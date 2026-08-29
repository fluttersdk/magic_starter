/// Magic Starter Configuration Template.
///
/// This file provides a default configuration for the magic_starter plugin.
/// Host applications should copy this structure into their own
/// `lib/config/magic_starter.dart`.
///
/// See [MagicStarterConfig] for how these values are consumed.
Map<String, dynamic> get magicStarterConfig => {
  'magic_starter': {
    'features': {
      'teams': false,
      'profile_photos': false,
      'registration': true,
      'two_factor': false,
      'sessions': false,
      'guest_auth': false,
      'phone_otp': false,
      'newsletter': false,
      'email_verification': false,
      'extended_profile': true,
      'social_login': true,
      'notifications': true,
      'timezones': false,
      'billing': false,
    },
    'auth': {'email': true, 'phone': false},
    'defaults': {'locale': 'en', 'timezone': 'UTC'},
    'supported_locales': ['en', 'tr'],
    'routes': {
      'home': '/',
      'login': '/auth/login',
      'auth_prefix': '/auth',
      'teams_prefix': '/teams',
      'profile_prefix': '/settings',
      'notifications_prefix': '/notifications',
      'billing': '/teams/billing',
    },
    // Required when the billing feature is on: Stripe rejects a relative
    // successUrl, cancelUrl or portal returnUrl, and the failure is only
    // logged. `starter:doctor` reports it.
    'billing': {'web_origin': null},
    'legal': {'terms_url': null, 'privacy_url': null},
  },
};
