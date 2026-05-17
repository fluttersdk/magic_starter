import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;

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
class MagicStarterPublishCommand extends ArtisanCommand {
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
  String get name => 'starter:publish';

  @override
  String get description => 'Publish Magic Starter files for customization';

  @override
  CommandBoot get boot => CommandBoot.none;

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
  Future<int> handle(ArtisanContext ctx) async {
    ctx.output.info(ConsoleStyle.banner('Magic Starter', '0.0.1'));

    final projectRoot = getProjectRoot();
    final pluginSourceDir = getPluginSourceDir();
    final force = (ctx.input.option('force') as bool?) ?? false;
    final tag = (ctx.input.option('tag') as String?) ?? 'all';

    if (pluginSourceDir == null) {
      ctx.output.error(
          'Could not resolve the magic_starter plugin source directory.');
      return 1;
    }

    // Parse colon-separated tag: group[:scope].
    final parts = tag.split(':');
    final group = parts[0];
    final scope = parts.length > 1 ? parts.sublist(1).join(':') : null;

    final published = <String>[];

    // 1. Publish each requested tag group.
    if (group == 'config' || group == 'all') {
      published.addAll(
        _publishConfig(ctx, projectRoot, pluginSourceDir, force),
      );
    }

    if (group == 'views' || group == 'all') {
      published.addAll(
        _publishViewsWithScope(
          ctx,
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
          ctx,
          projectRoot,
          pluginSourceDir,
          force,
          scope,
        ),
      );
    }

    if (group == 'middleware' || group == 'all') {
      published.addAll(
        _publishMiddleware(ctx, projectRoot, pluginSourceDir, force),
      );
    }

    if (group == 'lang' || group == 'all') {
      published.addAll(
        _publishLang(ctx, projectRoot, pluginSourceDir, force),
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
      ctx.output.error('Unknown tag: $tag');
      return 1;
    }

    // 3. Report result summary.
    if (published.isEmpty) {
      ctx.output.warning('No files were published.');
      return 0;
    }

    ctx.output.success('Published ${published.length} file(s).');

    // 4. Auto-wire published views/layouts into AppServiceProvider.
    if (group == 'views' || group == 'layouts' || group == 'all') {
      _autoWireRegistrations(
        ctx: ctx,
        projectRoot: projectRoot,
        group: group,
        scope: scope,
      );
    }

    return 0;
  }

  List<String> _publishConfig(
    ArtisanContext ctx,
    String projectRoot,
    String pluginSourceDir,
    bool force,
  ) {
    final source = '$pluginSourceDir/lib/config/magic_starter.dart';
    final destination = '$projectRoot/lib/config/magic_starter.dart';

    return _copyFile(ctx, source, destination, force);
  }

  List<String> _publishViewsWithScope(
    ArtisanContext ctx,
    String projectRoot,
    String pluginSourceDir,
    bool force,
    String? scope,
  ) {
    // No scope: publish all views (original behavior).
    if (scope == null) {
      return _publishAllViews(ctx, projectRoot, pluginSourceDir, force);
    }

    // Resolve matching entries from the view file map.
    final entries = _resolveViewEntries(scope);
    if (entries.isEmpty) {
      ctx.output.error('Unknown view scope: $scope');
      return [];
    }

    return _publishFileMapEntries(
      ctx,
      entries,
      projectRoot,
      pluginSourceDir,
      force,
      'views/starter',
    );
  }

  List<String> _publishLayoutsWithScope(
    ArtisanContext ctx,
    String projectRoot,
    String pluginSourceDir,
    bool force,
    String? scope,
  ) {
    // No scope: publish all layouts.
    if (scope == null) {
      return _publishFileMapEntries(
        ctx,
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
        ctx,
        {scope: _layoutFileMap[scope]!},
        projectRoot,
        pluginSourceDir,
        force,
        'layouts/starter',
      );
    }

    ctx.output.error('Unknown layout scope: $scope');
    return [];
  }

  /// Publishes all view files by scanning the source directory.
  List<String> _publishAllViews(
    ArtisanContext ctx,
    String projectRoot,
    String pluginSourceDir,
    bool force,
  ) {
    final sourceViewsDir =
        Directory(p.join(pluginSourceDir, 'lib', 'src', 'ui', 'views'));

    if (!sourceViewsDir.existsSync()) {
      ctx.output
          .warning('Views source directory not found: ${sourceViewsDir.path}');
      return [];
    }

    final published = <String>[];

    for (final entry in sourceViewsDir.listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) {
        continue;
      }

      final relativePath = p.relative(entry.path, from: sourceViewsDir.path);
      final destination = p.join(
          projectRoot, 'lib', 'resources', 'views', 'starter', relativePath);

      published.addAll(
        _copyFile(ctx, entry.path, destination, force),
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
    ArtisanContext ctx,
    Map<String, String> fileMap,
    String projectRoot,
    String pluginSourceDir,
    bool force,
    String destinationPrefix,
  ) {
    final published = <String>[];

    for (final entry in fileMap.entries) {
      final source = p.join(pluginSourceDir, 'lib', 'src', entry.value);
      final parts = p.split(entry.value);
      final fileName = parts.last;
      // Skip 'ui/views/' or 'ui/layouts/' prefix (first two segments).
      final subDirParts = parts.sublist(2, parts.length - 1);
      final destination = subDirParts.isEmpty
          ? p.join(projectRoot, 'lib', 'resources', destinationPrefix, fileName)
          : p.join(projectRoot, 'lib', 'resources', destinationPrefix,
              p.joinAll(subDirParts), fileName);

      published.addAll(
        _copyFile(ctx, source, destination, force),
      );
    }

    return published;
  }

  List<String> _publishMiddleware(
    ArtisanContext ctx,
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
          ctx,
          entry.value,
          '$projectRoot/lib/app/middleware/${entry.key}.dart',
          force,
        ),
      );
    }

