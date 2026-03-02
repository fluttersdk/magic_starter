import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../magic_starter_manager.dart';

/// Service provider for Magic Starter.
///
/// Register in your app's kernel:
///
/// ```dart
/// (app) => MagicStarterServiceProvider(app),
/// ```
class MagicStarterServiceProvider extends ServiceProvider {
  MagicStarterServiceProvider(super.app);

  @override
  void register() {
    // Register manager singleton.
    app.singleton('magic_starter', () => MagicStarterManager());
  }

  @override
  Future<void> boot() async {
    final teamsEnabled =
        Config.get<bool>('magic_starter.features.teams', false) ?? false;
    if (teamsEnabled && MagicStarterManager().teamResolver == null) {
      Log.warning(
        '[MagicStarter] Teams feature is enabled but no team resolver '
        'is configured. Call MagicStarter.useTeamResolver() in your AppServiceProvider.',
      );
    }

    // Register Gate abilities for profile section visibility.
    // Each ability returns true for non-guest users, false for guests.
    // Host apps can override by re-defining any ability after this provider boots.
    _registerGateAbilities();

    // 1. Check if primary color is defined in Wind UI theme.
    // 2. If not, register 'indigo' as the fallback primary color.
    // 3. Emit info log to notify about the fallback.
    _bootPrimaryColorFallback();
  }

  /// Registers Gate abilities that control profile section visibility.
  ///
  /// All abilities follow the pattern: grant access when the user is NOT a
  /// guest (i.e. `is_guest != true`). Host apps can override individual
  /// abilities by calling [Gate.define] with the same key after this
  /// provider boots.
  ///
  /// ### Defined Abilities
  ///
  /// | Ability | Controls |
  /// |---|---|
  /// | `starter.update-profile-photo` | Profile photo upload/remove section |
  /// | `starter.update-email` | Email field in profile information |
  /// | `starter.update-phone` | Phone and country code in extended profile |
  /// | `starter.update-password` | Password change section |
  /// | `starter.verify-email` | Email verification banner |
  /// | `starter.manage-two-factor` | Two-factor authentication section |
  /// | `starter.manage-newsletter` | Newsletter preferences section |
  /// | `starter.logout-sessions` | Logout/revoke buttons in browser sessions |
  /// | `starter.delete-account` | Account deletion section |
  void _registerGateAbilities() {
    bool isNotGuest(Model user, [dynamic _]) {
      return user.get<bool>('is_guest') != true;
    }

    Gate.define('starter.update-profile-photo', isNotGuest);
    Gate.define('starter.update-email', isNotGuest);
    Gate.define('starter.update-phone', isNotGuest);
    Gate.define('starter.update-password', isNotGuest);
    Gate.define('starter.verify-email', isNotGuest);
    Gate.define('starter.manage-two-factor', isNotGuest);
    Gate.define('starter.manage-newsletter', isNotGuest);
    Gate.define('starter.logout-sessions', isNotGuest);
    Gate.define('starter.delete-account', isNotGuest);
  }

  /// Boots the primary color fallback mechanism.
  ///
  /// If the host app has NOT defined a `primary` color in the Wind UI theme,
  /// this will automatically register `indigo` as the fallback primary color.
  ///
  /// Because `boot()` runs during `Magic.init()` — before `runApp()` builds
  /// the widget tree — the navigator context is not yet available. We defer
  /// the check to the first post-frame callback, when [WindTheme] is mounted
  /// and the context is guaranteed to exist.
  void _bootPrimaryColorFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = MagicRouter.instance.navigatorKey.currentContext;
      if (context == null) {
        return;
      }

      final windTheme = WindTheme.of(context);
      if (!windTheme.data.isValidColor('primary')) {
        Log.info(
            '[MagicStarter] No primary color defined — using indigo as fallback.');
        windTheme.updateTheme(
          colors: {
            'primary': windTheme.data.colors['indigo']!,
          },
        );
      }
    });
  }
}
