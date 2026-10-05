import 'package:magic/magic.dart';

/// Default authenticatable user for Magic Starter.
///
/// Used when the app does not override the user factory via
/// `MagicStarter.useUserModel()`.
class MagicStarterAuthUser extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => [
    'name',
    'email',
    'phone',
    'timezone',
    'language',
    'profile_photo_url',
  ];

  @override
  String? get id => getAttribute('id')?.toString();

  String? get name => get<String>('name');
  String? get email => get<String>('email');
  String? get profilePhotoUrl => get<String>('profile_photo_url');

  /// Whether the account can sign in with a password. An account created
  /// through a provider has none until the user sets one; a backend that
  /// predates social login does not send the field, and every account there
  /// has a password.
  bool get hasPassword => get<bool>('has_password') ?? true;

  /// Whether this is a device-bound guest account.
  bool get isGuest => get<bool>('is_guest') ?? false;

  /// The linked provider identities, each with `provider`, `email_at_link`,
  /// `created_at` and `revoked_at`.
  List<Map<String, dynamic>> get socialAccounts => [
    for (final account in get<List<dynamic>>('social_accounts') ?? const [])
      account as Map<String, dynamic>,
  ];

  /// When the scheduled account deletion runs, or `null` when none is.
  DateTime? get deletionScheduledAt {
    final scheduledAt = get<String>('deletion_scheduled_at');

    return scheduledAt == null ? null : DateTime.parse(scheduledAt);
  }

  /// Create from API data map.
  static MagicStarterAuthUser fromMap(Map<String, dynamic> map) {
    return MagicStarterAuthUser()
      ..setRawAttributes(map, sync: true)
      ..exists = map.containsKey('id');
  }
}
