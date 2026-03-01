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
    _replaceAppServiceProvider(
      features: features,
      force: force,
    );

    // 10. Scaffold User model.
    _createUserModel(
      force: force,
      features: features,
    );

    // 11. Scaffold Team model (only when teams feature is enabled).
    if (features['teams'] ?? false) {
      _createTeamModel(force: force);
    }

    // 12. Scaffold Dashboard view.
    _createDashboardView(force: force);

    // 13. Scaffold app routes file.
    _createAppRoutes(force: force);

    // 14. Create translations and pubspec asset entry.
    _createTranslationFile(force: force);
    _injectTranslationAssetIntoPubspec();

    // 15. Optional notification package setup.
    await _setupNotifications(features: features);

    // 16. Format host app.
    await runDartFormat(projectRoot);

    success('Magic Starter installation completed successfully.');
  }

  Map<String, bool> _resolveFeatureSelections() {
    final bool hasFeatureFlag = (option('features') as String?) != null;
    final bool nonInteractive =
        (arguments['non-interactive'] as bool? ?? false) || hasFeatureFlag;

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

    _safeWriteFile(
      path: configPath,
      content: rendered,
      force: force,
    );
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
    final String content = StubLoader.load(
      stubName,
      searchPaths: getStubSearchPaths(),
    );

    _safeWriteFile(
      path: targetPath,
      content: content,
      force: force,
    );
  }

  void _injectIntoKernel() {
    final String kernelPath = '$projectRoot/lib/app/kernel.dart';
    if (!FileHelper.fileExists(kernelPath)) {
      return;
    }

    // 1. Uncomment 'import package:magic/magic.dart' if it exists as a
    //    commented line — addImportToFile skips it due to contains() match.
    String content = FileHelper.readFile(kernelPath);
    final RegExp commentedMagicImport = RegExp(
      r"^\s*//\s*import 'package:magic/magic\.dart';\s*$",
      multiLine: true,
    );
    if (commentedMagicImport.hasMatch(content)) {
      content = content.replaceFirst(
        commentedMagicImport,
        "import 'package:magic/magic.dart';",
      );
      FileHelper.writeFile(kernelPath, content);
    }

    // 2. Add imports (addImportToFile is now safe since we uncommented).
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

    // 3. Check for UNCOMMENTED Kernel.registerAll — commented code must not
    //    trigger the idempotency guard.
    content = FileHelper.readFile(kernelPath);
    final bool hasUncommentedRegister = RegExp(
      r"^\s*Kernel\.registerAll\(",
      multiLine: true,
    ).hasMatch(content);
    if (hasUncommentedRegister) {
      return;
    }

    // 4. Inject Kernel.registerAll block before closing brace.
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
      pattern: RegExp(r'^\s*registerAppRoutes\(\);', multiLine: true),
      code: callCode,
    );
  }

  void _replaceAppServiceProvider({
    required Map<String, bool> features,
    required bool force,
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
    MagicStarter.useTeamResolver(
      currentTeam: () => null, // TODO: return current StarterTeam from Auth.user()
      allTeams: () => [], // TODO: return list of StarterTeam from Auth.user()
      onSwitch: (teamId) async {
        // TODO: implement team switching logic
      },
    );
'''
        : '';

    final String teamsImport =
        (features['teams'] ?? false) ? "import '../models/team.dart';" : '';

    final String socialLoginBlock = (features['social_login'] ?? false)
        ? '''
    // 6. Register social login button builder.
    MagicStarter.useSocialLogin((context) {
      // TODO: return your social login widget.
      return const SizedBox.shrink();
    });
'''
        : '';

    final String notificationsBlock = (features['notifications'] ?? false)
        ? '''
    // 7. Register notification type mapper callback.
    MagicStarter.useNotificationTypeMapper((type) {
      return (icon: Icons.info_outline, colorClass: 'text-blue-500');
    });
'''
        : '';

    final String rendered = StubLoader.replace(
      stub,
      {
        'teams_import': teamsImport,
        'teams_block': teamsBlock,
        'social_login_block': socialLoginBlock,
        'notifications_block': notificationsBlock,
      },
    );

    _safeWriteFile(
      path: targetPath,
      content: rendered,
      force: force,
    );
  }

  void _createTranslationFile({
    required bool force,
  }) {
    final String stub = StubLoader.load(
      'install/en',
      searchPaths: getStubSearchPaths(),
    );

    _safeWriteFile(
      path: '$projectRoot/assets/lang/en.json',
      content: stub,
      force: force,
    );
  }

  void _createUserModel({
    required bool force,
    required Map<String, bool> features,
  }) {
    final String stub = StubLoader.load(
      'install/user',
      searchPaths: getStubSearchPaths(),
    );

    final String teamsBlock = (features['teams'] ?? false)
        ? '''
  /// The user's current team.
  Team? get currentTeam {
    final Map<String, dynamic>? data = getAttribute('current_team') as Map<String, dynamic>?;
    return data != null ? Team.fromMap(data) : null;
  }

  /// All teams the user belongs to.
  List<Team> get allTeams {
    final List<dynamic> data = getAttribute('teams') as List<dynamic>? ?? [];
    return data.map((t) => Team.fromMap(t as Map<String, dynamic>)).toList();
  }
'''
        : '';

    final String teamsImport =
        (features['teams'] ?? false) ? "import 'team.dart';" : '';

    final String rendered = StubLoader.replace(
      stub,
      {
        'teams_block': teamsBlock,
        'teams_import': teamsImport,
      },
    );

    Directory('$projectRoot/lib/app/models').createSync(recursive: true);

    _safeWriteFile(
      path: '$projectRoot/lib/app/models/user.dart',
      content: rendered,
      force: force,
    );
  }

  void _createTeamModel({
    required bool force,
  }) {
    final String stub = StubLoader.load(
      'install/team',
      searchPaths: getStubSearchPaths(),
    );

    _safeWriteFile(
      path: '$projectRoot/lib/app/models/team.dart',
      content: stub,
      force: force,
    );
  }

  void _createDashboardView({
    required bool force,
  }) {
    final String stub = StubLoader.load(
      'install/dashboard_view',
      searchPaths: getStubSearchPaths(),
    );

    Directory('$projectRoot/lib/resources/views').createSync(recursive: true);

    _safeWriteFile(
      path: '$projectRoot/lib/resources/views/dashboard_view.dart',
      content: stub,
      force: force,
    );
  }

  void _createAppRoutes({
    required bool force,
  }) {
    final String stub = StubLoader.load(
      'install/app_routes',
      searchPaths: getStubSearchPaths(),
    );

    Directory('$projectRoot/lib/routes').createSync(recursive: true);

    _safeWriteFile(
      path: '$projectRoot/lib/routes/app.dart',
      content: stub,
      force: force,
    );
  }

  void _safeWriteFile({
    required String path,
    required String content,
    required bool force,
  }) {
    final String relativePath = path.replaceFirst('$projectRoot/', '');

    if (FileHelper.fileExists(path) && !force) {
      info('Skipped: $relativePath (already exists)');
      return;
    }

    if (FileHelper.fileExists(path) && force) {
      warn('Overwritten: $relativePath');
    } else {
      success('Created: $relativePath');
    }

    FileHelper.writeFile(path, content);
  }

  void _injectTranslationAssetIntoPubspec() {
    final String pubspecPath = '$projectRoot/pubspec.yaml';
    if (!FileHelper.fileExists(pubspecPath)) {
      return;
    }

    String content = FileHelper.readFile(pubspecPath);
    if (content.contains('- assets/lang/en.json')) {
      return;
    }

    // 1. Attempt to inject into existing flutter: section with assets: list.
    if (_tryInjectIntoFlutterAssets(pubspecPath, content)) {
      return;
    }

    // 2. Attempt to create assets: list in existing flutter: section.
    if (_tryCreateAssetsInFlutterSection(pubspecPath, content)) {
      return;
    }

    // 3. No flutter: section at all — append a new one.
    _appendFlutterSection(pubspecPath, content);
  }

  /// Injects the asset into an existing flutter: section that has an
  /// assets: list. Returns true if successful, false otherwise.
  bool _tryInjectIntoFlutterAssets(
    String pubspecPath,
    String content,
  ) {
    // Find the flutter: section at the start of a line.
    final flutterMatch =
        RegExp(r'^flutter:\s*$', multiLine: true).firstMatch(content);
    if (flutterMatch == null) {
      return false;
    }

    // Find the next unindented key (start of next section).
    final nextSectionMatch = RegExp(
      r'^\S',
      multiLine: true,
    ).firstMatch(content.substring(flutterMatch.end));
    final flutterEnd = nextSectionMatch != null
        ? flutterMatch.end + nextSectionMatch.start
        : content.length;
    final flutterSection = content.substring(flutterMatch.start, flutterEnd);

    // Early return if no assets: key in the flutter section.
    if (!flutterSection.contains('assets:')) {
      return false;
    }

    // Find the position of 'assets:' within the flutter section.
    final assetsMatch =
        RegExp(r'^  assets:\s*$', multiLine: true).firstMatch(flutterSection);
    if (assetsMatch == null) {
      return false;
    }

    // Find all asset items (lines starting with '    - ').
    final List<Match> assetItems = RegExp(
      r'^    - .+$',
      multiLine: true,
    ).allMatches(flutterSection.substring(assetsMatch.end)).toList();

    if (assetItems.isEmpty) {
      return false;
    }

    // Insertion point: after the last asset item.
    final lastAsset = assetItems.last;
    final injectionPoint = flutterMatch.start + assetsMatch.end + lastAsset.end;

    // Insert the new asset on a new line.
    final String updated =
        '${content.substring(0, injectionPoint)}\n    - assets/lang/en.json${content.substring(injectionPoint)}';

    FileHelper.writeFile(pubspecPath, updated);
    return true;
  }

  /// Creates an assets: list in an existing flutter: section that lacks one.
  /// Returns true if successful, false otherwise.
  bool _tryCreateAssetsInFlutterSection(
    String pubspecPath,
    String content,
  ) {
    // Find flutter: at the beginning of a line.
    final flutterMatch =
        RegExp(r'^flutter:\s*$', multiLine: true).firstMatch(content);
    if (flutterMatch == null) {
      return false;
    }

    // Find the next unindented key.
    final nextSectionMatch = RegExp(
      r'^\S',
      multiLine: true,
    ).firstMatch(content.substring(flutterMatch.end));
    final flutterEnd = nextSectionMatch != null
        ? flutterMatch.end + nextSectionMatch.start
        : content.length;
    final flutterSection = content.substring(flutterMatch.start, flutterEnd);

    // Skip if assets: already exists in the flutter section.
    if (flutterSection.contains('assets:')) {
      return false;
    }

    // Find the end of the 'flutter:' line.
    final flutterLineEnd = content.indexOf('\n', flutterMatch.end);
    if (flutterLineEnd == -1) {
      return false;
    }

    // Insert new assets list after 'flutter:' line.
    final String updated =
        '${content.substring(0, flutterLineEnd + 1)}  assets:\n    - assets/lang/en.json\n${content.substring(flutterLineEnd + 1)}';

    FileHelper.writeFile(pubspecPath, updated);
    return true;
  }

  /// Appends a new flutter: section to the end of the pubspec.yaml.
  void _appendFlutterSection(
    String pubspecPath,
    String content,
  ) {
    final String trailing = content.endsWith('\n') ? '' : '\n';
    final String updated =
        '$content${trailing}flutter:\n  assets:\n    - assets/lang/en.json\n';

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
