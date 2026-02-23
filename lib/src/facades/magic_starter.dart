import 'package:magic/magic.dart';

import '../magic_starter_manager.dart';
import '../models/starter_team.dart';
import '../ui/view_registry.dart';

/// Static facade for Magic Starter.
class MagicStarter {
  MagicStarter._();

  /// Get the manager instance.
  static MagicStarterManager get manager =>
      Magic.make<MagicStarterManager>('magic_starter');

  /// Global view registry accessor.
  static MagicStarterViewRegistry get view => manager.view;

  /// Set a custom user model factory.
  ///
  /// ```dart
  /// MagicStarter.useUserModel((data) => User.fromMap(data));
  /// ```
  static void useUserModel(UserModelFactory factory) {
    manager.userFactory = factory;
  }

  /// Create a user model from API data using the registered factory.
  static Authenticatable createUser(Map<String, dynamic> data) {
    return manager.userFactory(data);
  }

  /// Register team resolver callbacks.
  ///
  /// ```dart
  /// MagicStarter.useTeamResolver(
  ///   currentTeam: () => User.current.currentTeam?.toStarterTeam(),
  ///   allTeams: () => User.current.allTeams.map((t) => t.toStarterTeam()).toList(),
  ///   onSwitch: (id) => TeamController.instance.switchTeam(id),
  /// );
  /// ```
  static void useTeamResolver({
    required StarterTeam? Function() currentTeam,
    required List<StarterTeam> Function() allTeams,
    required Future<void> Function(dynamic teamId) onSwitch,
  }) {
    manager.teamResolver = TeamResolverConfig(
      currentTeam: currentTeam,
      allTeams: allTeams,
      onSwitch: onSwitch,
    );
  }

  /// Get the team resolver config, or null if not registered.
  static TeamResolverConfig? get teamResolver => manager.teamResolver;

  /// Whether a team resolver has been registered.
  static bool get hasTeamResolver => manager.teamResolver != null;

  /// Locale options for language selection.
  static List<SelectOption<String>> get localeOptions => manager.localeOptions;

  /// Check if the starter is ready.
  static bool get isReady => manager.isReady;
}
