import 'package:magic/magic.dart';

/// Feature toggle helper for Magic Starter.
///
/// All opt-in features default to `false` — matching the Laravel backend
/// where the `features` array is empty by default. Each feature must be
/// explicitly enabled in the host app's `magic_starter` config.
class MagicStarterConfig {
  MagicStarterConfig._();

  static const bool _defaultTeams = false;
  static const bool _defaultProfilePhotos = false;
  static const bool _defaultRegistration = false;
  static const bool _defaultSocialLogin = false;
  static const bool _defaultTwoFactor = false;
  static const bool _defaultSessions = false;
  static const bool _defaultExtendedProfile = false;
  static const bool _defaultNotifications = false;
  static const bool _defaultGuestAuth = false;
  static const bool _defaultPhoneOtp = false;
  static const bool _defaultNewsletter = false;
  static const bool _defaultEmailVerification = false;
  static const bool _defaultTimezones = false;
  static const bool _defaultEmailIdentity = true;
  static const bool _defaultPhoneIdentity = false;

  static const String _defaultLocale = 'en';
  static const String _defaultTimezone = 'UTC';

  static const List<String> _defaultSupportedLocales = [
    'en',
    'tr',
  ];

  static const String _defaultHomeRoute = '/';
  static const String _defaultLoginRoute = '/auth/login';

  static const String _defaultAuthPrefix = '/auth';
  static const String _defaultTeamsPrefix = '/teams';
  static const String _defaultProfilePrefix = '/settings';
  static const String _defaultNotificationsPrefix = '/notifications';

  // -- HTTP Configuration --
  static const int _defaultRequestTimeoutSeconds = 30;
  static const int _defaultMaxRetries = 3;

  /// Returns whether timezone list features are enabled.
  /// Returns whether timezone selection should be shown.
  /// True when either the dedicated timezones feature or
  /// the extended-profile feature (which includes timezone) is enabled.
  static bool hasTimezoneOrExtendedProfileFeatures() {
    return hasTimezoneFeatures() || hasExtendedProfileFeatures();
  }

  static bool hasTimezoneFeatures() {
    return Config.get<bool>(
          'magic_starter.features.timezones',
          _defaultTimezones,
        ) ??
        _defaultTimezones;
  }

  /// Returns whether team-related starter features are enabled.
  static bool hasTeamFeatures() {
    return Config.get<bool>('magic_starter.features.teams', _defaultTeams) ??
        _defaultTeams;
  }

  /// Returns whether profile photo starter features are enabled.
  static bool hasProfilePhotoFeatures() {
    return Config.get<bool>(
          'magic_starter.features.profile_photos',
          _defaultProfilePhotos,
        ) ??
        _defaultProfilePhotos;
  }

  /// Returns whether registration starter features are enabled.
  static bool hasRegistrationFeatures() {
    return Config.get<bool>(
          'magic_starter.features.registration',
          _defaultRegistration,
        ) ??
        _defaultRegistration;
  }

  /// Returns whether social login starter features are enabled.
  static bool hasSocialLoginFeatures() {
    return Config.get<bool>(
          'magic_starter.features.social_login',
          _defaultSocialLogin,
        ) ??
        _defaultSocialLogin;
  }

  /// Returns whether two-factor authentication starter features are enabled.
  static bool hasTwoFactorFeatures() {
    return Config.get<bool>(
          'magic_starter.features.two_factor',
          _defaultTwoFactor,
        ) ??
        _defaultTwoFactor;
  }

  /// Returns whether sessions management starter features are enabled.
  static bool hasSessionsFeatures() {
    return Config.get<bool>(
          'magic_starter.features.sessions',
          _defaultSessions,
        ) ??
        _defaultSessions;
  }

  /// Returns whether extended profile fields (phone, timezone, language) are enabled.
  static bool hasExtendedProfileFeatures() {
    return Config.get<bool>(
          'magic_starter.features.extended_profile',
          _defaultExtendedProfile,
        ) ??
        _defaultExtendedProfile;
  }

  /// Returns whether notification starter features are enabled.
  static bool hasNotificationFeatures() {
    return Config.get<bool>(
          'magic_starter.features.notifications',
          _defaultNotifications,
        ) ??
        _defaultNotifications;
  }

  /// Returns whether guest authentication starter features are enabled.
  static bool hasGuestAuthFeatures() {
    return Config.get<bool>(
          'magic_starter.features.guest_auth',
          _defaultGuestAuth,
        ) ??
        _defaultGuestAuth;
  }

  /// Returns whether phone OTP starter features are enabled.
  static bool hasPhoneOtpFeatures() {
    return Config.get<bool>(
          'magic_starter.features.phone_otp',
          _defaultPhoneOtp,
        ) ??
        _defaultPhoneOtp;
  }

  /// Returns whether newsletter starter features are enabled.
  static bool hasNewsletterFeatures() {
    return Config.get<bool>(
          'magic_starter.features.newsletter',
          _defaultNewsletter,
        ) ??
        _defaultNewsletter;
  }

