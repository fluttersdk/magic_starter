import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// Mock NetworkDriver — intercepts all Http facade calls
// ---------------------------------------------------------------------------

class MockNetworkDriver implements NetworkDriver {
  MagicResponse? nextResponse;

  String? lastMethod;
  String? lastUrl;
  dynamic lastData;
  Map<String, dynamic>? lastFiles;
  bool uploadCalled = false;

  void mockResponse({
    required int statusCode,
    dynamic data,
  }) {
    nextResponse = MagicResponse(
      data: data ?? {},
      statusCode: statusCode,
    );
  }

  MagicResponse _respond(
    String method,
    String url, {
    dynamic data,
    Map<String, dynamic>? files,
  }) {
    lastMethod = method;
    lastUrl = url;
    lastData = data;
    if (files != null) {
      lastFiles = files;
    }
    return nextResponse ?? MagicResponse(data: {}, statusCode: 500);
  }

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {}

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async =>
      _respond('GET', url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async =>
      _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async =>
      _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async =>
      _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async =>
      _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async =>
      _respond('DESTROY', '$resource/$id');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) async {
    uploadCalled = true;
    return _respond('UPLOAD', url, data: data, files: files);
  }
}

// ---------------------------------------------------------------------------
// Mock Guard — tracks Auth.restore() / Auth.logout() calls
// ---------------------------------------------------------------------------

class MockGuard implements Guard {
  Authenticatable? _user;
  bool logoutCalled = false;
  bool restoreCalled = false;
  String? mockToken = 'mock-token';

  @override
  Future<void> login(Map<String, dynamic> data, Authenticatable user) async {
    mockToken = data['token'] as String?;
    _user = user;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    _user = null;
    mockToken = null;
  }

  @override
  bool check() => _user != null;

  @override
  bool get guest => !check();

  @override
  T? user<T extends Model>() => _user as T?;

  @override
  dynamic id() => _user?.authIdentifier;

  @override
  void setUser(Authenticatable user) => _user = user;

  @override
  Future<bool> hasToken() async => mockToken != null;

  @override
  Future<String?> getToken() async => mockToken;

  @override
  Future<bool> refreshToken() async => true;

