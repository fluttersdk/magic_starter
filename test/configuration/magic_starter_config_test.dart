import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterConfig', () {
    setUp(() {
      MagicApp.reset();
    });

    // -------------------------------------------------------------------------
    // Feature toggles — default values
    // -------------------------------------------------------------------------

    group('feature toggles (defaults)', () {
      test('hasTeamFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasTeamFeatures(), isFalse);
      });

      test('hasProfilePhotoFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasProfilePhotoFeatures(), isFalse);
      });

      test('hasRegistrationFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasRegistrationFeatures(), isFalse);
      });

      test('hasSocialLoginFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasSocialLoginFeatures(), isFalse);
      });

      test('hasTwoFactorFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasTwoFactorFeatures(), isFalse);
      });

      test('hasSessionsFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasSessionsFeatures(), isFalse);
      });

      test('hasNotificationFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasNotificationFeatures(), isFalse);
      });

      test('hasGuestAuthFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasGuestAuthFeatures(), isFalse);
      });

      test('hasPhoneOtpFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasPhoneOtpFeatures(), isFalse);
      });

      test('hasNewsletterFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasNewsletterFeatures(), isFalse);
      });

      test('hasEmailVerificationFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasEmailVerificationFeatures(), isFalse);
      });

      test('hasExtendedProfileFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasExtendedProfileFeatures(), isFalse);
      });

      test('hasTimezoneFeatures() returns false by default', () {
        expect(MagicStarterConfig.hasTimezoneFeatures(), isFalse);
      });
    });
    // -------------------------------------------------------------------------
    // Route accessors — default values
    // -------------------------------------------------------------------------

    group('route accessors (defaults)', () {
      test('homeRoute() returns "/" by default', () {
        expect(MagicStarterConfig.homeRoute(), equals('/'));
      });

      test('loginRoute() returns "/auth/login" by default', () {
        expect(MagicStarterConfig.loginRoute(), equals('/auth/login'));
      });

      test('authPrefix() returns "/auth" by default', () {
        expect(MagicStarterConfig.authPrefix(), equals('/auth'));
      });

      test('teamsPrefix() returns "/teams" by default', () {
        expect(MagicStarterConfig.teamsPrefix(), equals('/teams'));
      });

      test('profilePrefix() returns "/settings" by default', () {
        expect(MagicStarterConfig.profilePrefix(), equals('/settings'));
      });

      test('notificationsPrefix() returns "/notifications" by default', () {
        expect(
            MagicStarterConfig.notificationsPrefix(), equals('/notifications'));
      });
    });

    // -------------------------------------------------------------------------
    // Computed routes — derived from prefixes
    // -------------------------------------------------------------------------

    group('computed routes (defaults)', () {
      test('teamCreateRoute() returns "/teams/create"', () {
        expect(
          MagicStarterConfig.teamCreateRoute(),
          equals('/teams/create'),
        );
      });

      test('teamSettingsRoute() returns "/teams/settings"', () {
        expect(
          MagicStarterConfig.teamSettingsRoute(),
          equals('/teams/settings'),
        );
      });

      test('profileRoute() returns "/settings/profile"', () {
        expect(
          MagicStarterConfig.profileRoute(),
          equals('/settings/profile'),
        );
      });

      test('notificationsRoute() returns "/notifications"', () {
        expect(
          MagicStarterConfig.notificationsRoute(),
          equals('/notifications'),
        );
      });

      test('notificationPreferencesRoute() returns "/settings/notifications"',
          () {
        expect(
          MagicStarterConfig.notificationPreferencesRoute(),
          equals('/settings/notifications'),
        );
      });

      test(
          'twoFactorChallengeRoute() returns "/auth/two-factor-challenge" by default',
          () {
        expect(
          MagicStarterConfig.twoFactorChallengeRoute(),
          equals('/auth/two-factor-challenge'),
        );
      });
    });

    // -------------------------------------------------------------------------
    // Feature toggles — configured overrides
    // -------------------------------------------------------------------------

    group('feature toggles (configured)', () {
      test('hasTeamFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.teams', true);

        expect(MagicStarterConfig.hasTeamFeatures(), isTrue);
      });

      test('hasProfilePhotoFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.profile_photos', true);

        expect(MagicStarterConfig.hasProfilePhotoFeatures(), isTrue);
      });

      test('hasRegistrationFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.registration', true);

        expect(MagicStarterConfig.hasRegistrationFeatures(), isTrue);
      });

      test('hasSocialLoginFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.social_login', true);

        expect(MagicStarterConfig.hasSocialLoginFeatures(), isTrue);
      });

      test('hasTwoFactorFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.two_factor', true);

        expect(MagicStarterConfig.hasTwoFactorFeatures(), isTrue);
      });

      test('hasSessionsFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.sessions', true);

        expect(MagicStarterConfig.hasSessionsFeatures(), isTrue);
      });

      test('hasNotificationFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.notifications', true);

        expect(MagicStarterConfig.hasNotificationFeatures(), isTrue);
      });

      test('hasGuestAuthFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.guest_auth', true);

        expect(MagicStarterConfig.hasGuestAuthFeatures(), isTrue);
      });

      test('hasPhoneOtpFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.phone_otp', true);

        expect(MagicStarterConfig.hasPhoneOtpFeatures(), isTrue);
      });

      test('hasNewsletterFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.newsletter', true);

        expect(MagicStarterConfig.hasNewsletterFeatures(), isTrue);
      });

      test('hasEmailVerificationFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.email_verification', true);

        expect(MagicStarterConfig.hasEmailVerificationFeatures(), isTrue);
      });

      test('hasTimezoneFeatures() returns true when config is set', () {
        Config.set('magic_starter.features.timezones', true);

        expect(MagicStarterConfig.hasTimezoneFeatures(), isTrue);
      });
    });
    // -------------------------------------------------------------------------
    // Route accessors — configured overrides
    // -------------------------------------------------------------------------

    group('route accessors (configured)', () {
      test('homeRoute() returns configured value', () {
        Config.set('magic_starter.routes.home', '/dashboard');

        expect(
          MagicStarterConfig.homeRoute(),
          equals('/dashboard'),
        );
      });

      test('loginRoute() returns configured value', () {
        Config.set('magic_starter.routes.login', '/sign-in');

        expect(
          MagicStarterConfig.loginRoute(),
          equals('/sign-in'),
        );
      });

      test('authPrefix() returns configured value', () {
        Config.set('magic_starter.routes.auth_prefix', '/authentication');

        expect(
          MagicStarterConfig.authPrefix(),
          equals('/authentication'),
        );
      });

      test('teamsPrefix() returns configured value', () {
        Config.set('magic_starter.routes.teams_prefix', '/organizations');

        expect(
          MagicStarterConfig.teamsPrefix(),
          equals('/organizations'),
        );
      });

      test('profilePrefix() returns configured value', () {
        Config.set('magic_starter.routes.profile_prefix', '/account');

        expect(
          MagicStarterConfig.profilePrefix(),
          equals('/account'),
        );
      });

      test('notificationsPrefix() returns configured value', () {
        Config.set('magic_starter.routes.notifications_prefix', '/alerts');

        expect(
          MagicStarterConfig.notificationsPrefix(),
          equals('/alerts'),
        );
      });
    });

    // -------------------------------------------------------------------------
    // Computed routes — derived from configured prefixes
    // -------------------------------------------------------------------------

    group('computed routes (configured prefixes)', () {
      test('teamCreateRoute() uses configured teamsPrefix', () {
        Config.set('magic_starter.routes.teams_prefix', '/organizations');

        expect(
          MagicStarterConfig.teamCreateRoute(),
          equals('/organizations/create'),
        );
      });

      test('teamSettingsRoute() uses configured teamsPrefix', () {
        Config.set('magic_starter.routes.teams_prefix', '/organizations');

        expect(
          MagicStarterConfig.teamSettingsRoute(),
          equals('/organizations/settings'),
        );
      });

      test('profileRoute() uses configured profilePrefix', () {
        Config.set('magic_starter.routes.profile_prefix', '/account');

        expect(
          MagicStarterConfig.profileRoute(),
          equals('/account/profile'),
        );
      });

      test('notificationsRoute() uses configured notificationsPrefix', () {
        Config.set('magic_starter.routes.notifications_prefix', '/alerts');

        expect(
          MagicStarterConfig.notificationsRoute(),
          equals('/alerts'),
        );
      });

      test('notificationPreferencesRoute() uses configured profilePrefix', () {
        Config.set('magic_starter.routes.profile_prefix', '/account');

        expect(
          MagicStarterConfig.notificationPreferencesRoute(),
          equals('/account/notifications'),
        );
      });
    });

    // -------------------------------------------------------------------------
    // Identity options (email/phone authentication)
    // -------------------------------------------------------------------------

    group('identity options (defaults)', () {
      test('emailIdentity() returns true by default', () {
        expect(MagicStarterConfig.emailIdentity(), isTrue);
      });

      test('phoneIdentity() returns false by default', () {
        expect(MagicStarterConfig.phoneIdentity(), isFalse);
      });
    });

    group('identity options (configured)', () {
      test('emailIdentity() returns false when config is set', () {
        Config.set('magic_starter.auth.email', false);

        expect(MagicStarterConfig.emailIdentity(), isFalse);
      });

      test('phoneIdentity() returns true when config is set', () {
        Config.set('magic_starter.auth.phone', true);

        expect(MagicStarterConfig.phoneIdentity(), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Locale and timezone defaults
    // -------------------------------------------------------------------------

    group('locale and timezone (defaults)', () {
      test('defaultLocale() returns "en" by default', () {
        expect(MagicStarterConfig.defaultLocale(), equals('en'));
      });

      test('defaultTimezone() returns "UTC" by default', () {
        expect(MagicStarterConfig.defaultTimezone(), equals('UTC'));
      });

      test('supportedTimezones() returns non-empty list by default', () {
        final tzs = MagicStarterConfig.supportedTimezones();
        expect(tzs, isNotEmpty);
        expect(tzs.contains('UTC'), isTrue);
      });

      test('supportedLocales() returns non-empty list by default', () {
        final locales = MagicStarterConfig.supportedLocales();
        expect(locales, isNotEmpty);
        expect(locales.contains('en'), isTrue);
        expect(locales.contains('tr'), isTrue);
      });
    });

    group('locale and timezone (configured)', () {
      test('defaultLocale() returns configured value', () {
        Config.set('magic_starter.defaults.locale', 'tr');

        expect(MagicStarterConfig.defaultLocale(), equals('tr'));
      });

      test('defaultTimezone() returns configured value', () {
        Config.set('magic_starter.defaults.timezone', 'Europe/Istanbul');

        expect(
          MagicStarterConfig.defaultTimezone(),
          equals('Europe/Istanbul'),
        );
      });
    });
  });
}