  /// Returns whether email verification starter features are enabled.
  static bool hasEmailVerificationFeatures() {
    return Config.get<bool>(
          'magic_starter.features.email_verification',
          _defaultEmailVerification,
        ) ??
        _defaultEmailVerification;
  }

  /// Returns whether email-based identity is enabled.
  static bool emailIdentity() {
    return Config.get<bool>(
          'magic_starter.auth.email',
          _defaultEmailIdentity,
        ) ??
        _defaultEmailIdentity;
  }

  /// Returns whether phone-based identity is enabled.
  static bool phoneIdentity() {
    return Config.get<bool>(
          'magic_starter.auth.phone',
          _defaultPhoneIdentity,
        ) ??
        _defaultPhoneIdentity;
  }

  /// Returns the default locale for new users.
  static String defaultLocale() {
    return Config.get<String>(
          'magic_starter.defaults.locale',
          _defaultLocale,
        ) ??
        _defaultLocale;
  }

  /// Returns the default timezone for new users.
  static String defaultTimezone() {
    return Config.get<String>(
          'magic_starter.defaults.timezone',
          _defaultTimezone,
        ) ??
        _defaultTimezone;
  }

  /// Returns the list of supported locales.
  static List<String> supportedLocales() {
    return Config.get<List<String>>(
          'magic_starter.supported_locales',
          _defaultSupportedLocales,
        ) ??
        _defaultSupportedLocales;
  }

  /// Returns the configured home route path.
  static String homeRoute() {
    return Config.get<String>('magic_starter.routes.home', _defaultHomeRoute) ??
        _defaultHomeRoute;
  }

  /// Returns the configured login route path.
  static String loginRoute() {
    return Config.get<String>(
            'magic_starter.routes.login', _defaultLoginRoute) ??
        _defaultLoginRoute;
  }

  /// Returns the configured auth route prefix (e.g. `/auth`).
  static String authPrefix() {
    return Config.get<String>(
            'magic_starter.routes.auth_prefix', _defaultAuthPrefix) ??
        _defaultAuthPrefix;
  }

  /// Returns the configured teams route prefix (e.g. `/teams`).
  static String teamsPrefix() {
    return Config.get<String>(
            'magic_starter.routes.teams_prefix', _defaultTeamsPrefix) ??
        _defaultTeamsPrefix;
  }

  /// Returns the configured profile route prefix (e.g. `/settings`).
  static String profilePrefix() {
    return Config.get<String>(
            'magic_starter.routes.profile_prefix', _defaultProfilePrefix) ??
        _defaultProfilePrefix;
  }

  /// Returns the configured notifications route prefix (e.g. `/notifications`).
  static String notificationsPrefix() {
    return Config.get<String>(
          'magic_starter.routes.notifications_prefix',
          _defaultNotificationsPrefix,
        ) ??
        _defaultNotificationsPrefix;
  }

  // -- HTTP Configuration --

  /// Returns the configured request timeout in seconds.
  static int requestTimeoutSeconds() {
    return Config.get<int>(
          'magic_starter.http.timeout_seconds',
          _defaultRequestTimeoutSeconds,
        ) ??
        _defaultRequestTimeoutSeconds;
  }

  /// Returns the configured maximum number of retries for failed requests.
  static int maxRetries() {
    return Config.get<int>(
          'magic_starter.http.max_retries',
          _defaultMaxRetries,
        ) ??
        _defaultMaxRetries;
  }

  // -- Legal links --

  /// Returns the configured Terms of Service URL, or `null` if not set.
  static String? termsUrl() {
    return Config.get<String?>('magic_starter.legal.terms_url', null);
  }

  /// Returns the configured Privacy Policy URL, or `null` if not set.
  static String? privacyUrl() {
    return Config.get<String?>('magic_starter.legal.privacy_url', null);
  }

  /// Returns whether at least one legal link (terms or privacy) is configured.
  static bool hasLegalLinks() {
    return termsUrl() != null || privacyUrl() != null;
  }

  // -- Computed route paths --

  /// Full path for team creation page.
  static String teamCreateRoute() => '${teamsPrefix()}/create';

  /// Full path for team settings page.
  static String teamSettingsRoute() => '${teamsPrefix()}/settings';

  /// Full path for profile settings page.
  static String profileRoute() => '${profilePrefix()}/profile';

  /// Full path for invitation acceptance page.
  static String invitationAcceptRoute(String token) =>
      '/invitations/$token/accept';

  /// Full path for the notifications list page.
  static String notificationsRoute() => notificationsPrefix();

  /// Full path for the notification preferences/settings page.
  static String notificationPreferencesRoute() =>
      '${profilePrefix()}/notifications';

  /// Full path for the two-factor challenge page.
  static String twoFactorChallengeRoute() =>
      '${authPrefix()}/two-factor-challenge';
}
