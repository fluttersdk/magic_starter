import 'dart:convert';
import 'dart:io';

import 'package:magic_cli/magic_cli.dart';

/// Installs and configures Magic Starter inside a host Magic application.
class InstallCommand extends Command {
  /// Dynamic feature keys that can be toggled by user input.
  static const List<String> _dynamicFeatureKeys = [
    'teams',
    'social_login',
    'two_factor',
    'sessions',
    'phone_otp',
    'newsletter',
    'notifications',
    'email_verification',
  ];

  @override
  String get name => 'install';

  @override
  String get description =>
      'Install and configure Magic Starter in your application';

  /// Absolute project root path.
  String get projectRoot => getProjectRoot();

  /// Resolves the host project root.
  ///
  /// Overridable in tests.
  String getProjectRoot() {
    return FileHelper.findProjectRoot();
  }

  /// Stub lookup paths.
  ///
  /// Overridable in tests.
  List<String> getStubSearchPaths() {
    return [
      _resolvePluginStubsDir(),
      '${Directory.current.path}/assets/stubs',
    ];
  }

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

  /// Runs magic_notifications installer.
  ///
  /// Overridable in tests.
  Future<ProcessResult> runNotificationInstaller(String rootPath) {
    return Process.run(
      'dart',
      [
        'run',
        'magic_notifications',
        'install',
        '--non-interactive',
      ],
      workingDirectory: rootPath,
    );
  }

  @override
  void configure(ArgParser parser) {
    parser
      ..addFlag(
        'force',
        abbr: 'f',
        defaultsTo: false,
        negatable: false,
        help: 'Overwrite generated files when they already exist.',
      )
      ..addFlag(
        'non-interactive',
        defaultsTo: false,
        negatable: false,
        help: 'Run installer without interactive questions.',
      )
      ..addOption(
        'features',
        help: 'Comma-separated feature keys for non-interactive mode.',
      );
  }

  @override
  Future<void> handle() async {
    final bool force = arguments['force'] as bool? ?? false;

    info('Magic Starter Installer');

    // 1. Validate host app is a Magic project.
    final String appPath = '$projectRoot/lib/config/app.dart';
    if (!FileHelper.fileExists(appPath)) {
      throw Exception(
          'Magic Framework not detected. Run `magic install` first.');
    }

    // 2. Resolve features using interactive or non-interactive flow.
    final Map<String, bool> features = _resolveFeatureSelections();

    // 3. Create config file from stub.
    _createConfigFile(
      force: force,
      features: features,
    );

    // 4. Inject provider into app config.
    _injectIntoApp();

    // 5. Inject config factory into main.dart.
    _injectIntoMain();

    // 6. Create middleware files.
    _createMiddlewareFiles(force: force);

    // 7. Inject middleware aliases into kernel.
    _injectIntoKernel();

    // 8. Inject starter route registrations into RouteServiceProvider.
    _injectIntoRouteServiceProvider(features: features);

    // 9. Replace AppServiceProvider from stub.
    _replaceAppServiceProvider(features: features);

    // 10. Create translations and pubspec asset entry.
    _createTranslationFile();
    _injectTranslationAssetIntoPubspec();

    // 11. Optional notification package setup.
    await _setupNotifications(features: features);

    // 12. Format host app.
    await runDartFormat(projectRoot);

    success('Magic Starter installation completed successfully.');
  }

  Map<String, bool> _resolveFeatureSelections() {
    final bool nonInteractive = arguments['non-interactive'] as bool? ?? false;

    final Map<String, bool> features = {
      'teams': false,
      'social_login': false,
      'two_factor': false,
      'sessions': false,
      'phone_otp': false,
      'newsletter': false,
      'notifications': false,
      'email_verification': false,
    };

    if (nonInteractive) {
      final String rawFeatures = option('features') as String? ?? '';
      final Set<String> selected = rawFeatures
          .split(',')
          .map((String feature) => feature.trim())
          .where((String feature) => feature.isNotEmpty)
          .toSet();

      for (final String key in _dynamicFeatureKeys) {
        features[key] = selected.contains(key);
      }

      return features;
    }

    for (final String key in _dynamicFeatureKeys) {
      features[key] = confirm(
        'Enable $key feature?',
        defaultValue: false,
      );
    }

    return features;
  }

