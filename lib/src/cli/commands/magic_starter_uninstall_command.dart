import 'dart:io';

import 'package:magic_cli/magic_cli.dart';

/// CLI command that removes Magic Starter from a host project.
///
/// This command performs a safe reverse of `install` by removing generated
/// configuration/injection lines and dependency entries while keeping user code
/// intact whenever possible.
class MagicStarterUninstallCommand extends Command {
  @override
  String get name => 'uninstall';

  @override
  String get description => 'Remove Magic Starter from the project';

  /// Resolves the host project root.
  ///
  /// Overridable in tests.
  String getProjectRoot() => FileHelper.findProjectRoot();

  /// Absolute host project root.
  String get projectRoot => getProjectRoot();

  /// Runs `dart format .` from [rootPath].
  ///
  /// Overridable in tests.
  Future<ProcessResult> runDartFormat(String rootPath) {
    return Process.run(
      'dart',
      [
        'format',
        '.',
      ],
      workingDirectory: rootPath,
    );
  }

  @override
  void configure(ArgParser parser) {
    parser.addFlag(
      'force',
      abbr: 'f',
      help: 'Skip confirmation prompt',
      defaultsTo: false,
      negatable: false,
    );
  }

  @override
  Future<void> handle() async {
    info(ConsoleStyle.banner('Magic Starter', '0.0.1'));

    final bool force = arguments['force'] as bool? ?? false;

    // 1. Show exactly what this command will remove.
    _showRemovalSummary();

    // 2. Ask for explicit confirmation unless --force is provided.
    if (!force) {
      final bool confirmed = confirm(
        'Proceed with uninstall?',
        defaultValue: false,
      );

      if (!confirmed) {
        info('Uninstall cancelled.');
        return;
      }
    }

    // 3. Execute all removals. Each step handles its own failures.
    _executeUninstall();

    // 4. Re-format host project for clean diffs.
    try {
      await runDartFormat(projectRoot);
      success('Formatted project with dart format');
    } catch (exception) {
      warn('Could not run dart format: $exception');
    }

    // 5. Show manual follow-up tasks that are intentionally not auto-removed.
    _showPlatformCleanupInstructions();

    success('Magic Starter uninstalled successfully!');
  }

  /// Prints a summary of the planned removals.
  void _showRemovalSummary() {
    info('The following will be removed:');
    info('  • lib/config/magic_starter.dart');
    info('  • magic_starter dependency from pubspec.yaml');
    info('  • Magic Starter import/provider from lib/config/app.dart');
    info('  • magic_starter import/configFactory from lib/main.dart');
    info(
        '  • Magic Starter middleware aliases/imports from lib/app/kernel.dart');
    info(
        '  • Magic Starter route imports/registrations from RouteServiceProvider');
    newLine();
  }

  /// Performs all uninstall operations.
  ///
  /// Each step is isolated with its own error handling so already-clean projects
  /// and partial installations do not crash the command.
  void _executeUninstall() {
    _safeStep(
      label: 'Delete config file',
      action: _deleteConfigFile,
    );
    _safeStep(
      label: 'Remove dependency from pubspec.yaml',
      action: _removePubspecDependency,
    );
    _safeStep(
      label: 'Remove injections from app.dart',
      action: _removeFromApp,
    );
    _safeStep(
      label: 'Remove injections from main.dart',
      action: _removeFromMain,
    );
    _safeStep(
      label: 'Remove middleware aliases from kernel.dart',
      action: _removeFromKernel,
    );
    _safeStep(
      label: 'Remove route registrations from RouteServiceProvider',
      action: _removeFromRouteServiceProvider,
    );
  }

  /// Runs [action] and converts all exceptions into warnings.
  void _safeStep({
    required String label,
    required void Function() action,
  }) {
    try {
      action();
    } catch (exception) {
      warn('$label failed: $exception');
    }
  }

  /// Deletes `lib/config/magic_starter.dart` when present.
  void _deleteConfigFile() {
    final String configPath = '$projectRoot/lib/config/magic_starter.dart';

    if (!FileHelper.fileExists(configPath)) {
      warn('Config file not found (already removed?)');
      return;
    }

    FileHelper.deleteFile(configPath);
    success('Deleted lib/config/magic_starter.dart');
  }

  /// Removes `magic_starter` from `pubspec.yaml`.
  void _removePubspecDependency() {
    final String pubspecPath = '$projectRoot/pubspec.yaml';

    if (!FileHelper.fileExists(pubspecPath)) {
      warn('pubspec.yaml not found. Skipping dependency cleanup.');
      return;
    }

    ConfigEditor.removeDependencyFromPubspec(
      pubspecPath: pubspecPath,
      name: 'magic_starter',
    );

    success('Removed magic_starter dependency from pubspec.yaml');
  }

