import 'package:magic/magic.dart';

/// Feature toggle helper for Magic Starter.
///
/// Defaults are intentionally explicit:
/// - teams: false (opt-in)
/// - profile_photos: false (opt-in)
/// - registration: true (enabled by default)
/// - social_login: false (opt-in)
class MagicStarterConfig {
  MagicStarterConfig._();

  static const bool _defaultTeams = false;
  static const bool _defaultProfilePhotos = false;
  static const bool _defaultRegistration = true;
  static const bool _defaultSocialLogin = false;

  static const String _defaultHomeRoute = '/';
  static const String _defaultLoginRoute = '/auth/login';

  static const String _defaultAuthPrefix = '/auth';
  static const String _defaultTeamsPrefix = '/teams';
  static const String _defaultProfilePrefix = '/settings';

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

  // -- Computed route paths --

  /// Full path for team creation page.
  static String teamCreateRoute() => '${teamsPrefix()}/create';

  /// Full path for team settings page.
  static String teamSettingsRoute() => '${teamsPrefix()}/settings';

  /// Full path for profile settings page.
  static String profileRoute() => '${profilePrefix()}/profile';
}
