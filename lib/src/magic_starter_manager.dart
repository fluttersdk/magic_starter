import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'configuration/magic_starter_config.dart';
import 'facades/magic_starter.dart';
import 'models/magic_starter_auth_user.dart';
import 'models/magic_starter_nav_item.dart';
import 'models/magic_starter_team.dart';
import 'ui/layouts/magic_starter_app_layout.dart';
import 'ui/layouts/magic_starter_guest_layout.dart';
import 'ui/magic_starter_view_registry.dart';
import 'ui/views/auth/magic_starter_forgot_password_view.dart';
import 'ui/views/auth/magic_starter_login_view.dart';
import 'ui/views/auth/magic_starter_register_view.dart';
import 'ui/views/auth/magic_starter_reset_password_view.dart';
import 'ui/views/auth/magic_starter_two_factor_challenge_view.dart';
import 'ui/views/auth/magic_starter_otp_verify_view.dart';
import 'ui/views/notifications/magic_starter_notification_preferences_view.dart';
import 'ui/views/notifications/magic_starter_notifications_list_view.dart';
import 'ui/views/profile/magic_starter_profile_settings_view.dart';
import 'ui/views/teams/magic_starter_team_create_view.dart';
import 'ui/views/teams/magic_starter_team_invitation_accept_view.dart';
import 'ui/views/teams/magic_starter_team_settings_view.dart';

/// Social login builder type.
typedef SocialLoginBuilder = Widget Function(
    BuildContext context, bool isLoading);

typedef UserModelFactory = Authenticatable Function(Map<String, dynamic> data);

/// Holds team-related callbacks so plugin UI can render team data
/// without depending on app-specific models.
class MagicStarterTeamResolverConfig {
  final MagicStarterTeam? Function() currentTeam;
  final List<MagicStarterTeam> Function() allTeams;
  final Future<void> Function(dynamic teamId) onSwitch;

  const MagicStarterTeamResolverConfig({
    required this.currentTeam,
    required this.allTeams,
    required this.onSwitch,
  });
}

/// Theme configuration for navigation colors and styling.
///
/// Allows consumer apps to override the default Wind UI `text-primary` tokens
/// with custom colors, gradients, or light/dark mode-independent class names.
///
/// All fields are optional — defaults preserve the current behavior with no
/// breaking changes.
///
/// ### Example
/// ```dart
/// MagicStarter.useNavigationTheme(
///   MagicStarterNavigationTheme(
///     activeItemClassName:
///         'active:text-amber-500 active:bg-amber-500/10 dark:active:text-amber-400 dark:active:bg-amber-400/10',
///     brandClassName:
///         'text-lg font-bold bg-gradient-to-r from-primary-400 to-accent-500 bg-clip-text text-transparent',
///     bottomNavActiveClassName: 'active:text-amber-500 dark:active:text-amber-400',
///     avatarClassName: 'bg-amber-500/10 dark:bg-amber-400/10',
///     avatarTextClassName: 'text-sm font-bold text-amber-600 dark:text-amber-400',
///   ),
/// );
/// ```
class MagicStarterNavigationTheme {
  /// Active sidebar/drawer nav item className tokens.
  ///
  /// Applied to the `WDiv` that has `states: {if (isActive) 'active'}`. Each
  /// token must include the `active:` prefix so the Wind CSS state system
  /// activates it only when the item is selected.
  ///
  /// Defaults to `'active:text-primary active:bg-primary/10 dark:active:bg-primary/10'`.
  final String activeItemClassName;

  /// Hover className for sidebar/drawer nav items.
  ///
  /// Defaults to `'hover:bg-gray-100 dark:hover:bg-gray-800'`.
  final String hoverItemClassName;

  /// Brand/logo text className. Used when [brandBuilder] is `null`.
  ///
  /// Supports gradient text by combining Tailwind-like tokens, e.g.
  /// `'text-lg font-bold bg-gradient-to-r from-primary to-accent bg-clip-text text-transparent'`.
  ///
  /// Defaults to `'text-lg font-bold text-primary'`.
  final String brandClassName;

  /// Custom brand/logo widget builder.
  ///
  /// When set, renders this widget instead of the default app name text.
  /// Receives the current [BuildContext] and should return any widget
  /// (image, SVG, styled text, etc.). When `null`, falls back to a [WText]
  /// using [brandClassName].
  ///
  /// ```dart
  /// brandBuilder: (context) => Image.asset('assets/logo.png', height: 28),
  /// ```
  final Widget Function(BuildContext context)? brandBuilder;

