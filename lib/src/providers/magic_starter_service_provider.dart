import 'package:magic/magic.dart';
import '../cli/commands/install_command.dart';
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

    // Register CLI install command.
    app.singleton('magic_starter.commands.install', () => InstallCommand());
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

    // 1. Check if primary color is defined in Wind UI theme.
    // 2. If not, register 'indigo' as the fallback primary color.
    // 3. Emit info log to notify about the fallback.
    _bootPrimaryColorFallback();
  }

  /// Boots the primary color fallback mechanism.
  ///
  /// If the host app has NOT defined a `primary` color in the Wind UI theme,
  /// this will automatically register `indigo` as the fallback primary color.
  void _bootPrimaryColorFallback() {
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
  }
}
