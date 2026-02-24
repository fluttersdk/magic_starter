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
  }
}
