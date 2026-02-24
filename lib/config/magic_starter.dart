/// Magic Starter Configuration Template.
///
/// This file provides a default configuration for the magic_starter plugin.
/// Host applications should copy this structure into their own `lib/config/magic_starter.dart`.
///
/// See [MagicStarterConfig] for how these values are consumed.
Map<String, dynamic> get magicStarterConfig => {
      'magic_starter': {
        'features': {
          'teams': false,
          'profile_photos': false,
          'registration': true,
        },
        'routes': {
          'home': '/',
          'login': '/auth/login',
          'auth_prefix': '/auth',
          'teams_prefix': '/teams',
          'profile_prefix': '/settings',
        },
      },
    };