  /// Active bottom navigation item className tokens.
  ///
  /// Applied to both the icon and label [WIcon]/[WText] widgets that have
  /// `states: isActive ? {'active'} : {}`. Each token must include the
  /// `active:` prefix.
  ///
  /// Defaults to `'active:text-primary'`.
  final String bottomNavActiveClassName;

  /// Avatar background className for the sidebar user menu.
  ///
  /// Defaults to `'bg-primary/10 dark:bg-primary/10'`.
  final String avatarClassName;

  /// Avatar text/initial color className for the sidebar user menu.
  ///
  /// Defaults to `'text-sm font-bold text-primary'`.
  final String avatarTextClassName;

  /// Profile dropdown trigger avatar background className.
  ///
  /// Used for the default circular avatar rendered in
  /// [MagicStarterUserProfileDropdown] when no custom [triggerBuilder] is set.
  ///
  /// Defaults to `'bg-gradient-to-tr from-primary to-gray-200'`.
  final String dropdownAvatarClassName;

  const MagicStarterNavigationTheme({
    this.activeItemClassName =
        'active:text-primary active:bg-primary/10 dark:active:bg-primary/10',
    this.hoverItemClassName = 'hover:bg-gray-100 dark:hover:bg-gray-800',
    this.brandClassName = 'text-lg font-bold text-primary',
    this.brandBuilder,
    this.bottomNavActiveClassName = 'active:text-primary',
    this.avatarClassName = 'bg-primary/10 dark:bg-primary/10',
    this.avatarTextClassName = 'text-sm font-bold text-primary',
    this.dropdownAvatarClassName = 'bg-gradient-to-tr from-primary to-gray-200',
  });
}

/// Configuration for app navigation sections.
///
/// Apps register these via [MagicStarter.useNavigation] to populate
/// the sidebar, drawer, and bottom navigation bar.
class MagicStarterNavigationConfig {
  /// Primary navigation items (Dashboard, Monitors, etc.).
  final List<MagicStarterNavItem> mainItems;

  /// Secondary/system navigation items (Team Members, Settings).
  final List<MagicStarterNavItem> systemItems;

  /// Bottom navigation items for mobile (subset of main).
  final List<MagicStarterNavItem> bottomItems;

  /// Profile dropdown menu items.
  ///
  /// Host apps can register additional links (e.g. Notifications, Billing)
  /// that appear in the user profile dropdown between the default
  /// "Profile Settings" link and the logout action.
  final List<MagicStarterNavItem> profileMenuItems;

  const MagicStarterNavigationConfig({
    required this.mainItems,
    this.systemItems = const [],
    this.bottomItems = const [],
    this.profileMenuItems = const [],
  });
}

/// Manager for Magic Starter.
class MagicStarterManager {
  /// Creates a new manager instance and registers default views.
  ///
  /// Intended to be instantiated by [MagicStarterServiceProvider] and
  /// resolved via IoC: `Magic.make<MagicStarterManager>('magic_starter')`.
  MagicStarterManager() {
    registerDefaultViews();
  }

  final MagicStarterViewRegistry _viewRegistry = MagicStarterViewRegistry();

  /// User model factory. Override to use your app's User model.
  UserModelFactory userFactory = (data) => MagicStarterAuthUser.fromMap(data);

  /// Team resolver callbacks. Null when not configured.
  MagicStarterTeamResolverConfig? teamResolver;

  /// Navigation config. Null when not configured (uses defaults).
  MagicStarterNavigationConfig? navigationConfig;

  /// Custom logout callback. When set, called instead of default logout.
  Future<void> Function()? onLogout;

  /// Custom header builder. When set, replaces the default header.
  Widget Function(BuildContext context, bool isDesktop)? headerBuilder;

  /// Social login builder. When set, renders custom social login buttons.
  SocialLoginBuilder? socialLoginBuilder;

  /// Custom notification type-to-icon/color mapper.
  /// When null, notification views use built-in defaults.
  MagicStarterNotificationTypeMapper? notificationTypeMapper;

  /// Navigation theme configuration. Holds color/className overrides for the
  /// app layout navigation elements (active item, brand, bottom nav, avatar).
  MagicStarterNavigationTheme navigationTheme = const MagicStarterNavigationTheme();

  /// Native language names for common locale codes.
  /// Used to generate human-readable labels from [Lang.supportedLocales].
  static const Map<String, String> _nativeLanguageNames = {
    'en': 'English',
    'tr': 'Türkçe',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'it': 'Italiano',
    'pt': 'Português',
    'nl': 'Nederlands',
    'ru': 'Русский',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'ar': 'العربية',
  };