    return published;
  }

  List<String> _publishLang(
    ArtisanContext ctx,
    String projectRoot,
    String pluginSourceDir,
    bool force,
  ) {
    return _copyFile(
      ctx,
      '$pluginSourceDir/assets/stubs/install/en.stub',
      '$projectRoot/assets/lang/en.json',
      force,
    );
  }

  List<String> _copyFile(
    ArtisanContext ctx,
    String sourcePath,
    String destinationPath,
    bool force,
  ) {
    final sourceFile = File(sourcePath);

    if (!sourceFile.existsSync()) {
      ctx.output.warning('Source file not found: $sourcePath');
      return [];
    }

    if (FileHelper.fileExists(destinationPath) && !force) {
      ctx.output.warning('Skipped (already exists): $destinationPath');
      return [];
    }

    final content = FileHelper.readFile(sourcePath);
    FileHelper.ensureDirectoryExists(File(destinationPath).parent.path);
    FileHelper.writeFile(
      destinationPath,
      content,
    );

    ctx.output.info('Published: $destinationPath');
    return [destinationPath];
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
    required ArtisanContext ctx,
    required String projectRoot,
    required String group,
    String? scope,
  }) {
    final providerPath =
        '$projectRoot/lib/app/providers/app_service_provider.dart';

    if (!FileHelper.fileExists(providerPath)) {
      ctx.output.warning(
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
        final parts = p.split(entry.value);
        final fileName = parts.last;
        final className = _snakeToPascal(fileName.replaceAll('.dart', ''));
        final subDirParts = parts.sublist(2, parts.length - 1);
        // Dart imports always use POSIX separators.
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
        final parts = p.split(entry.value);
        final fileName = parts.last;
        final className = _snakeToPascal(fileName.replaceAll('.dart', ''));
        final subDirParts = parts.sublist(2, parts.length - 1);
        // Dart imports always use POSIX separators.
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
        ctx.output.info(
            'Auto-wire: Skipped (already registered) ${reg.displayLabel}');
        continue;
      }

      // Add import if not already present.
      if (!content.contains(reg.importLine)) {
        content = _addImport(content, reg.importLine);
      }

      // Inject registration before boot() closing brace.
      content = _injectBeforeBootClosingBrace(content, reg.registrationLine);
      ctx.output.info('Registered: ${reg.displayLabel}');
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
  /// Locates the `boot()` method signature, then finds its matching closing
  /// brace by tracking brace depth. This is robust even when the provider
  /// contains additional methods or nested classes.
  String _injectBeforeBootClosingBrace(String content, String line) {
    // Find the boot() method signature.
    final bootPattern = RegExp(r'(void|Future<void>)\s+boot\s*\(');
    final bootMatch = bootPattern.firstMatch(content);
    if (bootMatch == null) {
      return content;
    }

    // Find the opening brace of boot().
    final openBrace = content.indexOf('{', bootMatch.end);
    if (openBrace == -1) {
      return content;
    }

    // Track brace depth to find the matching closing brace.
    var depth = 1;
    var pos = openBrace + 1;
    while (pos < content.length && depth > 0) {
      if (content[pos] == '{') {
        depth++;
      } else if (content[pos] == '}') {
        depth--;
      }
      if (depth > 0) pos++;
    }

    if (depth != 0) {
      return content;
    }

    // pos is now at boot()'s closing brace.
    return '${content.substring(0, pos)}$line\n  ${content.substring(pos)}';
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
