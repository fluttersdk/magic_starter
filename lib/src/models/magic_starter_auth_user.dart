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
  List<String> get fillable => ['name', 'email'];

  @override
  String? get id => getAttribute('id')?.toString();

  String? get name => get<String>('name');
  String? get email => get<String>('email');

  /// Create from API data map.
  static MagicStarterAuthUser fromMap(Map<String, dynamic> map) {
    return MagicStarterAuthUser()
      ..setRawAttributes(map, sync: true)
      ..exists = map.containsKey('id');
  }
}