  /// Removes Magic Starter import/provider lines from `lib/config/app.dart`.
  void _removeFromApp() {
    final String appPath = '$projectRoot/lib/config/app.dart';

    if (!FileHelper.fileExists(appPath)) {
      warn('lib/config/app.dart not found. Skipping app cleanup.');
      return;
    }

    String content = FileHelper.readFile(appPath);

    content = content.replaceAll(
      RegExp(r"import 'package:magic_starter[^']*';\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r'\s*MagicStarterServiceProvider\(\)[,]?\n?'),
      '',
    );

    content = content.replaceAll(
      RegExp(r'\s*\(app\) => MagicStarterServiceProvider\(app\)[,]?\n?'),
      '',
    );

    FileHelper.writeFile(appPath, content);
    success('Removed Magic Starter entries from lib/config/app.dart');
  }

  /// Removes Magic Starter import/configFactory lines from `lib/main.dart`.
  void _removeFromMain() {
    final String mainPath = '$projectRoot/lib/main.dart';

    if (!FileHelper.fileExists(mainPath)) {
      warn('lib/main.dart not found. Skipping main.dart cleanup.');
      return;
    }

    String content = FileHelper.readFile(mainPath);

    content = content.replaceAll(
      RegExp(r"import 'config/magic_starter\.dart';\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r'\s*\(\) => magicStarterConfig[,]?\n?'),
      '',
    );

    FileHelper.writeFile(mainPath, content);
    success('Removed Magic Starter entries from lib/main.dart');
  }

  /// Removes Magic Starter middleware imports and aliases from `lib/app/kernel.dart`.
  void _removeFromKernel() {
    final String kernelPath = '$projectRoot/lib/app/kernel.dart';

    if (!FileHelper.fileExists(kernelPath)) {
      warn('lib/app/kernel.dart not found. Skipping kernel cleanup.');
      return;
    }

    String content = FileHelper.readFile(kernelPath);

    content = content.replaceAll(
      RegExp(r"import 'package:magic_starter/src/http/middleware/[^']*';\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r"import 'middleware/ensure_authenticated\.dart';\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r"import 'middleware/redirect_if_authenticated\.dart';\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r"\s*'auth':\s*EnsureAuthenticated[,]?\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r"\s*'guest':\s*RedirectIfAuthenticated[,]?\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r"\s*'auth':\s*\(\)\s*=>\s*EnsureAuthenticated\(\)[,]?\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r"\s*'guest':\s*\(\)\s*=>\s*RedirectIfAuthenticated\(\)[,]?\n?"),
      '',
    );

    // Remove the empty Kernel.registerAll({}) block if all aliases were removed.
    content = content.replaceAll(
      RegExp(r'\s*Kernel\.registerAll\(\{\s*\}\);\n?'),
      '',
    );

    FileHelper.writeFile(kernelPath, content);
    success(
        'Removed Magic Starter middleware entries from lib/app/kernel.dart');
  }

  /// Removes Magic Starter route imports and registrations from
  /// `lib/app/providers/route_service_provider.dart`.
  void _removeFromRouteServiceProvider() {
    final String providerPath =
        '$projectRoot/lib/app/providers/route_service_provider.dart';

    if (!FileHelper.fileExists(providerPath)) {
      warn(
        'lib/app/providers/route_service_provider.dart not found. '
        'Skipping route provider cleanup.',
      );
      return;
    }

    String content = FileHelper.readFile(providerPath);

    content = content.replaceAll(
      RegExp(r"import 'package:magic_starter[^']*';\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r"import '../../routes/magic_starter[^']*';\n?"),
      '',
    );

    content = content.replaceAll(
      RegExp(r'\s*registerMagicStarterAuthRoutes\([^)]*\);\n?'),
      '',
    );

    content = content.replaceAll(
      RegExp(r'\s*registerMagicStarterProfileRoutes\([^)]*\);\n?'),
      '',
    );

    content = content.replaceAll(
      RegExp(r'\s*registerMagicStarterTeamRoutes\([^)]*\);\n?'),
      '',
    );

    content = content.replaceAll(
      RegExp(r'\s*registerMagicStarterNotificationRoutes\([^)]*\);\n?'),
      '',
    );

    FileHelper.writeFile(providerPath, content);
    success(
      'Removed Magic Starter route registrations from '
      'lib/app/providers/route_service_provider.dart',
    );
  }

  /// Prints manual cleanup instructions for intentionally untouched files.
  void _showPlatformCleanupInstructions() {
    newLine();
    warn('Manual cleanup recommended (not auto-removed):');
    info('  • AppServiceProvider custom MagicStarter integrations');
    info('  • middleware files under lib/app/middleware/');
    info('  • translation entries/files for magic_starter');
    newLine();
  }
}
