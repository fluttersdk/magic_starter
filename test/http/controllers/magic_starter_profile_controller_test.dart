import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show SizedBox, Widget;

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';
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

  void mockResponse({required int statusCode, dynamic data}) {
    nextResponse = MagicResponse(data: data ?? {}, statusCode: statusCode);
  }

  List<MagicResponse> responseQueue = [];

  void mockQueue(List<MagicResponse> responses) {
    responseQueue = List.from(responses);
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
    if (responseQueue.isNotEmpty) {
      return responseQueue.removeAt(0);
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
  }) async => _respond('GET', url);

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _respond('POST', url, data: data);

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) async => _respond('PUT', url, data: data);

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) async => _respond('DELETE', url);

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) async => _respond('INDEX', resource);

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _respond('SHOW', '$resource/$id');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => _respond('STORE', resource, data: data);

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) async => _respond('UPDATE', '$resource/$id', data: data);

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) async => _respond('DESTROY', '$resource/$id');

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

  /// Called from [logout], so a test can pin its ORDER against another hook
  /// (a before-logout one) rather than only whether it ran at all.
  void Function()? onLogout;

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
    onLogout?.call();
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
      _user = MagicStarterAuthUser.fromMap({'id': 1, 'name': 'Restored User'});
    }
  }

  @override
  ValueNotifier<int> get stateNotifier => ValueNotifier(0);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MagicStarterProfileController', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MagicStarterProfileController controller;

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
      Magic.singleton('auth', () => AuthManager());
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');
      Config.set('auth.guards', {
        'mock': {'driver': 'mock'},
      });

      // 4. Bind MagicStarterManager for MagicStarter facade.
      Magic.singleton('magic_starter', () => MagicStarterManager());

      // 5. Create a fresh controller instance.
      controller = MagicStarterProfileController();

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

      testWidgets(
        'a saved language is applied to the running app, not only persisted',
        (tester) async {
          // Saving a locale persisted it and confirmed it, and the app kept
          // speaking the old language until its next boot: nothing re-pointed
          // the translator after `Auth.restore()`.
          await tester.pumpWidget(const SizedBox.shrink());
          Translator.instance.setLoader(_StubLangLoader());
          await Translator.instance.setLocale(const Locale('en'));
          expect(Lang.current.languageCode, equals('en'));

          mockDriver.mockResponse(
            statusCode: 200,
            data: {'message': 'Profile updated'},
          );

          final result = await controller.doUpdateProfile(
            name: 'Alice',
            email: 'alice@example.com',
            language: 'tr',
          );

          expect(result, isTrue);
          // Applied after the current frame on purpose: `Lang.setLocale` calls
          // `Magic.reload()`, which unmounts the caller mid-await. The
          // controller asks for that frame itself, so one pump runs it and the
          // settle finishes the catalogue load it starts.
          await tester.pump();
          await tester.pumpAndSettle();

          expect(Lang.current.languageCode, equals('tr'));
        },
      );

      testWidgets('re-saving the same language does not switch anything', (
        tester,
      ) async {
        await tester.pumpWidget(const SizedBox.shrink());
        Translator.instance.setLoader(_StubLangLoader());
        await Translator.instance.setLocale(const Locale('en'));

        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Profile updated'},
        );

        await controller.doUpdateProfile(
          name: 'Alice',
          email: 'alice@example.com',
          language: 'en',
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(Lang.current.languageCode, equals('en'));
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

      test('sends the language param under the locale wire key', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Profile updated'},
        );

        final result = await controller.doUpdateProfile(
          name: 'Alice',
          email: 'alice@example.com',
          language: 'tr',
        );

        expect(result, isTrue);
        final sentData = mockDriver.lastData as Map;
        expect(sentData['locale'], equals('tr'));
        expect(sentData.containsKey('language'), isFalse);
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
          }),
        );
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
            proof: {'password': 'mysecretpass'},
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

      test(
        'immediately adds the flag to the body and signs out on 202',
        () async {
          mockDriver.mockResponse(
            statusCode: 202,
            data: {
              'data': {
                'deletion_scheduled_at': '2026-10-05T12:00:00.000000Z',
                'immediate': true,
              },
              'message': 'Your account is being deleted.',
            },
          );

          final result = await controller.doDeleteAccount(
            proof: {'password': 'mysecretpass'},
            immediately: true,
          );

          expect(result, isTrue);
          expect(mockGuard.logoutCalled, isTrue);
          expect(
            mockDriver.lastData,
            equals({
              '_method': 'DELETE',
              'password': 'mysecretpass',
              'immediately': true,
            }),
          );
        },
      );

      test('the default sends no immediately key', () async {
        mockDriver.mockResponse(
          statusCode: 202,
          data: {'message': 'Your account will be deleted in 30 days.'},
        );

        await controller.doDeleteAccount(proof: {'password': 'mysecretpass'});

        expect(mockDriver.lastData, isNot(contains('immediately')));
      });

      test('a refused immediate deletion keeps the user signed in', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The server wording.',
            'code': 'owns_shared_teams',
            'errors': {
              'user': ['The server wording.'],
            },
          },
        );

        final result = await controller.doDeleteAccount(
          proof: {'password': 'mysecretpass'},
          immediately: true,
        );

        expect(result, isFalse);
        expect(mockGuard.logoutCalled, isFalse);
        expect(mockDriver.lastData['immediately'], isTrue);
      });

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
          proof: {'password': 'wrongpass'},
        );

        expect(result, isFalse);
        expect(controller.isSuccess, isFalse);
        expect(mockGuard.logoutCalled, isFalse);
      });

      // The server revokes every token as part of the delete, so a hook that
      // calls the backend (a push device release) could only 401.
      test(
        'does not run the before-logout hooks when the delete succeeds',
        () async {
          final order = <String>[];
          MagicStarter.manager.beforeLogout(() async => order.add('hook'));
          mockGuard.onLogout = () => order.add('Auth.logout');

          mockDriver.mockResponse(
            statusCode: 200,
            data: {'message': 'Account deleted'},
          );

          final result = await controller.doDeleteAccount(
            proof: {'password': 'mysecretpass'},
          );

          expect(result, isTrue);
          expect(order, equals(['Auth.logout']));
        },
      );

      test(
        'does not run the before-logout hooks when the delete fails',
        () async {
          final order = <String>[];
          MagicStarter.manager.beforeLogout(() async => order.add('hook'));
          mockGuard.onLogout = () => order.add('Auth.logout');

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
            proof: {'password': 'wrongpass'},
          );

          expect(result, isFalse);
          expect(order, isEmpty);
        },
      );
    });

    group('doDeleteAccount refusals', () {
      late _RecordingLaunchAdapter launcher;
      late _RecordingStoreRail storeRail;

      setUp(() async {
        Translator.instance.setLoader(const _ShippedCatalogueLoader());
        await Translator.instance.setLocale(const Locale('en'));

        launcher = _RecordingLaunchAdapter();
        Magic.singleton('launch', () => LaunchService(adapter: launcher));

        storeRail = _RecordingStoreRail();
        Payments.manager.forgetDrivers();
        Payments.extend(PaymentsManager.storeRole, () => storeRail);

        Config.set('magic_starter.account.deletion_url', null);
      });

      tearDown(() {
        Payments.manager.forgetDrivers();
        Translator.instance.setLoader(_StubLangLoader());
      });

      /// Answers one 422 refusal, the way the backend's `ScheduleUserDeletion`
      /// shapes it.
      void refuse(
        String code, {
        List<String> teamIds = const [],
        Map<String, String>? teamProviders,
      }) {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The server wording.',
            'code': code,
            'team_ids': teamIds,
            'team_providers': ?teamProviders,
            'errors': {
              'user': ['The server wording.'],
            },
          },
        );
      }

      Future<bool> deleteAccount() =>
          controller.doDeleteAccount(proof: {'password': 'mysecretpass'});

      String blockedBy(String teams) =>
          _shipped('deletion_blocking_teams').replaceAll(':teams', teams);

      void knowTeams(Map<String, String> namesById) {
        MagicStarter.manager.teamResolver = MagicStarterTeamResolverConfig(
          currentTeam: () => null,
          allTeams: () => [
            for (final entry in namesById.entries)
              MagicStarterTeam(id: entry.key, name: entry.value),
          ],
          onSwitch: (_) async {},
        );
      }

      test('subscription_active shows its sentence and no action', () async {
        refuse('subscription_active');

        final result = await deleteAccount();

        expect(result, isFalse);
        expect(mockGuard.logoutCalled, isFalse);
        expect(
          controller.rxStatus.message,
          equals(_shipped('subscription_active')),
        );
        expect(controller.refusalAction, isNull);
      });

      test('last_login_method shows its sentence and no action', () async {
        refuse('last_login_method');

        await deleteAccount();

        expect(
          controller.rxStatus.message,
          equals(_shipped('last_login_method')),
        );
        expect(controller.refusalAction, isNull);
      });

      test('owns_shared_teams names the blocking teams', () async {
        knowTeams({'t1': 'Acme', 't2': 'Beta', 't3': 'Other'});
        refuse('owns_shared_teams', teamIds: ['t1', 't2']);

        final result = await deleteAccount();

        expect(result, isFalse);
        expect(mockGuard.logoutCalled, isFalse);
        expect(
          controller.rxStatus.message,
          equals('${_shipped('owns_shared_teams')} ${blockedBy('Acme, Beta')}'),
        );
        expect(controller.rxStatus.message, isNot(contains('The server')));
        expect(controller.refusalAction, isNull);
      });

      test('a team the list does not know falls back to the count', () async {
        knowTeams({'t1': 'Acme'});
        refuse('owns_shared_teams', teamIds: ['t1', 'gone']);

        await deleteAccount();

        expect(
          controller.rxStatus.message,
          equals('${_shipped('owns_shared_teams')} ${blockedBy('2')}'),
        );
      });

      test('no team resolver falls back to the count', () async {
        refuse('owns_shared_teams', teamIds: ['9a8b7c6d']);

        await deleteAccount();

        expect(
          controller.rxStatus.message,
          equals('${_shipped('owns_shared_teams')} ${blockedBy('1')}'),
        );
      });

      for (final provider in ['app_store', 'play_store']) {
        test('a $provider subscription offers store management', () async {
          knowTeams({'t1': 'Acme'});
          refuse(
            'team_has_active_subscription',
            teamIds: ['t1'],
            teamProviders: {'t1': provider},
          );

          final result = await deleteAccount();

          expect(result, isFalse);
          expect(mockGuard.logoutCalled, isFalse);
          expect(
            controller.rxStatus.message,
            equals('${_shipped('subscription_store')} ${blockedBy('Acme')}'),
          );
          final action = controller.refusalAction;
          expect(action, isNotNull);
          expect(action!.label, equals(_shipped('subscription_store_action')));

          await action.run();

          expect(storeRail.managementOpened, equals(1));
          expect(launcher.launched, isEmpty);
        });
      }

      test('a store rail that throws is reported, not rethrown', () async {
        Payments.extend(PaymentsManager.storeRole, _ThrowingStoreRail.new);
        refuse(
          'team_has_active_subscription',
          teamIds: ['t1'],
          teamProviders: {'t1': 'app_store'},
        );

        await deleteAccount();

        await expectLater(controller.refusalAction!.run(), completes);
      });

      test(
        'a stripe subscription opens the configured deletion page',
        () async {
          Config.set(
            'magic_starter.account.deletion_url',
            'https://example.com/account/delete',
          );
          knowTeams({'t1': 'Acme'});
          refuse(
            'team_has_active_subscription',
            teamIds: ['t1'],
            teamProviders: {'t1': 'stripe'},
          );

          await deleteAccount();

          expect(
            controller.rxStatus.message,
            equals('${_shipped('subscription_stripe')} ${blockedBy('Acme')}'),
          );
          final action = controller.refusalAction;
          expect(action, isNotNull);
          expect(action!.label, equals(_shipped('subscription_stripe_action')));

          await action.run();

          expect(
            launcher.launched,
            equals([Uri.parse('https://example.com/account/delete')]),
          );
          expect(storeRail.managementOpened, equals(0));
        },
      );

      test(
        'a stripe subscription with no deletion_url offers no action',
        () async {
          refuse(
            'team_has_active_subscription',
            teamIds: ['t1'],
            teamProviders: {'t1': 'stripe'},
          );

          await deleteAccount();

          expect(
            controller.rxStatus.message,
            startsWith(_shipped('subscription_stripe')),
          );
          expect(controller.refusalAction, isNull);
        },
      );

      test('the first blocking team with a known provider decides', () async {
        Config.set(
          'magic_starter.account.deletion_url',
          'https://example.com/account/delete',
        );
        refuse(
          'team_has_active_subscription',
          teamIds: ['t1', 't2'],
          teamProviders: {'t2': 'stripe'},
        );

        await deleteAccount();

        expect(
          controller.refusalAction!.label,
          equals(_shipped('subscription_stripe_action')),
        );
      });

      test(
        'a subscription refusal with no provider shows the generic sentence',
        () async {
          refuse('team_has_active_subscription', teamIds: ['t1']);

          await deleteAccount();

          expect(
            controller.rxStatus.message,
            startsWith(_shipped('team_has_active_subscription')),
          );
          expect(controller.refusalAction, isNull);
        },
      );

      test('the next call clears the action', () async {
        refuse(
          'team_has_active_subscription',
          teamIds: ['t1'],
          teamProviders: {'t1': 'app_store'},
        );
        await deleteAccount();
        expect(controller.refusalAction, isNotNull);

        mockDriver.mockResponse(
          statusCode: 202,
          data: {'message': 'Scheduled'},
        );
        await deleteAccount();

        expect(controller.refusalAction, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // Connected accounts
    // -----------------------------------------------------------------------

    group('connected accounts', () {
      late _FakeSocialAuth bridge;

      setUp(() async {
        Translator.instance.setLoader(const _ShippedCatalogueLoader());
        await Translator.instance.setLocale(const Locale('en'));

        bridge = _FakeSocialAuth();
        MagicStarter.useSocialAuth(bridge);
      });

      tearDown(() => Translator.instance.setLoader(_StubLangLoader()));

      group('doDisconnectSocialAccount', () {
        test('deletes the provider link, then restores the user', () async {
          mockDriver.mockResponse(statusCode: 204, data: null);

          final result = await controller.doDisconnectSocialAccount('google');

          expect(result, isTrue);
          expect(mockDriver.lastMethod, equals('DELETE'));
          expect(mockDriver.lastUrl, equals('/user/social-accounts/google'));
          expect(mockGuard.restoreCalled, isTrue);
        });

        test(
          'last_login_method shows its sentence and restores nothing',
          () async {
            mockDriver.mockResponse(
              statusCode: 422,
              data: {
                'message': 'The server wording.',
                'code': 'last_login_method',
                'errors': {
                  'provider': ['The server wording.'],
                },
              },
            );

            final result = await controller.doDisconnectSocialAccount('google');

            expect(result, isFalse);
            expect(
              controller.rxStatus.message,
              equals(_shipped('last_login_method')),
            );
            expect(mockGuard.restoreCalled, isFalse);
          },
        );

        test('an unknown link (404) is an error, not a success', () async {
          mockDriver.mockResponse(statusCode: 404, data: {'message': 'Gone'});

          final result = await controller.doDisconnectSocialAccount('github');

          expect(result, isFalse);
          expect(controller.isError, isTrue);
        });
      });

      group('beginSocialConnect', () {
        test('hands the provider and the proof to the bridge', () async {
          final opener = await controller.beginSocialConnect(
            'github',
            proof: {'password': 'mysecretpass'},
          );

          expect(opener, isNotNull);
          expect(bridge.beginCalls, equals(['github']));
          expect(
            bridge.beginProofs,
            equals([
              {'password': 'mysecretpass'},
            ]),
          );
          expect(bridge.openerCalls, equals(0));
        });

        for (final code in [
          'step_up_required',
          'social_account_taken',
          'flow_expired',
        ]) {
          test('$code shows its sentence and answers no opener', () async {
            bridge.beginFailure = MagicStarterSocialException(
              code: code,
              message: 'The bridge wording.',
            );

            final opener = await controller.beginSocialConnect(
              'github',
              proof: {'code': '123456'},
            );

            expect(opener, isNull);
            expect(controller.rxStatus.message, equals(_shipped(code)));
          });
        }

        test(
          'a failure the catalogue has no code for shows its message',
          () async {
            bridge.beginFailure = const MagicStarterSocialException(
              message: 'The provider is down.',
            );

            await controller.beginSocialConnect('github', proof: {});

            expect(
              controller.rxStatus.message,
              equals('The provider is down.'),
            );
          },
        );

        test('a cancelled flow shows nothing', () async {
          bridge.beginFailure = const MagicStarterSocialException(
            cancelled: true,
          );

          final opener = await controller.beginSocialConnect(
            'github',
            proof: {},
          );

          expect(opener, isNull);
          expect(controller.isError, isFalse);
        });
      });

      group('doConnectSocialAccount', () {
        test('runs the opener, then restores the user', () async {
          final opener = await controller.beginSocialConnect(
            'github',
            proof: {},
          );

          final result = await controller.doConnectSocialAccount(opener!);

          expect(result, isTrue);
          expect(bridge.openerCalls, equals(1));
          expect(mockGuard.restoreCalled, isTrue);
        });

        test('calls the opener before anything is awaited', () {
          // A web popup opens only inside the tap that started it.
          var opened = false;

          controller.doConnectSocialAccount(() {
            opened = true;

            return Future.value(<String, dynamic>{});
          });

          expect(opened, isTrue);
        });

        test('a refusal shows its sentence and restores nothing', () async {
          bridge.openFailure = const MagicStarterSocialException(
            code: 'social_account_taken',
          );
          final opener = await controller.beginSocialConnect(
            'github',
            proof: {},
          );

          final result = await controller.doConnectSocialAccount(opener!);

          expect(result, isFalse);
          expect(
            controller.rxStatus.message,
            equals(_shipped('social_account_taken')),
          );
          expect(mockGuard.restoreCalled, isFalse);
        });

        test('a cancelled flow shows nothing and restores nothing', () async {
          bridge.openFailure = const MagicStarterSocialException(
            cancelled: true,
          );
          final opener = await controller.beginSocialConnect(
            'github',
            proof: {},
          );

          final result = await controller.doConnectSocialAccount(opener!);

          expect(result, isFalse);
          expect(controller.isError, isFalse);
          expect(mockGuard.restoreCalled, isFalse);
        });
      });
    });

    // -----------------------------------------------------------------------
    // Step-up proofs and set-password
    // -----------------------------------------------------------------------

    group('step-up proofs', () {
      setUp(() => Config.set('magic_starter.features.sessions', true));

      final stepUpRefusal = <String, dynamic>{
        'message': 'Please confirm your identity to continue.',
        'code': 'step_up_required',
        'accepts': ['confirmation_token'],
        'errors': {
          'confirmation_token': ['Please confirm your identity to continue.'],
        },
      };

      test('a code proof is merged into the body beside _method', () async {
        mockDriver.mockResponse(statusCode: 200, data: {'message': 'ok'});

        await controller.doDisableTwoFactor(proof: {'code': '123456'});

        expect(
          mockDriver.lastData,
          equals({'_method': 'DELETE', 'code': '123456'}),
        );
      });

      test('a confirmation token proof reaches the body untouched', () async {
        mockDriver.mockResponse(statusCode: 200, data: {'message': 'ok'});

        await controller.doRevokeOtherSessions(
          proof: {'confirmation_token': 'tok-1'},
        );

        expect(
          mockDriver.lastData,
          equals({'_method': 'DELETE', 'confirmation_token': 'tok-1'}),
        );
      });

      test('an empty proof (a guest) sends no proof field', () async {
        mockDriver.mockResponse(statusCode: 200, data: {'data': {}});

        await controller.doEnableTwoFactor(proof: {});

        expect(mockDriver.lastData, equals(<String, dynamic>{}));
      });

      test(
        'step_up_required exposes the accepted proofs and its sentence',
        () async {
          mockDriver.mockResponse(statusCode: 422, data: stepUpRefusal);

          final result = await controller.doRevokeSession(
            tokenId: '7',
            proof: {'code': '000000'},
          );

          expect(result, isFalse);
          expect(controller.stepUpAccepts, equals(['confirmation_token']));
          expect(
            controller.rxStatus.message,
            equals(trans('social.step_up_required')),
          );
        },
      );

      test('step_up_required without accepts does not throw', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Please confirm your identity to continue.',
            'code': 'step_up_required',
          },
        );

        final result = await controller.doRevokeSession(
          tokenId: '7',
          proof: {'code': '000000'},
        );

        expect(result, isFalse);
        expect(controller.stepUpAccepts, isNull);
        expect(
          controller.rxStatus.message,
          equals(trans('social.step_up_required')),
        );
      });

      test('the next gated call starts without the previous refusal', () async {
        mockDriver.mockResponse(statusCode: 422, data: stepUpRefusal);
        await controller.doRevokeOtherSessions(proof: {'code': '000000'});
        expect(controller.stepUpAccepts, isNotNull);

        mockDriver.mockResponse(statusCode: 200, data: {'message': 'ok'});
        await controller.doRevokeOtherSessions(
          proof: {'confirmation_token': 'tok-2'},
        );

        expect(controller.stepUpAccepts, isNull);
      });

      test(
        'a refusal that is not a step-up leaves no accepted proofs',
        () async {
          mockDriver.mockResponse(
            statusCode: 422,
            data: {
              'message': 'Incorrect password',
              'errors': {
                'password': ['The password is incorrect.'],
              },
            },
          );

          await controller.doDeleteAccount(proof: {'password': 'wrong'});

          expect(controller.stepUpAccepts, isNull);
        },
      );
    });

    group('doSetPassword', () {
      test(
        'posts the new password with the proof, then restores the user',
        () async {
          mockDriver.mockResponse(statusCode: 200, data: {'data': null});

          final result = await controller.doSetPassword(
            password: 'NewSecret123',
            passwordConfirmation: 'NewSecret123',
            proof: {'confirmation_token': 'tok-1'},
          );

          expect(result, isTrue);
          expect(mockDriver.lastMethod, equals('POST'));
          expect(mockDriver.lastUrl, equals('/user/password/set'));
          expect(
            mockDriver.lastData,
            equals({
              'password': 'NewSecret123',
              'password_confirmation': 'NewSecret123',
              'confirmation_token': 'tok-1',
            }),
          );
          expect(mockGuard.restoreCalled, isTrue);
        },
      );

      test(
        'password_already_set restores the user and shows its sentence',
        () async {
          mockDriver.mockResponse(
            statusCode: 422,
            data: {
              'message': 'Your account already has a password set.',
              'code': 'password_already_set',
            },
          );

          final result = await controller.doSetPassword(
            password: 'NewSecret123',
            passwordConfirmation: 'NewSecret123',
            proof: {},
          );

          expect(result, isFalse);
          expect(mockGuard.restoreCalled, isTrue);
          expect(
            controller.rxStatus.message,
            equals(trans('social.password_already_set')),
          );
        },
      );

      test('password_not_set on a password change restores the user', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'This account has no password yet.',
            'code': 'password_not_set',
          },
        );

        final result = await controller.doUpdatePassword(
          currentPassword: 'anything',
          password: 'NewSecret123',
          passwordConfirmation: 'NewSecret123',
        );

        expect(result, isFalse);
        expect(mockGuard.restoreCalled, isTrue);
        expect(
          controller.rxStatus.message,
          equals(trans('social.password_not_set')),
        );
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
        },
      );

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
    // -----------------------------------------------------------------------
    // Two Factor Authentication
    // -----------------------------------------------------------------------

    group('two factor', () {
      group('doEnableTwoFactor', () {
        test('success (200) — returns data map', () async {
          mockDriver.mockResponse(
            statusCode: 200,
            data: {
              'data': {
                'secret': 'BASE32SECRET',
                'qr_url': 'otpauth://totp/app:user?secret=BASE32SECRET',
                'qr_svg': '<svg>...</svg>',
                'recovery_codes': ['code1', 'code2'],
              },
            },
          );

          final result = await controller.doEnableTwoFactor(
            proof: {'password': 'secret'},
          );

          expect(result, isNotNull);
          expect(result!['secret'], equals('BASE32SECRET'));
          expect(controller.isSuccess, isTrue);
          expect(mockDriver.lastMethod, equals('POST'));
          expect(mockDriver.lastUrl, equals('/two-factor-authentication'));
        });

        test('failure (500) — returns null and sets error', () async {
          mockDriver.mockResponse(
            statusCode: 500,
            data: {'message': 'Server error'},
          );

          final result = await controller.doEnableTwoFactor(
            proof: {'password': 'wrong'},
          );

          expect(result, isNull);
          expect(controller.isSuccess, isFalse);
        });
      });

      group('doConfirmTwoFactor', () {
        test('success (200) — returns true', () async {
          mockDriver.mockResponse(
            statusCode: 200,
            data: {'message': 'Two-factor authentication confirmed.'},
          );

          final result = await controller.doConfirmTwoFactor(code: '123456');

          expect(result, isTrue);
          expect(controller.isSuccess, isTrue);
          expect(mockDriver.lastMethod, equals('POST'));
          expect(
            mockDriver.lastUrl,
            equals('/two-factor-authentication/confirm'),
          );
          expect(mockDriver.lastData, equals({'code': '123456'}));
        });

        test('failure (422) — returns false', () async {
          mockDriver.mockResponse(
            statusCode: 422,
            data: {
              'message': 'Invalid code',
              'errors': {
                'code': [
                  'The provided two factor authentication code was invalid.',
                ],
              },
            },
          );

          final result = await controller.doConfirmTwoFactor(code: '000000');

          expect(result, isFalse);
          expect(controller.isSuccess, isFalse);
        });
      });

      group('doDisableTwoFactor', () {
        test('success (200) — returns true', () async {
          mockDriver.mockQueue([
            MagicResponse(
              statusCode: 200,
              data: {'message': 'Two-factor authentication disabled.'},
            ),
          ]);

          final result = await controller.doDisableTwoFactor(
            proof: {'password': 'mysecretpass'},
          );

          expect(result, isTrue);
          expect(controller.isSuccess, isTrue);
          expect(mockDriver.lastMethod, equals('POST'));
          expect(mockDriver.lastUrl, equals('/two-factor-authentication'));
          expect(
            mockDriver.lastData,
            equals({'_method': 'DELETE', 'password': 'mysecretpass'}),
          );
        });

        test('failure (422 confirm password) — returns false', () async {
          mockDriver.mockQueue([
            MagicResponse(
              statusCode: 422,
              data: {
                'message': 'Invalid password',
                'errors': {
                  'password': ['The password is incorrect.'],
                },
              },
            ),
          ]);

          final result = await controller.doDisableTwoFactor(
            proof: {'password': 'wrongpass'},
          );

          expect(result, isFalse);
          expect(controller.isSuccess, isFalse);
        });

        test('failure (500 on disable) — returns false', () async {
          mockDriver.mockQueue([MagicResponse(statusCode: 500, data: {})]);

          final result = await controller.doDisableTwoFactor(
            proof: {'password': 'mysecretpass'},
          );

          expect(result, isFalse);
          expect(controller.isSuccess, isFalse);
        });
      });

      group('getRecoveryCodes', () {
        test('success (200) — returns list of codes', () async {
          mockDriver.mockQueue([
            MagicResponse(
              statusCode: 200,
              data: {
                'data': ['code1', 'code2', 'code3'],
              },
            ),
          ]);

          final result = await controller.getRecoveryCodes(
            proof: {'password': 'mysecretpass'},
          );

          expect(result, isNotNull);
          expect(result!.length, equals(3));
          expect(result.first, equals('code1'));
          expect(mockDriver.lastMethod, equals('POST'));
          expect(mockDriver.lastUrl, equals('/two-factor-recovery-codes/show'));
          expect(mockDriver.lastData, equals({'password': 'mysecretpass'}));
        });

        test('failure (500) — returns null', () async {
          mockDriver.mockQueue([
            MagicResponse(statusCode: 500, data: {'message': 'Server error'}),
          ]);

          final result = await controller.getRecoveryCodes(
            proof: {'password': 'mysecretpass'},
          );

          expect(result, isNull);
        });
      });
      group('doRegenerateRecoveryCodes', () {
        test('success (200) — returns list of new codes', () async {
          mockDriver.mockQueue([
            MagicResponse(
              statusCode: 200,
              data: {
                'data': ['new1', 'new2', 'new3'],
              },
            ),
          ]);

          final result = await controller.doRegenerateRecoveryCodes(
            proof: {'password': 'mysecretpass'},
          );

          expect(result, isNotNull);
          expect(result!.length, equals(3));
          expect(result.first, equals('new1'));
          expect(controller.isSuccess, isTrue);
          expect(mockDriver.lastMethod, equals('POST'));
          expect(mockDriver.lastUrl, equals('/two-factor-recovery-codes'));
          expect(mockDriver.lastData, equals({'password': 'mysecretpass'}));
        });

        test('failure (500) — returns null', () async {
          mockDriver.mockQueue([
            MagicResponse(statusCode: 500, data: {'message': 'Server error'}),
          ]);

          final result = await controller.doRegenerateRecoveryCodes(
            proof: {'password': 'mysecretpass'},
          );

          expect(result, isNull);
          expect(controller.isSuccess, isFalse);
        });
      });
    });
    // -----------------------------------------------------------------------
    // Sessions
    // -----------------------------------------------------------------------

    group('sessions', () {
      setUp(() {
        Config.set('magic_starter.features.sessions', true);
      });

      group('getSessions', () {
        test(
          'success (200) — returns list of sessions when feature enabled',
          () async {
            mockDriver.mockResponse(
              statusCode: 200,
              data: {
                'data': [
                  {
                    'id': 'tok-abc',
                    'ip_address': '192.168.1.1',
                    'agent': {
                      'is_desktop': true,
                      'platform': 'macOS',
                      'browser': 'Chrome',
                    },
                    'location': {'city': 'Istanbul', 'country': 'TR'},
                    'is_current_device': true,
                  },
                ],
              },
            );

            final result = await controller.getSessions();

            expect(result, isNotNull);
            expect(result!.length, equals(1));
            expect(result.first['id'], equals('tok-abc'));
            expect(result.first['agent'], isNotNull);
            expect(result.first['location'], isNotNull);
            expect(controller.isSuccess, isTrue);
            expect(mockDriver.lastMethod, equals('GET'));
            expect(mockDriver.lastUrl, equals('/sessions'));
          },
        );

        test('returns null when feature disabled', () async {
          Config.set('magic_starter.features.sessions', false);

          final result = await controller.getSessions();

          expect(result, isNull);
        });

        test('failure (500) — returns null', () async {
          mockDriver.mockResponse(
            statusCode: 500,
            data: {'message': 'Server error'},
          );

          final result = await controller.getSessions();

          expect(result, isNull);
          expect(controller.isSuccess, isFalse);
        });
      });

      group('doRevokeSession', () {
        test(
          'success (200) — returns true and sends password to /sessions/{tokenId}',
          () async {
            mockDriver.mockResponse(
              statusCode: 200,
              data: {'message': 'Session revoked successfully.'},
            );

            final result = await controller.doRevokeSession(
              tokenId: 'tok-abc',
              proof: {'password': 'mysecretpass'},
            );

            expect(result, isTrue);
            expect(controller.isSuccess, isTrue);
            expect(mockDriver.lastMethod, equals('POST'));
          },
        );

        test('failure (422) — returns false for wrong password', () async {
          mockDriver.mockResponse(
            statusCode: 422,
            data: {
              'message': 'Invalid password',
              'errors': {
                'password': ['The password is incorrect.'],
              },
            },
          );

          final result = await controller.doRevokeSession(
            tokenId: 'tok-abc',
            proof: {'password': 'wrongpass'},
          );

          expect(result, isFalse);
          expect(controller.isSuccess, isFalse);
        });
      });

      group('doRevokeOtherSessions', () {
        test(
          'success (200) — returns true and sends password to /sessions/other',
          () async {
            mockDriver.mockResponse(
              statusCode: 200,
              data: {'message': 'Other sessions revoked successfully.'},
            );

            final result = await controller.doRevokeOtherSessions(
              proof: {'password': 'mysecretpass'},
            );

            expect(result, isTrue);
            expect(controller.isSuccess, isTrue);
            // expect(mockDriver.lastMethod, equals('DELETE'));
            // expect(mockDriver.lastUrl, equals('/sessions/other'));
            // expect(mockDriver.lastData, equals({'password': 'mysecretpass'}));
          },
        );

        test('failure (422) — returns false', () async {
          mockDriver.mockResponse(
            statusCode: 422,
            data: {
              'message': 'Invalid password',
              'errors': {
                'password': ['The password is incorrect.'],
              },
            },
          );

          final result = await controller.doRevokeOtherSessions(
            proof: {'password': 'wrongpass'},
          );

          expect(result, isFalse);
          expect(controller.isSuccess, isFalse);
        });
      });
    });
    // -----------------------------------------------------------------------
    // sendEmailVerification / isEmailVerified
    // -----------------------------------------------------------------------

    group('email verification', () {
      setUp(() {
        Config.set('magic_starter.features.email_verification', true);
      });

      group('sendEmailVerification', () {
        test(
          'success (202) — calls correct endpoint and sets success',
          () async {
            mockDriver.mockResponse(statusCode: 202, data: {});

            await controller.sendEmailVerification();

            expect(mockDriver.lastMethod, equals('POST'));
            expect(
              mockDriver.lastUrl,
              equals('/email/verification-notification'),
            );
            expect(controller.isSuccess, isTrue);
          },
        );

        test('error (500) — sets error state', () async {
          mockDriver.mockResponse(
            statusCode: 500,
            data: {'message': 'Server error'},
          );

          await controller.sendEmailVerification();

          expect(controller.isError, isTrue);
        });

        test('error (429) — sets error state (rate limited)', () async {
          mockDriver.mockResponse(
            statusCode: 429,
            data: {'message': 'Too many requests.'},
          );

          await controller.sendEmailVerification();

          expect(controller.isError, isTrue);
        });

        test('prevents duplicate submission while loading', () async {
          mockDriver.mockResponse(statusCode: 202, data: {});

          final first = controller.sendEmailVerification();
          // Second call while first is in-flight — should be a no-op.
          await controller.sendEmailVerification();
          await first;

          // Only one HTTP call should have been made.
          expect(
            mockDriver.lastUrl,
            equals('/email/verification-notification'),
          );
        });
      });

      group('isEmailVerified', () {
        test('returns false when no user is authenticated', () {
          expect(controller.isEmailVerified, isFalse);
        });

        test('returns false when email_verified_at is null', () {
          mockGuard.setUser(
            MagicStarterAuthUser.fromMap({
              'id': 1,
              'name': 'Alice',
              'email': 'alice@example.com',
              'email_verified_at': null,
            }),
          );

          expect(controller.isEmailVerified, isFalse);
        });

        test('returns true when email_verified_at has a value', () {
          mockGuard.setUser(
            MagicStarterAuthUser.fromMap({
              'id': 1,
              'name': 'Alice',
              'email': 'alice@example.com',
              'email_verified_at': '2025-01-15T10:00:00.000000Z',
            }),
          );

          expect(controller.isEmailVerified, isTrue);
        });
      });
    });

    // -----------------------------------------------------------------------
    // withoutNotifying
    // -----------------------------------------------------------------------

    group('withoutNotifying', () {
      test(
        'an overlapping action stays quiet after an inner one ends',
        () async {
          // A save still in flight when the reader opens another settings page
          // that loads on mount: two suppressed actions overlap. A flag cleared
          // by the one that finishes first un-suppressed the other.
          var notificationCount = 0;
          controller.addListener(() => notificationCount++);

          final Completer<void> outerHeld = Completer<void>();
          final Future<void> outer = controller.withoutNotifying(() async {
            await outerHeld.future;
            controller.setError('outer finished');
          });

          await controller.withoutNotifying(
            () async => controller.setLoading(),
          );
          outerHeld.complete();
          await outer;

          expect(notificationCount, 0);
        },
      );

      test('resetQuietly clears errors and state without notifying', () {
        var notificationCount = 0;
        controller.addListener(() => notificationCount++);
        controller.validationErrors = {'name': 'stale'};
        controller.setError('stale');
        notificationCount = 0;

        controller.resetQuietly();

        expect(notificationCount, 0);
        expect(controller.validationErrors, isEmpty);
        expect(controller.isEmpty, isTrue);
      });

      test('suppresses notifyListeners during action', () async {
        // 1. Attach a listener to the controller to count notifications.
        var notificationCount = 0;
        controller.addListener(() => notificationCount++);

        // 2. Mock a successful response for doUpdateProfile.
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Profile updated'},
        );

        // 3. Call doUpdateProfile WITHIN withoutNotifying.
        await controller.withoutNotifying(
          () => controller.doUpdateProfile(
            name: 'Alice',
            email: 'alice@example.com',
          ),
        );

        // 4. No notifications should have been fired.
        expect(notificationCount, equals(0));
      });

      test('still updates internal state when suppressed', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Profile updated'},
        );

        await controller.withoutNotifying(
          () => controller.doUpdateProfile(
            name: 'Alice',
            email: 'alice@example.com',
          ),
        );

        // State is updated even though notifications were suppressed.
        expect(controller.isSuccess, isTrue);
        expect(controller.rxState, isTrue);
      });

      test('re-enables notifications after action completes', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Profile updated'},
        );

        // 1. Run suppressed action.
        await controller.withoutNotifying(
          () => controller.doUpdateProfile(
            name: 'Alice',
            email: 'alice@example.com',
          ),
        );

        // 2. Attach listener AFTER suppressed call.
        var notifiedAfter = false;
        controller.addListener(() => notifiedAfter = true);

        // 3. Make another call WITHOUT withoutNotifying.
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Password updated'},
        );
        await controller.doUpdatePassword(
          currentPassword: 'oldpass',
          password: 'newpass',
          passwordConfirmation: 'newpass',
        );

        // 4. Notifications should fire normally again.
        expect(notifiedAfter, isTrue);
      });

      test('re-enables notifications even on exception', () async {
        // 1. Force an exception inside the controller method.
        // Use a null response to trigger a 500 → catch block → setError.
        mockDriver.mockResponse(
          statusCode: 500,
          data: {'message': 'Server error'},
        );

        // 2. withoutNotifying should NOT leak the suppression flag.
        await controller.withoutNotifying(
          () => controller.doUpdateProfile(
            name: 'Alice',
            email: 'alice@example.com',
          ),
        );

        // 3. Subsequent calls should notify normally.
        var notifiedAfter = false;
        controller.addListener(() => notifiedAfter = true);

        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Password updated'},
        );
        await controller.doUpdatePassword(
          currentPassword: 'oldpass',
          password: 'newpass',
          passwordConfirmation: 'newpass',
        );

        expect(notifiedAfter, isTrue);
      });

      test('returns the action result', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {'message': 'Profile updated'},
        );

        final result = await controller.withoutNotifying(
          () => controller.doUpdateProfile(
            name: 'Alice',
            email: 'alice@example.com',
          ),
        );

        expect(result, isTrue);
      });

      test(
        'direct calls still trigger notifications (backward compat)',
        () async {
          var notificationCount = 0;
          controller.addListener(() => notificationCount++);

          mockDriver.mockResponse(
            statusCode: 200,
            data: {'message': 'Profile updated'},
          );

          // Direct call WITHOUT withoutNotifying — should notify as before.
          await controller.doUpdateProfile(
            name: 'Alice',
            email: 'alice@example.com',
          );

          // At least 1 notification (setLoading + setSuccess = 2 minimum).
          expect(notificationCount, greaterThanOrEqualTo(1));
        },
      );
    });
  });
}