  /// Locale options for language selection.
  ///
  /// Reads from [Lang.supportedLocales] (configured via
  /// `localization.supported_locales`)
  /// and converts them to [SelectOption] with native language labels.
  /// Override via [localeOptions] setter for custom labels.
  List<SelectOption<String>> get localeOptions {
    if (_localeOptions != null) return _localeOptions!;
    return Lang.supportedLocales
        .map(
          (locale) => SelectOption<String>(
            value: locale.languageCode,
            label: _nativeLanguageNames[locale.languageCode] ??
                locale.languageCode.toUpperCase(),
          ),
        )
        .toList(growable: false);
  }

  set localeOptions(List<SelectOption<String>> options) {
    _localeOptions = options;
  }

  List<SelectOption<String>>? _localeOptions;

  /// Guest authentication entry point builder.
  /// When set, renders custom widget for guest/anonymous login flows.
  Widget Function()? guestAuthEntryBuilder;

  /// Custom label for the newsletter signup feature.
  String? newsletterLabel;

  /// Global view registry used for plugin view overrides.
  MagicStarterViewRegistry get view => _viewRegistry;

  /// Registers plugin-provided default views if they are not overridden yet.
  void registerDefaultViews() {
    // Views
    _registerDefault('auth.login', () => const MagicStarterLoginView());
    _registerDefault('auth.register', () => const MagicStarterRegisterView());
    _registerDefault(
      'auth.forgot_password',
      () => const MagicStarterForgotPasswordView(),
    );
    _registerDefault(
      'auth.reset_password',
      () => const MagicStarterResetPasswordView(),
    );
    // Two-factor challenge — conditional on feature flag.
    if (MagicStarterConfig.hasTwoFactorFeatures()) {
      _registerDefault(
        'auth.two_factor_challenge',
        () => const MagicStarterTwoFactorChallengeView(),
      );
    }

    // Phone OTP — conditional on feature flag.
    if (MagicStarterConfig.hasPhoneOtpFeatures()) {
      _registerDefault(
        'auth.otp_verify',
        () => const MagicStarterOtpVerifyView(),
      );
    }

    // Profile — always registered.
    _registerDefault(
      'profile.settings',
      () => const MagicStarterProfileSettingsView(),
    );

    // Teams — conditional on feature flag.
    if (MagicStarterConfig.hasTeamFeatures()) {
      _registerDefault(
        'teams.create',
        () => const MagicStarterTeamCreateView(),
      );
      _registerDefault(
        'teams.settings',
        () => const MagicStarterTeamSettingsView(),
      );
      _registerDefault(
        'teams.invitation_accept',
        () => const MagicStarterTeamInvitationAcceptView(),
      );
    }

    // Notifications — conditional on feature flag.
    if (MagicStarterConfig.hasNotificationFeatures()) {
      _registerDefault(
        'notifications.list',
        () => const MagicStarterNotificationsListView(),
      );
      _registerDefault(
        'notifications.preferences',
        () => const MagicStarterNotificationPreferencesView(),
      );
    }
    // Layouts
    _registerDefaultLayout(
      'layout.guest',
      (child) => MagicStarterGuestLayout(child: child),
    );
    _registerDefaultLayout(
      'layout.app',
      (child) => MagicStarterAppLayout(child: child),
    );
  }

  void _registerDefault(String key, Widget Function() builder) {
    if (!_viewRegistry.has(key)) {
      _viewRegistry.register(key, builder);
    }
  }

  void _registerDefaultLayout(String key, Widget Function(Widget) builder) {
    if (!_viewRegistry.hasLayout(key)) {
      _viewRegistry.registerLayout(key, builder);
    }
  }

  /// Check if the starter is ready.
  /// Returns false when team features are enabled but no team resolver
  /// is configured.
  bool get isReady {
    final teamsEnabled =
        Config.get<bool>('magic_starter.features.teams', false) ?? false;
    if (teamsEnabled && teamResolver == null) {
      return false;
    }
    return true;
  }

  /// Reset manager state. Useful for test isolation.
  void reset() {
    userFactory = (data) => MagicStarterAuthUser.fromMap(data);
    teamResolver = null;
    navigationConfig = null;
    onLogout = null;
    headerBuilder = null;
    socialLoginBuilder = null;
    notificationTypeMapper = null;
    navigationTheme = const MagicStarterNavigationTheme();
    _localeOptions = null;
    guestAuthEntryBuilder = null;
    newsletterLabel = null;
    _viewRegistry.clear();
    registerDefaultViews();
  }
}
