import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

import '../http/controllers/magic_starter_auth_controller_test.dart'
    show MockGuard, MockNetworkDriver;
import '../http/controllers/magic_starter_guest_auth_controller_test.dart'
    show MockVaultService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-feature integration smoke tests', () {
    late MockNetworkDriver mockDriver;
    late MockGuard mockGuard;
    late MockVaultService mockVault;
    late List<MagicController> controllers;

    T trackController<T extends MagicController>(T controller) {
      controllers.add(controller);
      return controller;
    }

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
      Config.set('auth.guards', {
        'mock': {
          'driver': 'mock',
        },
      });

      mockVault = MockVaultService();
      Magic.singleton('vault', () => mockVault);

      Magic.singleton('magic_starter', () => MagicStarterManager());

      controllers = <MagicController>[];
    });

    tearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }

      Auth.manager.forgetGuards();
    });

    test('guest login and upgrade flow works end-to-end', () async {
      Config.set('magic_starter.features.guest_auth', true);

      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': {
            'token': 'guest-token',
            'user': {
              'id': 99,
              'name': 'Guest User',
              'is_guest': true,
            },
          },
        },
      );

      final guestController = trackController<MagicStarterGuestAuthController>(
          MagicStarterGuestAuthController());

      await guestController.doGuestLogin();

      expect(guestController.isSuccess, isTrue);
      expect(mockDriver.lastUrl, equals('/auth/guest'));
      expect(mockDriver.lastData?['device_id'], isNotEmpty);
      expect(guestController.isGuestUser, isTrue);

      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'message': 'Profile upgraded',
        },
      );

      final profileController = trackController<MagicStarterProfileController>(
          MagicStarterProfileController());

      final upgraded = await profileController.doUpdateProfile(
        name: 'Upgraded User',
        email: 'upgraded@example.com',
      );

      expect(upgraded, isTrue);
      expect(profileController.isSuccess, isTrue);
      expect(mockDriver.lastUrl, equals('/user/profile'));
      expect(
        mockDriver.lastData,
        equals({
          'name': 'Upgraded User',
          'email': 'upgraded@example.com',
        }),
      );
    });

    test('email-only login mode sends email and not phone', () async {
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', false);

      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': {
            'token': 'email-token',
            'user': {
              'id': 1,
              'name': 'Email User',
              'email': 'email@example.com',
            },
          },
        },
      );

      final authController = trackController<MagicStarterAuthController>(
          MagicStarterAuthController());

      await authController.doLogin(
        email: 'email@example.com',
        password: 'secret123',
      );

      final payload = mockDriver.lastData as Map<String, dynamic>?;

      expect(authController.isSuccess, isTrue);
      expect(payload?['email'], equals('email@example.com'));
      expect(payload?.containsKey('phone'), isFalse);
    });

    test('OTP flow send then verify authenticates the user', () async {
      Config.set('magic_starter.features.phone_otp', true);

      final otpController = trackController<MagicStarterOtpController>(
          MagicStarterOtpController());

      mockDriver.mockResponse(
        statusCode: 200,
        data: {},
      );

      await otpController.sendOtp(phone: '+905301234567');

      expect(otpController.step, equals(OtpStep.codeInput));
      expect(mockDriver.lastUrl, equals('/auth/otp/send'));

      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'token': 'otp-token',
          'user': {
            'id': 2,
            'name': 'Otp User',
          },
        },
      );

      await otpController.verifyOtp(
        phone: '+905301234567',
        code: '123456',
      );

      expect(otpController.isSuccess, isTrue);
      expect(mockGuard.check(), isTrue);
      expect(mockDriver.lastUrl, equals('/auth/otp/verify'));
    });

    test('all optional features disabled keeps profile capabilities minimal',
        () {
      Config.set('magic_starter.features.guest_auth', false);
      Config.set('magic_starter.features.phone_otp', false);
      Config.set('magic_starter.features.newsletter', false);
      Config.set('magic_starter.features.email_verification', false);
      Config.set('magic_starter.features.extended_profile', false);
      Config.set('magic_starter.features.notifications', false);

      expect(MagicStarterConfig.hasGuestAuthFeatures(), isFalse);
      expect(MagicStarterConfig.hasPhoneOtpFeatures(), isFalse);
      expect(MagicStarterConfig.hasNewsletterFeatures(), isFalse);
      expect(MagicStarterConfig.hasEmailVerificationFeatures(), isFalse);
      expect(MagicStarterConfig.hasExtendedProfileFeatures(), isFalse);
      expect(MagicStarterConfig.hasNotificationFeatures(), isFalse);
    });

    test('newsletter feature works across register and profile status fetch',
        () async {
      Config.set('magic_starter.features.newsletter', true);
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', false);

      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'data': {
            'token': 'register-token',
            'user': {
              'id': 3,
              'name': 'Newsletter User',
              'email': 'newsletter@example.com',
            },
          },
        },
      );

      final authController = trackController<MagicStarterAuthController>(
          MagicStarterAuthController());

      await authController.doRegister(
        name: 'Newsletter User',
        email: 'newsletter@example.com',
        password: 'secret123',
        passwordConfirmation: 'secret123',
        subscribeNewsletter: true,
      );

      final registerPayload = mockDriver.lastData as Map<String, dynamic>?;

      expect(authController.isSuccess, isTrue);
      expect(mockDriver.lastUrl, equals('/auth/register'));
      expect(registerPayload?['subscribe_newsletter'], isTrue);

      mockDriver.mockResponse(
        statusCode: 200,
        data: {
          'subscribed': false,
        },
      );

      final newsletterController =
          trackController<MagicStarterNewsletterController>(
              MagicStarterNewsletterController());

      await newsletterController.getNewsletterStatus();

      expect(newsletterController.isSuccess, isTrue);
      expect(mockDriver.lastMethod, equals('GET'));
      expect(mockDriver.lastUrl, equals('/user/newsletter'));
    });

    test('all feature toggles enabled return true including identity config',
        () {
      Config.set('magic_starter.features.guest_auth', true);
      Config.set('magic_starter.features.phone_otp', true);
      Config.set('magic_starter.features.newsletter', true);
      Config.set('magic_starter.features.email_verification', true);
      Config.set('magic_starter.features.extended_profile', true);
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', true);

      expect(MagicStarterConfig.hasGuestAuthFeatures(), isTrue);
      expect(MagicStarterConfig.hasPhoneOtpFeatures(), isTrue);
      expect(MagicStarterConfig.hasNewsletterFeatures(), isTrue);
      expect(MagicStarterConfig.hasEmailVerificationFeatures(), isTrue);
      expect(MagicStarterConfig.hasExtendedProfileFeatures(), isTrue);
      expect(MagicStarterConfig.emailIdentity(), isTrue);
      expect(MagicStarterConfig.phoneIdentity(), isTrue);
    });
  });
}