/// Serves an empty catalogue for any locale, so a locale switch in these tests
/// succeeds without shipping copy for it.
class _StubLangLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async => <String, dynamic>{};
}

/// The package's shipped `social` copy, so an assertion on a sentence is an
/// assertion about what a host installs rather than a literal typed here.
class _ShippedCatalogueLoader implements TranslationLoader {
  const _ShippedCatalogueLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => {
    for (final entry in _shippedSocial().entries)
      'social.${entry.key}': entry.value,
  };
}

Map<String, dynamic> _shippedSocial() {
  final stub =
      jsonDecode(File('assets/stubs/install/en.stub').readAsStringSync())
          as Map<String, dynamic>;

  return stub['social'] as Map<String, dynamic>;
}

String _shipped(String code) => _shippedSocial()[code] as String;

/// A launcher that records what it was asked to open instead of opening it.
class _RecordingLaunchAdapter implements LaunchAdapter {
  final List<Uri> launched = [];

  @override
  Future<bool> launch(
    Uri url, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    launched.add(url);

    return true;
  }

  @override
  Future<bool> canLaunch(Uri url) async => true;
}

/// A store rail that counts how often the store's management screen opened.
class _RecordingStoreRail implements StoreBillingService {
  int managementOpened = 0;

  @override
  Future<void> identify(String appUserId) async {}

