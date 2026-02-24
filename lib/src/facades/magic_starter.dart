import 'package:magic/magic.dart';
import 'package:flutter/widgets.dart';

import '../magic_starter_manager.dart';
import '../models/starter_team.dart';
import '../models/starter_nav_item.dart';
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
  ///   onSwitch: (id) => StarterTeamController.instance.switchTeam(id),
  /// );
  /// ```
  static void useTeamResolver({
    required StarterTeam? Function() currentTeam,
    required List<StarterTeam> Function() allTeams,
    required Future<void> Function(dynamic teamId) onSwitch,
  }) {
    manager.teamResolver = StarterTeamResolverConfig(
      currentTeam: currentTeam,
      allTeams: allTeams,
      onSwitch: onSwitch,
    );
  }

  /// Get the team resolver config, or null if not registered.
  static StarterTeamResolverConfig? get teamResolver => manager.teamResolver;

  /// Whether a team resolver has been registered.
  static bool get hasTeamResolver => manager.teamResolver != null;

  /// Register navigation items for the app layout.
  ///
  /// ```dart
  /// MagicStarter.useNavigation(
  ///   mainItems: [
  ///     StarterNavItem(icon: Icons.dashboard, labelKey: 'nav.dashboard', path: '/'),
  ///   ],
  ///   systemItems: [
  ///     StarterNavItem(icon: Icons.people_outline, labelKey: 'nav.members', path: '/teams/members'),
  ///   ],
  ///   bottomItems: [
  ///     StarterNavItem(icon: Icons.dashboard_outlined, labelKey: 'nav.dashboard', path: '/'),
  ///   ],
  /// );
  /// ```
  static void useNavigation({
    required List<StarterNavItem> mainItems,
    List<StarterNavItem> systemItems = const [],
    List<StarterNavItem> bottomItems = const [],
  }) {
    manager.navigationConfig = StarterNavigationConfig(
      mainItems: mainItems,
      systemItems: systemItems,
      bottomItems: bottomItems,
    );
  }

  /// Get the navigation config, or null if not registered.
  static StarterNavigationConfig? get navigationConfig => manager.navigationConfig;

  /// Whether navigation items have been registered.
  static bool get hasNavigation => manager.navigationConfig != null;

  /// Register a custom logout callback.
  ///
  /// When set, the app layout's logout button calls this instead of
  /// the default `StarterAuthController.instance.logout()`.
  ///
  /// ```dart
  /// MagicStarter.useLogout(() async {
  ///   await Notify.logoutPush();
  ///   await SocialAuth.signOut();
  ///   await Auth.logout();
  ///   MagicRoute.to('/auth/login');
  /// });
  /// ```
  static void useLogout(Future<void> Function() callback) {
    manager.onLogout = callback;
  }

  /// Register a custom header builder.
  ///
  /// When set, replaces the default header in the app layout.
  ///
  /// ```dart
  /// MagicStarter.useHeader((context, isDesktop) {
  ///   return AppHeader(showMenuButton: !isDesktop);
  /// });
  /// ```
  static void useHeader(
    Widget Function(BuildContext context, bool isDesktop) builder,
  ) {
    manager.headerBuilder = builder;
  }

  /// Locale options for language selection.
  static List<SelectOption<String>> get localeOptions => manager.localeOptions;

  /// Check if the starter is ready.
  static bool get isReady => manager.isReady;
}
