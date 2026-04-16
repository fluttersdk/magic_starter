import 'dart:io';

import 'package:magic_cli/magic_cli.dart';

import '../helpers/magic_starter_config_helper.dart';

/// Publish Magic Starter files into the host application for customization.
///
/// This command is the Magic Starter equivalent of Laravel's `vendor:publish`.
/// It copies real plugin source files into the host app so users can edit them.
///
/// Supports granular publishing via colon-separated `--tag` values:
/// - `--tag=views` publishes all views
/// - `--tag=views:auth` publishes only auth module views
/// - `--tag=views:auth.login` publishes a single view by registry key
/// - `--tag=layouts` publishes both layouts
/// - `--tag=layouts:app` publishes a single layout
class MagicStarterPublishCommand extends Command {
  // -------------------------------------------------------------------------
  // View and layout file maps
  // -------------------------------------------------------------------------

  /// Maps view registry keys to their relative source paths within the plugin.
  static const _viewFileMap = {
    'auth.login': 'ui/views/auth/magic_starter_login_view.dart',
    'auth.register': 'ui/views/auth/magic_starter_register_view.dart',
    'auth.forgot_password':
        'ui/views/auth/magic_starter_forgot_password_view.dart',
    'auth.reset_password':
        'ui/views/auth/magic_starter_reset_password_view.dart',
    'auth.two_factor_challenge':
        'ui/views/auth/magic_starter_two_factor_challenge_view.dart',
    'auth.otp_verify': 'ui/views/auth/magic_starter_otp_verify_view.dart',
    'profile.settings':
        'ui/views/profile/magic_starter_profile_settings_view.dart',
    'teams.create': 'ui/views/teams/magic_starter_team_create_view.dart',
    'teams.settings': 'ui/views/teams/magic_starter_team_settings_view.dart',
    'teams.invitation_accept':
        'ui/views/teams/magic_starter_team_invitation_accept_view.dart',
    'notifications.list':
        'ui/views/notifications/magic_starter_notifications_list_view.dart',
    'notifications.preferences':
        'ui/views/notifications/magic_starter_notification_preferences_view.dart',
  };