  @override
  Future<void> restore() async {
    restoreCalled = true;
    if (mockToken != null) {
      _user = MagicStarterAuthUser.fromMap({
        'id': 1,
        'name': 'Restored User',
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('StarterProfileController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late StarterProfileController controller;

    setUp(() {
      // 1. Reset IoC container.
      MagicApp.reset();
      Magic.flush();

      // 2. Bind mock network driver for Http facade.
      Magic.singleton('network', () => MockNetworkDriver());

      // 2b. Bind log service for Log facade (used in catch blocks).
      Magic.singleton('log', () => LogManager());
      Config.set('logging', {
        'default': 'console',
        'channels': {
          'console': {'driver': 'console', 'level': 'debug'},
        },
      });

      // 3. Bind mock guard for Auth facade.
      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {
          'driver': 'mock',
        },
      });

      // 4. Bind MagicStarterManager for MagicStarter facade.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 5. Create a fresh controller instance.
      controller = StarterProfileController();

      // 6. Resolve the mock driver for response setup.
      mockDriver = Magic.make<NetworkDriver>('network') as MockNetworkDriver;
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    // -----------------------------------------------------------------------
    // doUpdateProfile
    // -----------------------------------------------------------------------

    group('doUpdateProfile', () {
      test('success (200) — returns true and calls Auth.restore()', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Profile updated'},
        );

        final result = await controller.doUpdateProfile(
          name: 'Alice Updated',
          email: 'alice@example.com',
        );

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
        expect(mockGuard.restoreCalled, isTrue);
        expect(mockDriver.lastMethod, equals('PUT'));
        expect(mockDriver.lastUrl, equals('/user/profile'));
        expect(
          mockDriver.lastData,
          equals({'name': 'Alice Updated', 'email': 'alice@example.com'}),
        );
      });

      test('failure (422) — returns false and sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Validation failed',
            'errors': {
              'email': ['The email is already taken.'],
            },
          },
        );

        final result = await controller.doUpdateProfile(
          name: 'Alice',
          email: 'taken@example.com',
        );

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
        expect(mockGuard.restoreCalled, isFalse);
      });

      test('prevents duplicate submission', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Profile updated'},
        );

        final future1 = controller.doUpdateProfile(
          name: 'Alice',
          email: 'alice@example.com',
        );

        // Second call while first is in-flight — should return false.
        final result2 = await controller.doUpdateProfile(
          name: 'Alice',
          email: 'alice@example.com',
        );

        final result1 = await future1;

        expect(result1, isTrue);
        expect(result2, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // doUpdatePassword
    // -----------------------------------------------------------------------

    group('doUpdatePassword', () {
      test('success (200) — returns true', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Password updated'},
        );

        final result = await controller.doUpdatePassword(
          currentPassword: 'oldpass123',
          password: 'newpass456',
          passwordConfirmation: 'newpass456',
        );

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
        expect(mockDriver.lastMethod, equals('PUT'));
        expect(mockDriver.lastUrl, equals('/user/password'));
        expect(
            mockDriver.lastData,
            equals({
              'current_password': 'oldpass123',
              'password': 'newpass456',
              'password_confirmation': 'newpass456',
            }));
      });

      test('failure (422) — returns false and sets error state', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Current password is incorrect',
            'errors': {
              'current_password': ['The current password is incorrect.'],
            },
          },
        );

        final result = await controller.doUpdatePassword(
          currentPassword: 'wrongpass',
          password: 'newpass456',
          passwordConfirmation: 'newpass456',
        );

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // doDeleteAccount
    // -----------------------------------------------------------------------

    group('doDeleteAccount', () {
      test(
        'success (200) — returns true, sends _method DELETE, and calls Auth.logout()',
        () async {
          mockDriver.mockResponse(
            statusCode: 200,
            data: {'message': 'Account deleted'},
          );

          final result = await controller.doDeleteAccount(
            password: 'mysecretpass',
          );

          expect(result, isTrue);
          expect(controller.isSuccess, isTrue);
          expect(mockGuard.logoutCalled, isTrue);

          // Verify POST body contains _method: DELETE.
          expect(mockDriver.lastMethod, equals('POST'));
          expect(mockDriver.lastUrl, equals('/user'));
          expect(
            mockDriver.lastData,
            equals({'_method': 'DELETE', 'password': 'mysecretpass'}),
          );
        },
      );

      test('failure (422) — returns false and does not logout', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Incorrect password',
            'errors': {
              'password': ['The password is incorrect.'],
            },
          },
        );

        final result = await controller.doDeleteAccount(
          password: 'wrongpass',
        );

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
        expect(mockGuard.logoutCalled, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // doUpdateProfilePhoto
    // -----------------------------------------------------------------------

    group('doUpdateProfilePhoto', () {
      late MagicFile testFile;

      setUp(() {
        testFile = MagicFile(
          name: 'avatar.jpg',
          size: 1024,
          mimeType: 'image/jpeg',
          bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        );
      });

      test(
          'success (200) — returns true, calls upload(), and calls Auth.restore()',
          () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Photo updated'},
        );

        final result = await controller.doUpdateProfilePhoto(file: testFile);

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
        expect(mockGuard.restoreCalled, isTrue);

        // Verify upload() was called on the driver.
        expect(mockDriver.uploadCalled, isTrue);
        expect(mockDriver.lastMethod, equals('UPLOAD'));
        expect(mockDriver.lastUrl, equals('/user/profile-photo'));
        expect(mockDriver.lastFiles, isNotNull);
        expect(mockDriver.lastFiles!['photo'], equals(testFile));
      });

      test('failure (422) — returns false', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Invalid file type',
            'errors': {
              'photo': ['The photo must be an image.'],
            },
          },
        );

        final result = await controller.doUpdateProfilePhoto(file: testFile);

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
        expect(mockGuard.restoreCalled, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // doDeleteProfilePhoto
    // -----------------------------------------------------------------------

    group('doDeleteProfilePhoto', () {
      test('success (200) — returns true and calls Auth.restore()', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Photo deleted'},
        );

        final result = await controller.doDeleteProfilePhoto();

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
        expect(mockGuard.restoreCalled, isTrue);
        expect(mockDriver.lastMethod, equals('DELETE'));
        expect(mockDriver.lastUrl, equals('/user/profile-photo'));
      });

      test('failure (404) — returns false', () async {
        mockDriver.mockResponse(
          statusCode: 404,
          data: {'message': 'No photo to delete'},
        );

        final result = await controller.doDeleteProfilePhoto();

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
        expect(mockGuard.restoreCalled, isFalse);
      });
    });
  });
}
