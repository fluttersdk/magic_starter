import 'package:flutter/material.dart';
import 'package:magic/magic.dart';

import '../configuration/magic_starter_theme.dart';
import '../magic_starter_manager.dart';
import '../models/magic_starter_team.dart';
import '../models/magic_starter_nav_item.dart';
import '../ui/magic_starter_view_registry.dart';

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
typedef MagicStarterNotificationTypeMapper
    = ({IconData icon, String colorClass}) Function(String type);

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
  ///   currentTeam: () => User.current.currentTeam?.toMagicStarterTeam(),
  ///   allTeams: () => User.current.allTeams.map((t) => t.toMagicStarterTeam()).toList(),
  ///   onSwitch: (id) => MagicStarterTeamController.instance.switchTeam(id),
  /// );
  /// ```
  static void useTeamResolver({
    required MagicStarterTeam? Function() currentTeam,
    required List<MagicStarterTeam> Function() allTeams,
    required Future<void> Function(dynamic teamId) onSwitch,
  }) {
    manager.teamResolver = MagicStarterTeamResolverConfig(
      currentTeam: currentTeam,
      allTeams: allTeams,
      onSwitch: onSwitch,
    );
  }

  /// Get the team resolver config, or null if not registered.
  static MagicStarterTeamResolverConfig? get teamResolver =>
      manager.teamResolver;

  /// Whether a team resolver has been registered.
  static bool get hasTeamResolver => manager.teamResolver != null;

  /// Register navigation items for the app layout.
  ///
  /// ```dart
  /// MagicStarter.useNavigation(
  ///   mainItems: [
  ///     MagicStarterNavItem(icon: Icons.dashboard, labelKey: 'nav.dashboard', path: '/'),
  ///   ],
  ///   systemItems: [
  ///     MagicStarterNavItem(icon: Icons.people_outline, labelKey: 'nav.members', path: '/teams/members'),
  ///   ],
  ///   bottomItems: [
  ///     MagicStarterNavItem(icon: Icons.dashboard_outlined, labelKey: 'nav.dashboard', path: '/'),
  ///   ],
  ///   profileMenuItems: [
  ///     MagicStarterNavItem(icon: Icons.notifications_outlined, labelKey: 'nav.notifications', path: '/notifications'),
  ///   ],
  /// );
  /// ```
  static void useNavigation({
    required List<MagicStarterNavItem> mainItems,
    List<MagicStarterNavItem> systemItems = const [],
    List<MagicStarterNavItem> bottomItems = const [],
    List<MagicStarterNavItem> profileMenuItems = const [],
  }) {
    manager.navigationConfig = MagicStarterNavigationConfig(
      mainItems: mainItems,
      systemItems: systemItems,
      bottomItems: bottomItems,
      profileMenuItems: profileMenuItems,
    );
  }

  /// Get the navigation config, or null if not registered.
  static MagicStarterNavigationConfig? get navigationConfig =>
      manager.navigationConfig;

  /// Whether navigation items have been registered.
  static bool get hasNavigation => manager.navigationConfig != null;

  /// Register a custom logout callback.
  ///
  /// When set, the app layout's logout button calls this instead of
  /// the default `MagicStarterAuthController.instance.logout()`.
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

  /// Register a custom sidebar footer builder. When set, rendered between the
  /// navigation and user menu in both the desktop sidebar and mobile drawer.
  static void useSidebarFooter(
    Widget Function(BuildContext context) builder,
  ) {
    manager.sidebarFooterBuilder = builder;
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
  static void useNotificationTypeMapper(
      MagicStarterNotificationTypeMapper mapper) {
    manager.notificationTypeMapper = mapper;
  }

  /// The registered notification type mapper, or `null` if not configured.
  static MagicStarterNotificationTypeMapper? get notificationTypeMapper =>
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

  /// Register a custom navigation theme.
  ///
  /// When set, overrides the default Wind UI `text-primary` tokens used for
  /// active nav items, brand/logo, bottom nav, and user avatar colors.
  ///
  /// All fields in [MagicStarterNavigationTheme] are optional — pass only the
  /// values you want to customise.
  ///
  /// ```dart
  /// MagicStarter.useNavigationTheme(
  ///   MagicStarterNavigationTheme(
  ///     activeItemClassName:
  ///         'active:text-amber-500 active:bg-amber-500/10 dark:active:text-amber-400 dark:active:bg-amber-400/10',
  ///     brandBuilder: (context) => Image.asset('assets/logo.png', height: 28),
  ///   ),
  /// );
  /// ```
  static void useNavigationTheme(MagicStarterNavigationTheme theme) {
    manager.navigationTheme = theme;
  }

  /// Get the active navigation theme.
  ///
  /// Returns the theme registered via [useNavigationTheme], or a default
  /// [MagicStarterNavigationTheme] instance when not configured.
  static MagicStarterNavigationTheme get navigationTheme =>
      manager.navigationTheme;

  /// Register a custom modal theme.
  ///
  /// When set, overrides the default Wind UI class names used for modal
  /// containers, headers, bodies, footers, buttons, inputs, and typography.
  ///
  /// All fields in [MagicStarterModalTheme] are optional — pass only the
  /// values you want to customise.
  ///
  /// ```dart
  /// MagicStarter.useModalTheme(
  ///   MagicStarterModalTheme(
  ///     containerClassName: 'bg-zinc-900 rounded-2xl border border-zinc-700',
  ///     primaryButtonClassName:
  ///         'px-6 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white font-semibold',
  ///     maxWidth: 560.0,
  ///   ),
  /// );
  /// ```
  static void useModalTheme(MagicStarterModalTheme theme) {
    manager.modalTheme = theme;
  }

  /// Get the active modal theme.
  ///
  /// Returns the theme registered via [useModalTheme], or a default
  /// [MagicStarterModalTheme] instance when not configured.
  static MagicStarterModalTheme get modalTheme => manager.modalTheme;

  /// Register a unified theme configuration.
  ///
  /// Sets all sub-themes (navigation, modal, form, card, page header, layout,
  /// auth) in a single call. Individual sub-themes can still be overridden
  /// afterward via [useNavigationTheme], [useModalTheme], [useFormTheme], etc.
  ///
  /// ```dart
  /// MagicStarter.useTheme(
  ///   MagicStarterTheme(
  ///     form: MagicStarterFormTheme(
  ///       inputClassName: 'rounded-xl border-2 ...',
  ///     ),
  ///     card: MagicStarterCardTheme(
  ///       surfaceClassName: 'bg-zinc-50 dark:bg-zinc-900 ...',
  ///     ),
  ///   ),
  /// );
  /// ```
  static void useTheme(MagicStarterTheme theme) {
    manager.theme = theme;
  }

  /// Get the active unified theme.
  static MagicStarterTheme get theme => manager.theme;

  /// Register a custom form theme.
  ///
  /// When set, overrides the default Wind UI class names used for form inputs,
  /// labels, placeholders, primary/secondary buttons, links, and checkboxes
  /// across all auth and profile forms.
  ///
  /// All fields in [MagicStarterFormTheme] are optional — pass only the
  /// values you want to customise.
  ///
  /// ```dart
  /// MagicStarter.useFormTheme(
  ///   MagicStarterFormTheme(
  ///     inputClassName: 'w-full px-4 py-4 rounded-xl bg-zinc-900 border border-zinc-700 text-white',
  ///     primaryButtonClassName: 'w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-xl',
  ///   ),
  /// );
  /// ```
  static void useFormTheme(MagicStarterFormTheme theme) {
    manager.formTheme = theme;
  }

  /// Get the active form theme.
  ///
  /// Returns the theme registered via [useFormTheme], or a default
  /// [MagicStarterFormTheme] instance when not configured.
  static MagicStarterFormTheme get formTheme => manager.formTheme;

  /// Register a custom auth theme.
  ///
  /// When set, overrides the default Wind UI class names used for the auth
  /// form card, title, subtitle, error banner, theme toggle, social divider,
  /// and guest/registration link styles.
  ///
  /// All fields in [MagicStarterAuthTheme] are optional — pass only the
  /// values you want to customise.
  ///
  /// ```dart
  /// MagicStarter.useAuthTheme(
  ///   MagicStarterAuthTheme(
  ///     cardClassName: 'rounded-3xl bg-zinc-900 border border-zinc-700 p-8 flex flex-col items-center',
  ///     titleClassName: 'text-3xl font-black text-white text-center',
  ///   ),
  /// );
  /// ```
  static void useAuthTheme(MagicStarterAuthTheme theme) {
    manager.authTheme = theme;
  }

  /// Get the active auth theme.
  ///
  /// Returns the theme registered via [useAuthTheme], or a default
  /// [MagicStarterAuthTheme] instance when not configured.
  static MagicStarterAuthTheme get authTheme => manager.authTheme;

  /// Register a custom card theme.
  ///
  /// When set, overrides the default Wind UI class names used for card
  /// variant backgrounds, border radius, padding, and title styles.
  ///
  /// All fields in [MagicStarterCardTheme] are optional — pass only the
  /// values you want to customise.
  ///
  /// ```dart
  /// MagicStarter.useCardTheme(
  ///   MagicStarterCardTheme(
  ///     surfaceClassName: 'bg-zinc-900 border border-zinc-700',
  ///     borderRadius: 'rounded-xl',
  ///   ),
  /// );
  /// ```
  static void useCardTheme(MagicStarterCardTheme theme) {
    manager.cardTheme = theme;
  }

  /// Get the active card theme.
  ///
  /// Returns the theme registered via [useCardTheme], or a default
  /// [MagicStarterCardTheme] instance when not configured.
  static MagicStarterCardTheme get cardTheme => manager.cardTheme;

  /// Register a custom page header theme.
  ///
  /// When set, overrides the default Wind UI class names used for the page
  /// header container, title, subtitle, and action container.
  ///
  /// All fields in [MagicStarterPageHeaderTheme] are optional — pass only the
  /// values you want to customise.
  ///
  /// ```dart
  /// MagicStarter.usePageHeaderTheme(
  ///   MagicStarterPageHeaderTheme(
  ///     titleClassName: 'text-3xl font-black text-white',
  ///   ),
  /// );
  /// ```
  static void usePageHeaderTheme(MagicStarterPageHeaderTheme theme) {
    manager.pageHeaderTheme = theme;
  }

  /// Get the active page header theme.
  ///
  /// Returns the theme registered via [usePageHeaderTheme], or a default
  /// [MagicStarterPageHeaderTheme] instance when not configured.
  static MagicStarterPageHeaderTheme get pageHeaderTheme =>
      manager.pageHeaderTheme;

  /// Register a custom layout theme.
  ///
  /// When set, overrides the default Wind UI class names and dimensions for
  /// the app layout shell: sidebar, header, content background, drawer, brand
  /// bar, and bottom navigation.
  ///
  /// All fields in [MagicStarterLayoutTheme] are optional — pass only the
  /// values you want to customise.
  ///
  /// ```dart
  /// MagicStarter.useLayoutTheme(
  ///   MagicStarterLayoutTheme(
  ///     sidebarWidth: 280,
  ///     sidebarClassName: 'h-full flex flex-col bg-zinc-900 border-r border-zinc-700',
  ///   ),
  /// );
  /// ```
  static void useLayoutTheme(MagicStarterLayoutTheme theme) {
    manager.layoutTheme = theme;
  }

  /// Get the active layout theme.
  ///
  /// Returns the theme registered via [useLayoutTheme], or a default
  /// [MagicStarterLayoutTheme] instance when not configured.
  static MagicStarterLayoutTheme get layoutTheme => manager.layoutTheme;

  /// Check if the starter is ready.
  static bool get isReady => manager.isReady;
}
