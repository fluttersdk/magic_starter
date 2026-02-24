import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'models/magic_starter_auth_user.dart';
import 'models/starter_nav_item.dart';
import 'models/starter_team.dart';
import 'ui/layouts/app_layout.dart';
import 'ui/layouts/guest_layout.dart';
import 'ui/view_registry.dart';
import 'ui/views/auth/forgot_password_view.dart';
import 'ui/views/auth/login_view.dart';
import 'ui/views/auth/register_view.dart';
import 'ui/views/auth/reset_password_view.dart';
import 'ui/views/profile/profile_settings_view.dart';
import 'ui/views/teams/team_create_view.dart';
import 'ui/views/teams/team_invitation_accept_view.dart';
import 'ui/views/teams/team_settings_view.dart';

/// Factory type for creating authenticatable user models from API data.
typedef UserModelFactory = Authenticatable Function(Map<String, dynamic> data);

/// Holds team-related callbacks so plugin UI can render team data
/// without depending on app-specific models.
class StarterTeamResolverConfig {
  final StarterTeam? Function() currentTeam;
  final List<StarterTeam> Function() allTeams;
  final Future<void> Function(dynamic teamId) onSwitch;

  const StarterTeamResolverConfig({
    required this.currentTeam,
    required this.allTeams,
    required this.onSwitch,
  });
}

/// Configuration for app navigation sections.
///
/// Apps register these via [MagicStarter.useNavigation] to populate
/// the sidebar, drawer, and bottom navigation bar.
class StarterNavigationConfig {
  /// Primary navigation items (Dashboard, Monitors, etc.).
  final List<StarterNavItem> mainItems;

  /// Secondary/system navigation items (Team Members, Settings).
  final List<StarterNavItem> systemItems;

  /// Bottom navigation items for mobile (subset of main).
  final List<StarterNavItem> bottomItems;

  /// Profile dropdown menu items.
  ///
  /// Host apps can register additional links (e.g. Notifications, Billing)
  /// that appear in the user profile dropdown between the default
  /// "Profile Settings" link and the logout action.
  final List<StarterNavItem> profileMenuItems;

  const StarterNavigationConfig({
    required this.mainItems,
    this.systemItems = const [],
    this.bottomItems = const [],
    this.profileMenuItems = const [],
  });
}

/// Manager for Magic Starter.
class MagicStarterManager {
  static final MagicStarterManager _instance = MagicStarterManager._internal();

  factory MagicStarterManager() {
    return _instance;
  }

  MagicStarterManager._internal() {
    registerDefaultViews();
  }

  final MagicStarterViewRegistry _viewRegistry = MagicStarterViewRegistry();

  /// User model factory. Override to use your app's User model.
  UserModelFactory userFactory = (data) => MagicStarterAuthUser.fromMap(data);

  /// Team resolver callbacks. Null when not configured.
  StarterTeamResolverConfig? teamResolver;

  /// Navigation config. Null when not configured (uses defaults).
  StarterNavigationConfig? navigationConfig;

  /// Custom logout callback. When set, called instead of default logout.
  Future<void> Function()? onLogout;

  /// Custom header builder. When set, replaces the default header.
  Widget Function(BuildContext context, bool isDesktop)? headerBuilder;

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
  /// Reads from [Lang.supportedLocales] (configured via `localization.supported_locales`)
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
    _registerDefault(
      'profile.settings',
      () => const MagicStarterProfileSettingsView(),
    );
    _registerDefault('teams.create', () => const MagicStarterTeamCreateView());
    _registerDefault(
      'teams.settings',
      () => const MagicStarterTeamSettingsView(),
    );
    _registerDefault(
      'teams.invitation_accept',
      () => const MagicStarterTeamInvitationAcceptView(),
    );
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
  /// Returns false when team features are enabled but no team resolver is configured.
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
    _localeOptions = null;
    _viewRegistry.clear();
    registerDefaultViews();
  }
}
