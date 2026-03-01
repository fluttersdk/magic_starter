import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../magic_starter_manager.dart';
import '../models/starter_team.dart';
import '../models/starter_nav_item.dart';
import '../ui/view_registry.dart';

/// Maps a notification type string to an icon and color class.
///
/// ### Example Usage
/// ```dart
/// MagicStarter.useNotificationTypeMapper((type) => switch (type) {
///   'monitor_down' => (icon: Icons.error_outline, colorClass: 'text-red-500'),
///   'monitor_up' => (icon: Icons.check_circle_outline, colorClass: 'text-green-500'),
///   _ => (icon: Icons.info_outline, colorClass: 'text-blue-500'),
/// });
/// ```
typedef StarterNotificationTypeMapper = ({IconData icon, String colorClass})
    Function(String type);

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
  ///   profileMenuItems: [
  ///     StarterNavItem(icon: Icons.notifications_outlined, labelKey: 'nav.notifications', path: '/notifications'),
  ///   ],
  /// );
  /// ```
  static void useNavigation({
    required List<StarterNavItem> mainItems,
    List<StarterNavItem> systemItems = const [],
    List<StarterNavItem> bottomItems = const [],
    List<StarterNavItem> profileMenuItems = const [],
  }) {
    manager.navigationConfig = StarterNavigationConfig(
      mainItems: mainItems,
      systemItems: systemItems,
      bottomItems: bottomItems,
      profileMenuItems: profileMenuItems,
    );
  }

  /// Get the navigation config, or null if not registered.
  static StarterNavigationConfig? get navigationConfig =>
      manager.navigationConfig;

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

  /// Register a custom social login buttons builder.
  ///
  /// When set, social login buttons appear on login and register pages
  /// (requires `magic_starter.features.social_login` to be enabled).
  ///
  /// ```dart
  /// MagicStarter.useSocialLogin((context, isLoading) {
  ///   return SocialLoginButtons(
  ///     loadingProvider: controller.socialLoginProvider,
  ///     onGoogle: () => controller.doSocialLogin('google'),
  ///   );
  /// });
  /// ```
  static void useSocialLogin(SocialLoginBuilder builder) {
    manager.socialLoginBuilder = builder;
  }

  /// Whether social login buttons have been registered.
  static bool get hasSocialLogin => manager.socialLoginBuilder != null;

  /// Get the social login builder, or null if not registered.
  static SocialLoginBuilder? get socialLoginBuilder =>
      manager.socialLoginBuilder;

  /// Register a custom notification type-to-icon/color mapper.
  ///
  /// When set, notification views use this mapper to resolve the icon and
  /// color class for each notification type (e.g. `monitor_down`, `monitor_up`).
  /// If not set, views fall back to built-in defaults.
  ///
  /// ### Example Usage
  /// ```dart
  /// MagicStarter.useNotificationTypeMapper((type) => switch (type) {
  ///   'monitor_down' => (icon: Icons.error_outline, colorClass: 'text-red-500'),
  ///   _ => (icon: Icons.info_outline, colorClass: 'text-blue-500'),
  /// });
  /// ```
  static void useNotificationTypeMapper(StarterNotificationTypeMapper mapper) {
    manager.notificationTypeMapper = mapper;
  }

  /// The registered notification type mapper, or `null` if not configured.
  static StarterNotificationTypeMapper? get notificationTypeMapper =>
      manager.notificationTypeMapper;

  /// Locale options for language selection.
  static List<SelectOption<String>> get localeOptions => manager.localeOptions;

  /// Register custom locale options for language selection.
  ///
  /// ```dart
  /// MagicStarter.useLocaleOptions({
  ///   'en': 'English',
  ///   'tr': 'Türkçe',
  /// });
  /// ```
  static void useLocaleOptions(Map<String, String> locales) {
    manager.localeOptions = locales.entries
        .map(
          (e) => SelectOption<String>(
            value: e.key,
            label: e.value,
          ),
        )
        .toList(growable: false);
  }

  /// Register custom timezone options.
  ///
  /// ```dart
  /// MagicStarter.useTimezoneOptions(
  ///   ['UTC', 'America/New_York', 'Europe/London'],
  /// );
  /// ```
  static void useTimezoneOptions(List<String>? timezones) {
    manager.timezoneOptions = timezones;
  }

  /// Get the registered timezone options, or `null` if not configured.
  static List<String>? get timezoneOptions => manager.timezoneOptions;

  /// Register a guest authentication entry point builder.
  ///
  /// When set, renders a custom widget for guest/anonymous login flows.
  ///
  /// ```dart
  /// MagicStarter.useGuestAuthEntry(() => GuestLoginPage());
  /// ```
  static void useGuestAuthEntry(Widget Function() builder) {
    manager.guestAuthEntryBuilder = builder;
  }

  /// Get the registered guest auth entry builder, or `null` if not configured.
  static Widget Function()? get guestAuthEntryBuilder =>
      manager.guestAuthEntryBuilder;

  /// Register a custom label for the newsletter signup feature.
  ///
  /// ```dart
  /// MagicStarter.useNewsletterLabel('Subscribe to our updates');
  /// ```
  static void useNewsletterLabel(String label) {
    manager.newsletterLabel = label;
  }

  /// Get the registered newsletter label, or `null` if not configured.
  static String? get newsletterLabel => manager.newsletterLabel;

  /// Check if the starter is ready.
  static bool get isReady => manager.isReady;
}