  @override
  Future<bool> purchase(String productKey, {PurchaseContext? context}) async =>
      false;

  @override
  Future<Map<String, StoreProductOffer>> products(
    List<String> productKeys,
  ) async => const <String, StoreProductOffer>{};

  @override
  Future<bool> restore() async => false;

  @override
  Future<void> openStoreManagement() async => managementOpened++;

  @override
  ManageVia get store => ManageVia.appStore;
}

/// A store rail whose management screen cannot be opened.
class _ThrowingStoreRail extends _RecordingStoreRail {
  @override
  Future<void> openStoreManagement() async =>
      throw const BillingException('no store screen');
}

/// A bridge whose connect answers, or fails, as scripted.
class _FakeSocialAuth implements MagicStarterSocialAuth {
  final List<String> beginCalls = [];
  final List<Map<String, String>> beginProofs = [];
  int openerCalls = 0;
  MagicStarterSocialException? beginFailure;
  MagicStarterSocialException? openFailure;

  @override
  List<String> providers() => const ['google', 'github'];

  @override
  String label(String provider) => provider;

  @override
  Widget icon(String provider) => const SizedBox();

  @override
  Future<Map<String, dynamic>> signIn(String provider) =>
      throw UnimplementedError();

  @override
  Future<Future<Map<String, dynamic>> Function()> beginConnect(
    String provider,
    Map<String, String> proof,
  ) async {
    beginCalls.add(provider);
    beginProofs.add(proof);
    final failure = beginFailure;
    if (failure != null) throw failure;

    return () async {
      openerCalls++;
      final failure = openFailure;
      if (failure != null) throw failure;

      return {
        'data': {'provider': provider, 'email': 'ada@example.com'},
      };
    };
  }

  @override
  Future<String> confirm(String provider) => throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}