  void _createConfigFile({
    required bool force,
    required Map<String, bool> features,
  }) {
    final String configPath = '$projectRoot/lib/config/magic_starter.dart';

    if (FileHelper.fileExists(configPath) && !force) {
      warn('Config already exists. Use --force to overwrite.');
      return;
    }

    final String stub = StubLoader.load(
      'install/magic_starter_config',
      searchPaths: getStubSearchPaths(),
    );

    final String rendered = StubLoader.replace(
      stub,
      {
        'feature_teams': (features['teams'] ?? false).toString(),
        'feature_social_login': (features['social_login'] ?? false).toString(),
        'feature_two_factor': (features['two_factor'] ?? false).toString(),
        'feature_sessions': (features['sessions'] ?? false).toString(),
        'feature_phone_otp': (features['phone_otp'] ?? false).toString(),
        'feature_newsletter': (features['newsletter'] ?? false).toString(),
        'feature_notifications':
            (features['notifications'] ?? false).toString(),
        'feature_email_verification':
            (features['email_verification'] ?? false).toString(),
      },
    );

    FileHelper.writeFile(configPath, rendered);
    success('Created lib/config/magic_starter.dart');
  }

  void _injectIntoApp() {
    final String appPath = '$projectRoot/lib/config/app.dart';

    ConfigEditor.addImportToFile(
      filePath: appPath,
      importStatement: "import 'package:magic_starter/magic_starter.dart';",
    );

    final String content = FileHelper.readFile(appPath);
    if (!content.contains('MagicStarterServiceProvider')) {
      ConfigEditor.insertCodeBeforePattern(
        filePath: appPath,
        pattern: RegExp(r'^\s+\],\s*$', multiLine: true),
        code: '      (app) => MagicStarterServiceProvider(app),\n',
      );
    }
  }

  void _injectIntoMain() {
    final String mainPath = '$projectRoot/lib/main.dart';
    if (!FileHelper.fileExists(mainPath)) {
      return;
    }

    ConfigEditor.addImportToFile(
      filePath: mainPath,
      importStatement: "import 'config/magic_starter.dart';",
    );

    final String content = FileHelper.readFile(mainPath);
    if (!content.contains('magicStarterConfig')) {
      ConfigEditor.insertCodeBeforePattern(
        filePath: mainPath,
        pattern: RegExp(r'^\s+\],\s*$', multiLine: true),
        code: '      () => magicStarterConfig,\n',
      );
    }
  }

  void _createMiddlewareFiles({
    required bool force,
  }) {
    _createMiddlewareFile(
      force: force,
      stubName: 'install/ensure_authenticated',
      targetPath: '$projectRoot/lib/app/middleware/ensure_authenticated.dart',
    );

    _createMiddlewareFile(
      force: force,
      stubName: 'install/redirect_if_authenticated',
      targetPath:
          '$projectRoot/lib/app/middleware/redirect_if_authenticated.dart',
    );
  }

  void _createMiddlewareFile({
    required bool force,
    required String stubName,
    required String targetPath,
  }) {
    if (FileHelper.fileExists(targetPath) && !force) {
      return;
    }

    final String content = StubLoader.load(
      stubName,
      searchPaths: getStubSearchPaths(),
    );

    FileHelper.writeFile(targetPath, content);
  }

  void _injectIntoKernel() {
    final String kernelPath = '$projectRoot/lib/app/kernel.dart';
    if (!FileHelper.fileExists(kernelPath)) {
      return;
    }

    ConfigEditor.addImportToFile(
      filePath: kernelPath,
      importStatement: "import 'package:magic/magic.dart';",
    );
    ConfigEditor.addImportToFile(
      filePath: kernelPath,
      importStatement: "import 'middleware/ensure_authenticated.dart';",
    );
    ConfigEditor.addImportToFile(
      filePath: kernelPath,
      importStatement: "import 'middleware/redirect_if_authenticated.dart';",
    );

    final String content = FileHelper.readFile(kernelPath);
    if (content.contains("'auth': () => EnsureAuthenticated(),") &&
        content.contains("'guest': () => RedirectIfAuthenticated(),")) {
      return;
    }

    final String registerBlock = '''
  Kernel.registerAll({
    'auth': () => EnsureAuthenticated(),
    'guest': () => RedirectIfAuthenticated(),
  });
''';

    final String updated = content.replaceFirst(
      RegExp(r'}\s*$'),
      '$registerBlock\n}',
    );

    FileHelper.writeFile(kernelPath, updated);
  }

  void _injectIntoRouteServiceProvider({
    required Map<String, bool> features,
  }) {
    final String providerPath =
        '$projectRoot/lib/app/providers/route_service_provider.dart';

    if (!FileHelper.fileExists(providerPath)) {
      return;
    }

    ConfigEditor.addImportToFile(
      filePath: providerPath,
      importStatement: "import 'package:magic_starter/magic_starter.dart';",
    );

    _insertCallIfMissing(
      filePath: providerPath,
      callCode: '    registerMagicStarterAuthRoutes();\n',
      marker: 'registerMagicStarterAuthRoutes();',
    );

    _insertCallIfMissing(
      filePath: providerPath,
      callCode: '    registerMagicStarterProfileRoutes();\n',
      marker: 'registerMagicStarterProfileRoutes();',
    );

    if (features['teams'] ?? false) {
      _insertCallIfMissing(
        filePath: providerPath,
        callCode: '    registerMagicStarterTeamRoutes();\n',
        marker: 'registerMagicStarterTeamRoutes();',
      );
    }

    if (features['notifications'] ?? false) {
      _insertCallIfMissing(
        filePath: providerPath,
        callCode: '    registerMagicStarterNotificationRoutes();\n',
        marker: 'registerMagicStarterNotificationRoutes();',
      );
    }
  }

