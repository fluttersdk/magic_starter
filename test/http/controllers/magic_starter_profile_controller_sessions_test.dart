import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import 'magic_starter_auth_controller_test.dart' show MockGuard, MockNetworkDriver;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MagicStarterProfileController sessions', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MagicStarterProfileController controller;

    final Map<String, dynamic> mockSession = {
      'id': 'session-id-1',
      'ip_address': '192.168.1.1',
      'user_agent': 'Mozilla/5.0',
      'agent': {
        'is_desktop': true,
        'platform': 'Windows',
        'browser': 'Chrome',
      },
      'location': {
        'city': 'Istanbul',
        'country': 'Turkey',
      },
      'is_current_device': true,
      'last_used_at': '2025-01-01T00:00:00Z',
      'created_at': '2025-01-01T00:00:00Z',
    };

    setUp(() {
      MagicApp.reset();
      Magic.flush();

      mockDriver = MockNetworkDriver();
      Magic.singleton('network', () => mockDriver);
      Magic.singleton('log', () => LogManager());

      mockGuard = MockGuard();
      Auth.manager.forgetGuards();
      Auth.manager.extend('mock', (_) => mockGuard);
      Config.set('auth.defaults.guard', 'mock');

      Config.set('magic_starter.features.sessions', true);

      Magic.singleton('magic_starter', () => MagicStarterManager());
      controller = MagicStarterProfileController();
    });

    tearDown(() {
      controller.dispose();
      Auth.manager.forgetGuards();
    });

    group('getSessions', () {
      test('returns session list on success', () async {
        final List<Map<String, dynamic>> sessions = [
          {
            ...mockSession,
            'id': 'session-id-1',
          },
          {
            ...mockSession,
            'id': 'session-id-2',
            'ip_address': '10.0.0.2',
            'is_current_device': false,
          },
          {
            ...mockSession,
            'id': 'session-id-3',
            'ip_address': '172.16.0.3',
            'is_current_device': false,
          },
        ];

        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': sessions,
          },
        );

        final List<Map<String, dynamic>>? result =
            await controller.getSessions();

        expect(result, isNotNull);
        expect(result, hasLength(3));
        expect(result!.first['agent']['browser'], equals('Chrome'));
        expect(result.first['location']['city'], equals('Istanbul'));
        expect(controller.isSuccess, isTrue);
        expect(mockDriver.lastMethod, equals('GET'));
        expect(mockDriver.lastUrl, equals('/sessions'));
      });

      test('returns empty list when API returns empty data', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'data': <Map<String, dynamic>>[],
          },
        );

        final List<Map<String, dynamic>>? result =
            await controller.getSessions();

        expect(result, isNotNull);
        expect(result, isEmpty);
        expect(controller.isSuccess, isTrue);
      });

      test('returns null and sets error state on API error', () async {
        mockDriver.mockResponse(
          statusCode: 500,
          data: {
            'message': 'Server error',
          },
        );

        final List<Map<String, dynamic>>? result =
            await controller.getSessions();

        expect(result, isNull);
        expect(controller.isError, isTrue);
      });
    });

    group('doRevokeSession', () {
      test('revokes a single session and sends password payload', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'message': 'Session revoked successfully.',
          },
        );

        final bool result = await controller.doRevokeSession(
          tokenId: 'session-id-1',
          password: 'my-secret-password',
        );

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(mockDriver.lastMethod, equals('POST'));
        expect(mockDriver.lastUrl, equals('/sessions/session-id-1'));
        expect(
          mockDriver.lastData,
          equals({
            '_method': 'DELETE',
            'password': 'my-secret-password',
          }),
        );
      });

      test('returns false and sets error for wrong password', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The password is incorrect.',
            'errors': {
              'password': [
                'The provided password does not match your current password.',
              ],
            },
          },
        );

        final bool result = await controller.doRevokeSession(
          tokenId: 'session-id-1',
          password: 'wrong-password',
        );

        expect(result, isFalse);
        expect(controller.isError, isTrue);
      });

      test('returns false and sets error state on revoke failure', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Invalid session token.',
            'errors': {
              'token': [
                'The selected session token is invalid.',
              ],
            },
          },
        );

        final bool result = await controller.doRevokeSession(
          tokenId: 'invalid-token',
          password: 'my-secret-password',
        );

        expect(result, isFalse);
        expect(controller.isError, isTrue);
      });
    });

    group('doRevokeOtherSessions', () {
      test('revokes all other sessions and sends password payload', () async {
        mockDriver.mockResponse(
          statusCode: 200,
          data: {
            'message': 'Other sessions revoked successfully.',
          },
        );

        final bool result = await controller.doRevokeOtherSessions(
          password: 'my-secret-password',
        );

        expect(result, isTrue);
        expect(controller.isSuccess, isTrue);
        expect(mockDriver.lastMethod, equals('POST'));
        expect(mockDriver.lastUrl, equals('/sessions/other'));
        expect(
          mockDriver.lastData,
          equals({
            '_method': 'DELETE',
            'password': 'my-secret-password',
          }),
        );
      });

      test('returns false and sets error for wrong password', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'The password is incorrect.',
            'errors': {
              'password': [
                'The provided password was incorrect.',
              ],
            },
          },
        );

        final bool result = await controller.doRevokeOtherSessions(
          password: 'wrong-password',
        );

        expect(result, isFalse);
        expect(controller.isError, isTrue);
      });

      test('returns false for empty password payload', () async {
        mockDriver.mockResponse(
          statusCode: 422,
          data: {
            'message': 'Password is required.',
            'errors': {
              'password': [
                'The password field is required.',
              ],
            },
          },
        );

        final bool result = await controller.doRevokeOtherSessions(
          password: '',
        );

        expect(result, isFalse);
        expect(mockDriver.lastUrl, equals('/sessions/other'));
        expect(
          mockDriver.lastData,
          equals({
            '_method': 'DELETE',
            'password': '',
          }),
        );
      });
    });
  });
}
