import 'dart:io';

import 'package:magic_cli/magic_cli.dart';

import '../helpers/starter_config_helper.dart';

/// Publish Magic Starter files into the host application for customization.
///
/// This command is the Magic Starter equivalent of Laravel's `vendor:publish`.
/// It copies real plugin source files into the host app so users can edit them.
class PublishCommand extends Command {
  @override
  String get name => 'publish';

  @override
  String get description => 'Publish Magic Starter files for customization';

  @override
  void configure(ArgParser parser) {
    parser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing files.',
      defaultsTo: false,
      negatable: false,
    );

    parser.addOption(
      'tag',
      help: 'Publish group: config, views, middleware, lang, all.',
      allowed: [
        'config',
        'views',
        'middleware',
        'lang',
        'all',
      ],
      defaultsTo: 'all',
    );
  }

  /// Resolve the host project root path.
  ///
  /// Overridable in tests.
  String getProjectRoot() => FileHelper.findProjectRoot();

  /// Resolve the `magic_starter` plugin source directory.
  ///
  /// Overridable in tests.
  String? getPluginSourceDir() {
    return StarterConfigHelper.resolvePluginSourceDir(
      projectRoot: getProjectRoot(),
    );
  }

  @override
  Future<void> handle() async {
    info(ConsoleStyle.banner('Magic Starter', '0.0.1'));

    final projectRoot = getProjectRoot();
    final pluginSourceDir = getPluginSourceDir();
    final force = arguments['force'] as bool? ?? false;
    final tag = arguments['tag'] as String? ?? 'all';

    if (pluginSourceDir == null) {
      error('Could not resolve the magic_starter plugin source directory.');
      return;
    }

    final published = <String>[];

    // 1. Publish each requested tag group.
    if (tag == 'config' || tag == 'all') {
      published.addAll(
        _publishConfig(
          projectRoot,
          pluginSourceDir,
          force,
        ),
      );
    }

    if (tag == 'views' || tag == 'all') {
      published.addAll(
        _publishViews(
          projectRoot,
          pluginSourceDir,
          force,
        ),
      );
    }

    if (tag == 'middleware' || tag == 'all') {
      published.addAll(
        _publishMiddleware(
          projectRoot,
          pluginSourceDir,
          force,
        ),
      );
    }

    if (tag == 'lang' || tag == 'all') {
      published.addAll(
        _publishLang(
          projectRoot,
          pluginSourceDir,
          force,
        ),
      );
    }

    // 2. Report result summary.
    if (published.isEmpty) {
      warn('No files were published.');
      return;
    }

    success('Published ${published.length} file(s).');
  }

  List<String> _publishConfig(
    String projectRoot,
    String pluginSourceDir,
    bool force,
  ) {
    final source = '$pluginSourceDir/lib/config/magic_starter.dart';
    final destination = '$projectRoot/lib/config/magic_starter.dart';

    return _copyFile(
      source,
      destination,
      force,
    );
  }

  List<String> _publishViews(
    String projectRoot,
    String pluginSourceDir,
    bool force,
  ) {
    final sourceViewsDir = Directory('$pluginSourceDir/lib/src/ui/views');

    if (!sourceViewsDir.existsSync()) {
      warn('Views source directory not found: ${sourceViewsDir.path}');
      return [];
    }

    final published = <String>[];

    for (final entry in sourceViewsDir.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) {
        continue;
      }

      final relativePath = entry.path.substring(sourceViewsDir.path.length + 1);
      final destination =
          '$projectRoot/lib/resources/views/starter/$relativePath';

      published.addAll(
        _copyFile(
          entry.path,
          destination,
          force,
        ),
      );
    }

    return published;
  }

  List<String> _publishMiddleware(
    String projectRoot,
    String pluginSourceDir,
    bool force,
  ) {
    final published = <String>[];

    final middlewareFiles = {
      'ensure_authenticated':
          '$pluginSourceDir/assets/stubs/install/ensure_authenticated.stub',
      'redirect_if_authenticated':
          '$pluginSourceDir/assets/stubs/install/redirect_if_authenticated.stub',
    };

    for (final entry in middlewareFiles.entries) {
      published.addAll(
        _copyFile(
          entry.value,
          '$projectRoot/lib/app/middleware/${entry.key}.dart',
          force,
        ),
      );
    }

    return published;
  }

  List<String> _publishLang(
    String projectRoot,
    String pluginSourceDir,
    bool force,
  ) {
    return _copyFile(
      '$pluginSourceDir/assets/stubs/install/en.stub',
      '$projectRoot/assets/lang/en.json',
      force,
    );
  }

  List<String> _copyFile(
    String sourcePath,
    String destinationPath,
    bool force,
  ) {
    final sourceFile = File(sourcePath);

    if (!sourceFile.existsSync()) {
      warn('Source file not found: $sourcePath');
      return [];
    }

    if (FileHelper.fileExists(destinationPath) && !force) {
      warn('Skipped (already exists): $destinationPath');
      return [];
    }

    final content = FileHelper.readFile(sourcePath);
    FileHelper.ensureDirectoryExists(File(destinationPath).parent.path);
    FileHelper.writeFile(
      destinationPath,
      content,
    );

    info('Published: $destinationPath');
    return [
      destinationPath,
    ];
  }
}