  /// Maps layout registry keys to their relative source paths within the plugin.
  static const _layoutFileMap = {
    'app': 'ui/layouts/magic_starter_app_layout.dart',
    'guest': 'ui/layouts/magic_starter_guest_layout.dart',
  };
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
      help: 'Publish group: config, views, layouts, middleware, lang, all.\n'
          'Granular: views:auth, views:auth.login, layouts:app.',
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
    return MagicStarterConfigHelper.resolvePluginSourceDir(
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

    // Parse colon-separated tag: group[:scope].
    final parts = tag.split(':');
    final group = parts[0];
    final scope = parts.length > 1 ? parts.sublist(1).join(':') : null;

    final published = <String>[];

    // 1. Publish each requested tag group.
    if (group == 'config' || group == 'all') {
      published.addAll(
        _publishConfig(
          projectRoot,
          pluginSourceDir,
          force,
        ),
      );
    }

    if (group == 'views' || group == 'all') {
      published.addAll(
        _publishViewsWithScope(
          projectRoot,
          pluginSourceDir,
          force,
          scope,
        ),
      );
    }

    if (group == 'layouts' || group == 'all') {
      published.addAll(
        _publishLayoutsWithScope(
          projectRoot,
          pluginSourceDir,
          force,
          scope,
        ),
      );
    }

    if (group == 'middleware' || group == 'all') {
      published.addAll(
        _publishMiddleware(
          projectRoot,
          pluginSourceDir,
          force,
        ),
      );
    }

    if (group == 'lang' || group == 'all') {
      published.addAll(
        _publishLang(
          projectRoot,
          pluginSourceDir,
          force,
        ),
      );
    }

    // 2. Validate unknown tag groups.
    const knownGroups = {
      'config',
      'views',
      'layouts',
      'middleware',
      'lang',
      'all'
    };
    if (!knownGroups.contains(group)) {
      error('Unknown tag: $tag');
      return;
    }

    // 3. Report result summary.
    if (published.isEmpty) {
      warn('No files were published.');
      return;
    }

    success('Published ${published.length} file(s).');

    // 4. Auto-wire published views/layouts into AppServiceProvider.
    if (group == 'views' || group == 'layouts' || group == 'all') {
      _autoWireRegistrations(
        projectRoot: projectRoot,
        group: group,
        scope: scope,
      );
    }
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

  List<String> _publishViewsWithScope(
    String projectRoot,
    String pluginSourceDir,
    bool force,
    String? scope,
  ) {
    // No scope: publish all views (original behavior).
    if (scope == null) {
      return _publishAllViews(projectRoot, pluginSourceDir, force);
    }

    // Resolve matching entries from the view file map.
    final entries = _resolveViewEntries(scope);
    if (entries.isEmpty) {
      error('Unknown view scope: $scope');
      return [];
    }

    return _publishFileMapEntries(
      entries,
      projectRoot,
      pluginSourceDir,
      force,
      'views/starter',
    );
  }

  List<String> _publishLayoutsWithScope(
    String projectRoot,
    String pluginSourceDir,
    bool force,
    String? scope,
  ) {
    // No scope: publish all layouts.
    if (scope == null) {
      return _publishFileMapEntries(
        _layoutFileMap,
        projectRoot,
        pluginSourceDir,
        force,
        'layouts/starter',
      );
    }

    // Single layout by key.
    if (_layoutFileMap.containsKey(scope)) {
      return _publishFileMapEntries(
        {scope: _layoutFileMap[scope]!},
        projectRoot,
        pluginSourceDir,
        force,
        'layouts/starter',
      );
    }

    error('Unknown layout scope: $scope');
    return [];
  }

  /// Publishes all view files by scanning the source directory.
  List<String> _publishAllViews(
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

  /// Resolves view file map entries matching the given scope.
  ///
  /// - Exact key match (e.g., `auth.login`) returns a single entry.
  /// - Module prefix (e.g., `auth`) returns all entries starting with `auth.`.
  Map<String, String> _resolveViewEntries(String scope) {
    // Exact key match.
    if (_viewFileMap.containsKey(scope)) {
      return {scope: _viewFileMap[scope]!};
    }

    // Module prefix match (e.g., 'auth' matches 'auth.login', 'auth.register').
    final prefix = '$scope.';
    final filtered = Map.fromEntries(
      _viewFileMap.entries.where((e) => e.key.startsWith(prefix)),
    );

    return filtered;
  }

  /// Publishes files from a key-to-relative-path map.
  List<String> _publishFileMapEntries(
    Map<String, String> fileMap,
    String projectRoot,
    String pluginSourceDir,
    bool force,
    String destinationPrefix,
  ) {
    final published = <String>[];

    for (final entry in fileMap.entries) {
      final source = '$pluginSourceDir/lib/src/${entry.value}';
      final parts = entry.value.split('/');
      final fileName = parts.last;
      // Skip 'ui/views/' or 'ui/layouts/' prefix (first two segments).
      final subDirParts = parts.sublist(2, parts.length - 1);
      final destination = subDirParts.isEmpty
          ? '$projectRoot/lib/resources/$destinationPrefix/$fileName'
          : '$projectRoot/lib/resources/$destinationPrefix/${subDirParts.join('/')}/$fileName';

      published.addAll(
        _copyFile(
          source,
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

  // -------------------------------------------------------------------------
  // Auto-wire registration into AppServiceProvider
  // -------------------------------------------------------------------------

  /// Auto-wires view/layout registrations into the consumer's AppServiceProvider.
  ///
  /// Finds the `boot()` method and injects `MagicStarter.view.register()` or
  /// `MagicStarter.view.registerLayout()` calls. Idempotent: skips lines that
  /// already exist in the file.
  void _autoWireRegistrations({
    required String projectRoot,
    required String group,
    String? scope,
  }) {
    final providerPath =
        '$projectRoot/lib/app/providers/app_service_provider.dart';

    if (!FileHelper.fileExists(providerPath)) {
      warn(
        'Auto-wire: AppServiceProvider not found at '
        'lib/app/providers/app_service_provider.dart. '
        'Skipping registration injection.',
      );
      return;
    }

    String content = FileHelper.readFile(providerPath);
    final registrations = <_AutoWireEntry>[];

    // Collect view registrations.
    if (group == 'views' || group == 'all') {
      final viewEntries =
          scope != null ? _resolveViewEntries(scope) : _viewFileMap;
      for (final entry in viewEntries.entries) {
        final parts = entry.value.split('/');
        final fileName = parts.last;
        final className = _snakeToPascal(fileName.replaceAll('.dart', ''));
        final subDirParts = parts.sublist(2, parts.length - 1);
        final subDir = subDirParts.join('/');
        final importPath = subDir.isEmpty
            ? '../../resources/views/starter/$fileName'
            : '../../resources/views/starter/$subDir/$fileName';

        registrations.add(_AutoWireEntry(
          importLine: "import '$importPath';",
          registrationLine: "    MagicStarter.view.register('${entry.key}', "
              '() => const $className());',
          displayLabel: "MagicStarter.view.register('${entry.key}', ...)",
        ));
      }
    }

    // Collect layout registrations.
    if (group == 'layouts' || group == 'all') {
      final layoutEntries = <String, String>{};
      if (scope != null && _layoutFileMap.containsKey(scope)) {
        layoutEntries[scope] = _layoutFileMap[scope]!;
      } else if (scope == null) {
        layoutEntries.addAll(_layoutFileMap);
      }

      for (final entry in layoutEntries.entries) {
        final parts = entry.value.split('/');
        final fileName = parts.last;
        final className = _snakeToPascal(fileName.replaceAll('.dart', ''));
        final subDirParts = parts.sublist(2, parts.length - 1);
        final subDir = subDirParts.join('/');
        final importPath = subDir.isEmpty
            ? '../../resources/layouts/starter/$fileName'
            : '../../resources/layouts/starter/$subDir/$fileName';

        registrations.add(_AutoWireEntry(
          importLine: "import '$importPath';",
          registrationLine:
              "    MagicStarter.view.registerLayout('layout.${entry.key}', "
              '(child) => $className(child: child));',
          displayLabel:
              "MagicStarter.view.registerLayout('layout.${entry.key}', ...)",
        ));
      }
    }

    if (registrations.isEmpty) {
      return;
    }

    // Inject each registration idempotently.
    var injectedCount = 0;
    for (final reg in registrations) {
      // Check idempotency: skip if the registration line already exists.
      if (content.contains(reg.registrationLine)) {
        info('Auto-wire: Skipped (already registered) ${reg.displayLabel}');
        continue;
      }

      // Add import if not already present.
      if (!content.contains(reg.importLine)) {
        content = _addImport(content, reg.importLine);
      }

      // Inject registration before boot() closing brace.
      content = _injectBeforeBootClosingBrace(content, reg.registrationLine);
      info('Registered: ${reg.displayLabel}');
      injectedCount++;
    }

    if (injectedCount > 0) {
      FileHelper.writeFile(providerPath, content);
    }
  }

  /// Adds an import statement after the last existing import line.
  String _addImport(String content, String importLine) {
    // Find the last import line position.
    final importPattern = RegExp('^import\\s+.+;', multiLine: true);
    final matches = importPattern.allMatches(content).toList();

    if (matches.isEmpty) {
      // No imports found: prepend at the top.
      return '$importLine\n$content';
    }

    final lastImport = matches.last;
    final insertPos = lastImport.end;
    return '${content.substring(0, insertPos)}\n$importLine${content.substring(insertPos)}';
  }

  /// Injects a registration line before the closing brace of `boot()`.
  ///
  /// Uses the same second-to-last `}` strategy as the install command.
  String _injectBeforeBootClosingBrace(String content, String line) {
    final bracePositions = <int>[];
    for (var i = 0; i < content.length; i++) {
      if (content[i] == '}') {
        bracePositions.add(i);
      }
    }

    // Need at least 2 closing braces (boot + class).
    if (bracePositions.length < 2) {
      return content;
    }

    final bootBrace = bracePositions[bracePositions.length - 2];
    return '${content.substring(0, bootBrace)}$line\n  ${content.substring(bootBrace)}';
  }

  /// Converts a snake_case string to PascalCase.
  ///
  /// Example: `magic_starter_login_view` -> `MagicStarterLoginView`
  static String _snakeToPascal(String snake) {
    return snake
        .split('_')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join();
  }
}

/// Internal data class for auto-wire registration entries.
class _AutoWireEntry {
  final String importLine;
  final String registrationLine;
  final String displayLabel;

  const _AutoWireEntry({
    required this.importLine,
    required this.registrationLine,
    required this.displayLabel,
  });
}
