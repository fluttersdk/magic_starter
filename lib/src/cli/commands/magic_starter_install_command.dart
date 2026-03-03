import 'dart:convert';
import 'dart:io';

import 'package:magic_cli/magic_cli.dart';

/// Installs and configures Magic Starter inside a host Magic application.
class MagicStarterInstallCommand extends Command {
  /// Dynamic feature keys that can be toggled by user input.
  static const List<String> _dynamicFeatureKeys = [
    'teams',
    'registration',
    'extended_profile',
    'profile_photos',
    'social_login',
    'two_factor',
    'sessions',
    'phone_otp',
    'newsletter',
    'notifications',
    'email_verification',
    'guest_auth',
    'timezones',
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
      'registration': false,
      'extended_profile': false,
      'profile_photos': false,
      'social_login': false,
      'two_factor': false,
      'sessions': false,
      'phone_otp': false,
      'newsletter': false,
      'notifications': false,
      'email_verification': false,
      'guest_auth': false,
      'timezones': false,
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
        for (final String key in _dynamicFeatureKeys)
          'feature_$key': (features[key] ?? false).toString(),
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

  /// Inject config import, config factory, and primary color theme
  /// into the host application's main.dart.
  ///
  /// Steps:
  /// 1. Add magic_starter config import.
  /// 2. Add material.dart import (for MaterialColor/Color).
  /// 3. Inject magicStarterConfig factory into configFactories.
  /// 4. Inject WindThemeData with default primary color palette.
  /// 5. Pass windTheme to MagicApplication constructor.
  void _injectIntoMain() {
    final String mainPath = '$projectRoot/lib/main.dart';
    if (!FileHelper.fileExists(mainPath)) {
      return;
    }

    // 1. Add magic_starter config import.
    ConfigEditor.addImportToFile(
      filePath: mainPath,
      importStatement: "import 'config/magic_starter.dart';",
    );

    // 2. Ensure material.dart import (needed for MaterialColor, Color).
    ConfigEditor.addImportToFile(
      filePath: mainPath,
      importStatement: "import 'package:flutter/material.dart';",
    );

    // 3. Inject magicStarterConfig factory into configFactories.
    String content = FileHelper.readFile(mainPath);
    if (!content.contains('magicStarterConfig')) {
      ConfigEditor.insertCodeBeforePattern(
        filePath: mainPath,
        pattern: RegExp(r'^\s+\],\s*$', multiLine: true),
        code: '      () => magicStarterConfig,\n',
      );
    }

    // 4. Inject WindThemeData with default primary color palette.
    content = FileHelper.readFile(mainPath);
    if (!content.contains('WindThemeData')) {
      _injectWindTheme(mainPath);
    }
  }

  /// Inject WindThemeData variable and pass it to MagicApplication.
  ///
  /// Inserts the theme variable before `runApp(` and adds the
  /// `windTheme: windTheme` parameter to the MagicApplication
  /// constructor call.
  void _injectWindTheme(String mainPath) {
    // 1. Insert windTheme variable before runApp(.
    const String windThemeCode = '''
  final windTheme = WindThemeData(
    colors: {
      'primary': MaterialColor(0xFF7C3AED, <int, Color>{
        50: Color(0xFFF3F0FF),
        100: Color(0xFFEDE9FE),
        200: Color(0xFFDDD6FE),
        300: Color(0xFFC4B5FD),
        400: Color(0xFFA78BFA),
        500: Color(0xFF8B5CF6),
        600: Color(0xFF7C3AED),
        700: Color(0xFF6D28D9),
        800: Color(0xFF5B21B6),
        900: Color(0xFF4C1D95),
      }),
    },
  );

''';
    ConfigEditor.insertCodeBeforePattern(
      filePath: mainPath,
      pattern: RegExp(r'^\s+runApp\(', multiLine: true),
      code: windThemeCode,
    );

    // 2. Add windTheme parameter to MagicApplication constructor.
    String content = FileHelper.readFile(mainPath);
    if (content.contains('MagicApplication(') &&
        !content.contains('windTheme:')) {
      content = content.replaceFirst(
        RegExp(r"MagicApplication\(title:\s*'([^']*)'\)"),
        'MagicApplication(\n'
            '      title: \'\$1\',\n'
            '      windTheme: windTheme,\n'
            '    )',
      );
      FileHelper.writeFile(mainPath, content);
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
        callCode: '    registerMagicMagicStarterTeamRoutes();\n',
        marker: 'registerMagicMagicStarterTeamRoutes();',
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

    // When file already exists and --force is not set, inject essential
    // starter code into the existing file instead of replacing it entirely.
    // This handles the typical case where `magic install` has already
    // created the file with user customizations.
    if (FileHelper.fileExists(targetPath) && !force) {
      _injectIntoExistingAppServiceProvider(
        targetPath: targetPath,
        features: features,
      );
      return;
    }

    final String stub = StubLoader.load(
      'install/app_service_provider',
      searchPaths: getStubSearchPaths(),
    );

    final String teamsBlock = (features['teams'] ?? false)
        ? '''
    // 5. Register team resolver callback.
    MagicStarter.useTeamResolver(
      currentTeam: () => null, // TODO: return current MagicStarterTeam from Auth.user()
      allTeams: () => [], // TODO: return list of MagicStarterTeam from Auth.user()
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

  /// Injects essential Magic Starter code into an existing AppServiceProvider.
  ///
  /// Adds imports and boot-time configuration calls that are required for the
  /// starter plugin to function. Each injection is idempotent — it checks for
  /// the presence of a marker string before adding code.
  void _injectIntoExistingAppServiceProvider({
    required String targetPath,
    required Map<String, bool> features,
  }) {
    // 1. Add required imports.
    ConfigEditor.addImportToFile(
      filePath: targetPath,
      importStatement: "import 'package:flutter/material.dart';",
    );
    ConfigEditor.addImportToFile(
      filePath: targetPath,
      importStatement: "import 'package:magic_starter/magic_starter.dart';",
    );
    ConfigEditor.addImportToFile(
      filePath: targetPath,
      importStatement: "import '../models/user.dart';",
    );

    // Team model import is only added when the full stub is used (--force).
    // In inject mode, the user must add team imports when implementing the
    // team resolver manually.

    // 2. Inject essential boot() code before the closing brace of boot().
    //    Each block uses a marker to prevent duplicate injection.
    String content = FileHelper.readFile(targetPath);

    // 2a. setUserFactory + useUserModel
    //    Check for uncommented call — the magic install stub contains a
    //    commented-out example that must not trigger the idempotency guard.
    final bool hasUncommentedSetUserFactory = RegExp(
      r'^\s*Auth\.manager\.setUserFactory\(',
      multiLine: true,
    ).hasMatch(content);
    if (!hasUncommentedSetUserFactory) {
      content = _injectBeforeBootClosingBrace(
        content,
        '''
    // Magic Starter: Register user factory for auth session restoration.
    Auth.manager.setUserFactory((data) => User.fromMap(data));
    MagicStarter.useUserModel((data) => User.fromMap(data));
''',
      );
    }

    // 2b. useNavigation
    if (!content.contains('useNavigation')) {
      content = _injectBeforeBootClosingBrace(
        content,
        '''

    // Magic Starter: Navigation items for sidebar and mobile bottom bar.
    MagicStarter.useNavigation(
      mainItems: [
        MagicStarterNavItem(
          icon: Icons.dashboard_outlined,
          labelKey: 'nav.dashboard',
          path: MagicStarterConfig.homeRoute(),
        ),
        MagicStarterNavItem(
          icon: Icons.settings_outlined,
          labelKey: 'nav.settings',
          path: MagicStarterConfig.profileRoute(),
        ),
      ],
      bottomItems: [
        MagicStarterNavItem(
          icon: Icons.dashboard_outlined,
          labelKey: 'nav.dashboard',
          path: MagicStarterConfig.homeRoute(),
        ),
        MagicStarterNavItem(
          icon: Icons.settings_outlined,
          labelKey: 'nav.settings',
          path: MagicStarterConfig.profileRoute(),
        ),
      ],
    );
''',
      );
    }

    // 2c. useLogout
    if (!content.contains('useLogout')) {
      content = _injectBeforeBootClosingBrace(
        content,
        '''

    // Magic Starter: Logout callback.
    MagicStarter.useLogout(() async {
      await Auth.logout();
      MagicRoute.to(MagicStarterConfig.loginRoute());
    });
''',
      );
    }

    // 2d. useLocaleOptions
    if (!content.contains('useLocaleOptions')) {
      content = _injectBeforeBootClosingBrace(
        content,
        '''

    // Magic Starter: Supported locale options for profile settings.
    MagicStarter.useLocaleOptions({
      'en': 'English',
    });
''',
      );
    }

    FileHelper.writeFile(targetPath, content);
    info('Injected: lib/app/providers/app_service_provider.dart');
  }

  /// Injects [code] before the closing brace of the `boot()` method body.
  ///
  /// Finds the last `}` in the file (class closing brace) and the `}` right
  /// before it (boot method closing brace), then inserts [code] before that.
  String _injectBeforeBootClosingBrace(String content, String code) {
    // Find the boot() method and inject before its closing brace.
    // The pattern: last `}` is the class brace, second-to-last `}` is boot().
    final List<int> bracePositions = [];
    for (int i = 0; i < content.length; i++) {
      if (content[i] == '}') {
        bracePositions.add(i);
      }
    }

    // We need at least 2 closing braces (boot + class).
    if (bracePositions.length < 2) {
      return content;
    }

    // Insert before the second-to-last closing brace (boot method).
    final int bootBrace = bracePositions[bracePositions.length - 2];
    return '${content.substring(0, bootBrace)}$code  ${content.substring(bootBrace)}';
  }

  void _createTranslationFile({
    required bool force,
  }) {
    final String targetPath = '$projectRoot/assets/lang/en.json';
    final String relativePath = targetPath.replaceFirst('$projectRoot/', '');

    // 1. Load the stub content as a JSON map.
    final String stubContent = StubLoader.load(
      'install/en',
      searchPaths: getStubSearchPaths(),
    );
    final Map<String, dynamic> sourceData =
        jsonDecode(stubContent) as Map<String, dynamic>;

    // 2. Merge into existing file or write fresh.
    final bool exists = FileHelper.fileExists(targetPath);

    if (exists && !force) {
      // Deep-merge — preserves user-customised values, adds new keys.
      JsonEditor.mergeJsonData(targetPath, sourceData);
      info('Merged: $relativePath');
    } else if (exists && force) {
      // Force — overwrite entirely.
      JsonEditor.mergeJsonData(targetPath, sourceData, force: true);
      warn('Overwritten: $relativePath');
    } else {
      // Fresh write — target does not exist.
      JsonEditor.mergeJsonData(targetPath, sourceData);
      success('Created: $relativePath');
    }
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
    final String targetPath = '$projectRoot/lib/routes/app.dart';

    // When routes file already exists and --force is not set, inject the
    // dashboard imports and layout group into the existing routes file.
    if (FileHelper.fileExists(targetPath) && !force) {
      _injectIntoExistingAppRoutes(targetPath: targetPath);
      return;
    }

    final String stub = StubLoader.load(
      'install/app_routes',
      searchPaths: getStubSearchPaths(),
    );

    Directory('$projectRoot/lib/routes').createSync(recursive: true);

    _safeWriteFile(
      path: targetPath,
      content: stub,
      force: force,
    );
  }

  /// Injects DashboardView import and layout-wrapped route group into an
  /// existing routes/app.dart file.
  ///
  /// Each injection is idempotent — checks for markers before adding code.
  void _injectIntoExistingAppRoutes({
    required String targetPath,
  }) {
    // 1. Add imports.
    ConfigEditor.addImportToFile(
      filePath: targetPath,
      importStatement:
          "import 'package:magic_starter/magic_starter.dart';",
    );
    ConfigEditor.addImportToFile(
      filePath: targetPath,
      importStatement:
          "import '../resources/views/dashboard_view.dart';",
    );

    // 2. Inject layout group with dashboard route if not present.
    String content = FileHelper.readFile(targetPath);
    if (!content.contains('DashboardView')) {
      // Find the registerAppRoutes() function body and inject at the start.
      final RegExp bodyPattern = RegExp(
        r'(void registerAppRoutes\(\)\s*\{)',
        multiLine: true,
      );
      final Match? match = bodyPattern.firstMatch(content);
      if (match != null) {
        final String injection = '''

  // Auth-protected routes with AppLayout
  MagicRoute.group(
    layout: (child) => MagicStarter.view.makeLayout('layout.app', child: child),
    middleware: ['auth'],
    layoutId: 'app',
    routes: () {
      MagicRoute.page('/', () => const DashboardView());
    },
  );
''';
        content = content.replaceFirst(
          match.group(0)!,
          '${match.group(0)!}$injection',
        );

        // 3. Comment out the original WelcomeView '/' route to avoid conflict
        //    with the layout-wrapped DashboardView '/' route above.
        final RegExp welcomeRoute = RegExp(
          r"^(\s*)(MagicRoute\.page\('/'.*WelcomeView.*\);)",
          multiLine: true,
        );
        content = content.replaceAllMapped(welcomeRoute, (m) {
          return '${m.group(1)}// ${m.group(2)} // Replaced by DashboardView';
        });

        // 4. Comment out the WelcomeView import to avoid unused import warning.
        final RegExp welcomeImport = RegExp(
          r"^(import\s+'.*welcome_view\.dart';)",
          multiLine: true,
        );
        content = content.replaceAllMapped(welcomeImport, (m) {
          return '// ${m.group(1)} // Replaced by DashboardView';
        });

        FileHelper.writeFile(targetPath, content);
        info('Injected: lib/routes/app.dart');
      }
    }
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