  void _insertCallIfMissing({
    required String filePath,
    required String marker,
    required String callCode,
  }) {
    final String content = FileHelper.readFile(filePath);
    if (content.contains(marker)) {
      return;
    }

    ConfigEditor.insertCodeBeforePattern(
      filePath: filePath,
      pattern: RegExp(r'\s*registerAppRoutes\(\);'),
      code: callCode,
    );
  }

  void _replaceAppServiceProvider({
    required Map<String, bool> features,
  }) {
    final String targetPath =
        '$projectRoot/lib/app/providers/app_service_provider.dart';

    final String stub = StubLoader.load(
      'install/app_service_provider',
      searchPaths: getStubSearchPaths(),
    );

    final String teamsBlock = (features['teams'] ?? false)
        ? '''
    // 5. Register team resolver callback.
    MagicStarter.useTeamResolver((userId) async {
      return [];
    });
'''
        : '';

    final String notificationsBlock = (features['notifications'] ?? false)
        ? '''
    // 6. Register notification type mapper callback.
    MagicStarter.useNotificationTypeMapper((notification) {
      return notification.type;
    });
'''
        : '';

    final String rendered = StubLoader.replace(
      stub,
      {
        'teams_block': teamsBlock,
        'notifications_block': notificationsBlock,
      },
    );

    FileHelper.writeFile(targetPath, rendered);
  }

  void _createTranslationFile() {
    final String stub = StubLoader.load(
      'install/en',
      searchPaths: getStubSearchPaths(),
    );

    FileHelper.writeFile(
      '$projectRoot/assets/lang/en.json',
      stub,
    );
  }

  void _injectTranslationAssetIntoPubspec() {
    final String pubspecPath = '$projectRoot/pubspec.yaml';
    if (!FileHelper.fileExists(pubspecPath)) {
      return;
    }

    final String content = FileHelper.readFile(pubspecPath);
    if (content.contains('- assets/lang/en.json')) {
      return;
    }

    if (content.contains('flutter:\n  assets:')) {
      final String updated = content.replaceFirst(
        'flutter:\n  assets:\n',
        'flutter:\n  assets:\n    - assets/lang/en.json\n',
      );
      FileHelper.writeFile(pubspecPath, updated);
      return;
    }

    final String updated =
        '$content\nflutter:\n  assets:\n    - assets/lang/en.json\n';
    FileHelper.writeFile(pubspecPath, updated);
  }

  Future<void> _setupNotifications({
    required Map<String, bool> features,
  }) async {
    if (!(features['notifications'] ?? false)) {
      return;
    }

    final String pubspecPath = '$projectRoot/pubspec.yaml';
    if (FileHelper.fileExists(pubspecPath)) {
      try {
        ConfigEditor.addPathDependencyToPubspec(
          pubspecPath: pubspecPath,
          name: 'magic_notifications',
          path: '../magic_notifications',
        );
      } catch (_) {
        // Ignore YAML update failures to keep install resilient.
      }
    }

    try {
      await runNotificationInstaller(projectRoot);
    } catch (_) {
      warn('Failed to run magic_notifications installer automatically.');
    }
  }

  String _resolvePluginStubsDir() {
    final String packageConfigPath =
        '${Directory.current.path}/.dart_tool/package_config.json';

    if (!File(packageConfigPath).existsSync()) {
      return '${Directory.current.path}/assets/stubs';
    }

    final String content = File(packageConfigPath).readAsStringSync();

    try {
      final Map<String, dynamic> decoded =
          jsonDecode(content) as Map<String, dynamic>;

      final List<dynamic> packages =
          decoded['packages'] as List<dynamic>? ?? [];
      for (final dynamic package in packages) {
        if (package is Map<String, dynamic> &&
            package['name'] == 'magic_starter') {
          final String rootUri = package['rootUri'] as String;

          String packageRoot;
          if (rootUri.startsWith('file://')) {
            packageRoot = Uri.parse(rootUri).toFilePath();
          } else if (rootUri.startsWith('../')) {
            packageRoot = File(packageConfigPath)
                .parent
                .uri
                .resolve(rootUri)
                .toFilePath();
          } else {
            packageRoot = rootUri;
          }

          return '$packageRoot/assets/stubs'.replaceAll('//', '/');
        }
      }
    } catch (_) {
      // Fall through to local fallback path.
    }

    return '${Directory.current.path}/assets/stubs';
  }
}
