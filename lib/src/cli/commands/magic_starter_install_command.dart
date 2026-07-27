import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;

/// Installs and configures Magic Starter inside a host Magic application.
///
/// ## Layered architecture (hybrid manifest + fluent override)
///
/// 1. `install.yaml` at `<magic_starter_root>/install.yaml` declares the
///    STATIC layer: the `magic.provider: MagicStarterServiceProvider`
///    injection into the host's `lib/config/app.dart` providers list. That
///    injection is idempotent (ConfigEditor lookahead regex no-ops on re-run)
///    and is the only manifest-expressible step.
/// 2. [resolveManifestPath] locates that file via [Isolate.resolvePackageUri]
///    starting from `package:magic_starter/magic_starter.dart`.
/// 3. [handle] validates the host is a Magic project, resolves the feature
///    selections (non-interactive `--features` branch or interactive prompt
///    loop), parses the manifest for the provider NAME, and delegates staging
///    to [stageInstaller].
/// 4. [stageInstaller] constructs the [PluginInstaller] directly (NOT via
///    [ManifestInstaller.prepare], whose `_applyMagic` would enqueue the
///    provider injection FIRST). It stages [_applyFluentOverride]'s DYNAMIC,
///    feature-gated transactional `writeFile` ops FIRST (config stub, two
///    middleware files, user / team / dashboard / routes scaffolds), then the
///    helper-backed `injectProvider` LAST. The atomic `.tmp` swap covers only
///    the writeFiles; `injectProvider` commits synchronously and does not roll
///    back, so it must trail every high-risk write (no-rollback ordering).
/// 5. After [PluginInstaller.commit] lands the transactional writes, the
///    helper-backed mutations run (main.dart inject, kernel uncomment + alias
///    inject, RSP route registration, AppServiceProvider inject-or-replace,
///    translation merge, pubspec asset). These read-modify-write the same
///    files multiple times so they cannot be expressed as deferred ops; they
///    run LAST per the no-rollback ordering contract (helper ops do not roll
///    back, so they must follow the high-risk transactional writes).
///
/// ## Test seam
///
/// [getProjectRoot], [getStubSearchPaths], [runDartFormat], and
/// [resolveManifestPath] are overridable so a test subclass can pin the
/// project root + stubs dir + manifest path and stub the `dart format`
/// side effect.
class MagicStarterInstallCommand extends ArtisanInstallCommand {
  /// Public default constructor. The provider's `commands()` list constructs
  /// this with no arguments; test fixtures subclass + override the seams.
  MagicStarterInstallCommand();

  /// Dynamic feature keys that can be toggled by user input.
  static const List<String> dynamicFeatureKeys = [
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
  String get signature => 'starter:install '
      '$baseFlags'
      '{--features= : Comma-separated feature keys for non-interactive mode}';

  @override
  String get description =>
      'Install and configure Magic Starter in your application';

  @override
  String pluginName(ArtisanContext ctx) => 'magic_starter';

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

  /// Resolves the absolute filesystem path of magic_starter's `install.yaml`.
  ///
  /// Production path: resolves `package:magic_starter/magic_starter.dart` via
  /// [Isolate.resolvePackageUri], walks two directories up to the plugin root,
  /// and returns `<plugin_root>/install.yaml` when present. Returns `null`
  /// when the manifest cannot be located so [handle] surfaces a clean error.
  ///
  /// Overridable in tests.
  Future<String?> resolveManifestPath() async {
    final resolved = await Isolate.resolvePackageUri(
      Uri.parse('package:magic_starter/magic_starter.dart'),
    );
    if (resolved == null || resolved.scheme != 'file') return null;

    final libBarrel = resolved.toFilePath();
    final pluginRoot = p.dirname(p.dirname(libBarrel));
    final manifestPath = p.join(pluginRoot, 'install.yaml');
    return File(manifestPath).existsSync() ? manifestPath : null;
  }

  /// Builds the install context rooted at the overridable [getProjectRoot] so
  /// every transactional + helper op writes into the resolved host project
  /// (and tests can redirect it at a temp directory).
  @override
  InstallContext buildContext(ArtisanContext ctx) =>
      InstallContext.real(ctx, projectRoot: projectRoot);

  @override
  Future<int> handle(ArtisanContext ctx) async {
    final bool force = isForce(ctx);

    ctx.output.info('Magic Starter Installer');

    // 1. Validate host app is a Magic project.
    final String appPath = '$projectRoot/lib/config/app.dart';
    if (!FileHelper.fileExists(appPath)) {
      throw Exception(
          'Magic Framework not detected. Run `magic install` first.');
    }

    // 2. Resolve features using interactive or non-interactive flow.
    final Map<String, bool> features = _resolveFeatureSelections(ctx);

    // 3. Resolve + parse the install.yaml manifest (the static layer).
    final manifestPath = await resolveManifestPath();
    if (manifestPath == null) {
      ctx.output.error(
        'magic_starter install.yaml could not be resolved. The plugin asset '
        'bundle is missing or the package was loaded from an unexpected '
        'location.',
      );
      return 1;
    }

    final InstallManifest manifest;
    try {
      manifest = ManifestParser.parseFile(manifestPath);
    } on FormatException catch (e) {
      ctx.output.error('install.yaml at $manifestPath: $e');
      return 1;
    } on ManifestValidationException catch (e) {
      ctx.output.error('install.yaml at $manifestPath: ${e.message}');
      return 1;
    }

    // 4. Stage the transactional feature-gated writes FIRST, then the
    //    helper-backed provider injection LAST, and commit atomically.
    final installContext = buildContext(ctx);
    final installer = stageInstaller(
      installContext,
      manifest,
      features: features,
      force: force,
    );
    await installer.commit(dryRun: isDryRun(ctx), force: force);

    // 5. Helper-backed mutations run AFTER the transactional commit. They
    //    read-modify-write the same files repeatedly (uncomment, idempotency
    //    guards, inject-or-replace) so they cannot be deferred ops; ordering
    //    them last honors the no-rollback safety contract.
    _injectIntoMain();
    _injectIntoKernel();
    _injectIntoRouteServiceProvider(features: features);
    _replaceAppServiceProvider(ctx, features: features, force: force);
    _createTranslationFile(ctx, force: force);
    _injectTranslationAssetIntoPubspec();

    // 6. Optional notification package setup.
    await _setupNotifications(ctx, features: features);

    // 7. Format host app.
    await runDartFormat(projectRoot);

    ctx.output.success('Magic Starter installation completed successfully.');
    return 0;
  }

  /// Builds the fully-staged [PluginInstaller] WITHOUT committing.
  ///
  /// Constructs the installer directly (rather than [ManifestInstaller.prepare],
  /// whose `_applyMagic` would enqueue the provider injection FIRST) and stages
  /// ops in the no-rollback-safe order:
  ///
  /// 1. The DYNAMIC, feature-gated transactional `writeFile` ops via
  ///    [_applyFluentOverride] (config, middleware, models, dashboard, routes).
  ///    The atomic `.tmp` swap covers these.
  /// 2. The helper-backed `injectProvider(manifest.magic.provider)` LAST,
  ///    guarded so an absent provider name is a no-op. The injection commits
  ///    synchronously and does not roll back, so it must trail every
  ///    high-risk write.
  ///
  /// Exposed (not private) so the ordering invariant can be asserted on
  /// `installer.pendingOps` without firing the transaction. The manifest stays
  /// authoritative for the provider name.
  PluginInstaller stageInstaller(
    InstallContext installContext,
    InstallManifest manifest, {
    required Map<String, bool> features,
    required bool force,
  }) {
    final PluginInstaller installer =
        PluginInstaller(installContext, pluginName: manifest.pluginName);

    // 1. Transactional writes FIRST (ride the atomic .tmp swap).
    _applyFluentOverride(installer, features: features, force: force);

    // 2. Helper-backed provider injection LAST (synchronous, no rollback).
    final String? provider = manifest.magic.provider;
    if (provider != null) {
      installer.injectProvider(provider);
    }

    return installer;
  }

  /// Conditional layer: stages every feature-gated transactional write onto
  /// [installer] so they commit atomically before the post-commit helper
  /// injects run.
  void _applyFluentOverride(
    PluginInstaller installer, {
    required Map<String, bool> features,
    required bool force,
  }) {
    _stageConfigFile(installer, features: features, force: force);
    _stageMiddlewareFiles(installer, force: force);
    _stageUserModel(installer, features: features, force: force);
    if (features['teams'] ?? false) {
      _stageTeamModel(installer, force: force);
    }
    _stageDashboardView(installer, force: force);
    _stageAppRoutes(installer, force: force);
  }

  Map<String, bool> _resolveFeatureSelections(ArtisanContext ctx) {
    final String? rawFeaturesOption = ctx.input.option('features') as String?;
    final bool hasFeatureFlag = rawFeaturesOption != null;
    final bool nonInteractive = isNonInteractive(ctx) || hasFeatureFlag;

    final Map<String, bool> features = {
      for (final String key in dynamicFeatureKeys) key: false,
    };

    if (nonInteractive) {
      final String rawFeatures = rawFeaturesOption ?? '';
      final Set<String> selected = rawFeatures
          .split(',')
          .map((String feature) => feature.trim())
          .where((String feature) => feature.isNotEmpty)
          .toSet();

      for (final String key in dynamicFeatureKeys) {
        features[key] = selected.contains(key);
      }

      return features;
    }

    for (final String key in dynamicFeatureKeys) {
      features[key] = Prompt.confirm(
        'Enable $key feature?',
        defaultValue: false,
      );
    }

    return features;
  }

  void _stageConfigFile(
    PluginInstaller installer, {
    required Map<String, bool> features,
    required bool force,
  }) {
    final String configPath = '$projectRoot/lib/config/magic_starter.dart';
    if (_shouldSkip(configPath, force: force)) {
      return;
    }

    final String stub = StubLoader.load(
      'install/magic_starter_config',
      searchPaths: getStubSearchPaths(),
    );

    final String rendered = StubLoader.replace(
      stub,
      {
        for (final String key in dynamicFeatureKeys)
          'feature_$key': (features[key] ?? false).toString(),
      },
    );

    installer.writeFile(targetPath: configPath, content: rendered);
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
      // Anchor on the `title:` argument without requiring an immediate closing
      // paren so both `MagicApplication(title: 'X')` and the multi-argument
      // `MagicApplication(title: 'X', titleSuffix: 'Y')` form are matched.
      // Group 1 is the title; group 2 is the remaining arguments (empty for the
      // single-argument form) preserved verbatim after the injected windTheme.
      content = content.replaceFirstMapped(
        RegExp(r"MagicApplication\(\s*title:\s*'([^']*)'([^)]*)\)"),
        (Match m) {
          // The trailing args (group 2) already carry their own leading comma
          // for the multi-argument form (", titleSuffix: 'Y'"); only the
          // single-argument form (empty group 2) needs a comma after
          // windTheme. Emitting an unconditional comma would produce ",,".
          final String rest = m[2] ?? '';
          return 'MagicApplication(\n'
              '      title: \'${m[1]}\',\n'
              '      windTheme: windTheme${rest.isEmpty ? ',' : rest}\n'
              '    )';
        },
      );
      FileHelper.writeFile(mainPath, content);
    }
  }

  void _stageMiddlewareFiles(
    PluginInstaller installer, {
    required bool force,
  }) {
    _stageMiddlewareFile(
      installer,
      force: force,
      stubName: 'install/ensure_authenticated',
      targetPath: '$projectRoot/lib/app/middleware/ensure_authenticated.dart',
    );

    _stageMiddlewareFile(
      installer,
      force: force,
      stubName: 'install/redirect_if_authenticated',
      targetPath:
          '$projectRoot/lib/app/middleware/redirect_if_authenticated.dart',
    );
  }

  void _stageMiddlewareFile(
    PluginInstaller installer, {
    required bool force,
    required String stubName,
    required String targetPath,
  }) {
    if (_shouldSkip(targetPath, force: force)) {
      return;
    }

    final String content = StubLoader.load(
      stubName,
      searchPaths: getStubSearchPaths(),
    );

    installer.writeFile(targetPath: targetPath, content: content);
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

  void _replaceAppServiceProvider(
    ArtisanContext ctx, {
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
        ctx,
        targetPath: targetPath,
        features: features,
      );
      return;
    }

    final String stub = StubLoader.load(
      'install/app_service_provider',
      searchPaths: getStubSearchPaths(),
    );

    // The team callbacks are rendered INSIDE the generated `bootstrap()` call
    // rather than as a separate statement, because `bootstrap()` takes all
    // three or none: a partial set throws an ArgumentError, and omitting them
    // while the teams feature is enabled throws a StateError. Emitting them as
    // one indivisible group is what keeps the generated provider valid.
    final String teamParams = (features['teams'] ?? false)
        ? '''
            currentTeam: () => User.current.currentTeam?.toMagicStarterTeam(),
            allTeams: () => User.current.allTeams.map((t) => t.toMagicStarterTeam()).toList(),
            onSwitch: (teamId) => MagicStarterTeamController.instance.switchTeam(teamId),
'''
        : '';

    const String teamsImport = '';

    final String socialLoginBlock = (features['social_login'] ?? false)
        ? '''
    // 4. Register social login button builder.
    MagicStarter.useSocialLogin((context, isLoading) {
      // TODO: return your social login widget.
      return const SizedBox.shrink();
    });
'''
        : '';

    final String notificationsBlock = (features['notifications'] ?? false)
        ? '''
    // 5. Register notification type mapper callback.
    MagicStarter.useNotificationTypeMapper((type) {
      return (icon: Icons.info_outline, colorClass: 'text-blue-500');
    });
'''
        : '';

    final String rendered = StubLoader.replace(
      stub,
      {
        'teams_import': teamsImport,
        'team_params': teamParams,
        'social_login_block': socialLoginBlock,
        'notifications_block': notificationsBlock,
      },
    );

    FileHelper.writeFile(targetPath, rendered);
    ctx.output
        .warning('Overwritten: lib/app/providers/app_service_provider.dart');
  }

  /// Injects essential Magic Starter code into an existing AppServiceProvider.
  ///
  /// Adds imports and boot-time configuration calls that are required for the
  /// starter plugin to function. Each injection is idempotent — it checks for
  /// the presence of a marker string before adding code.
  void _injectIntoExistingAppServiceProvider(
    ArtisanContext ctx, {
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

    // 2a. setUserFactory (magic's own Auth session-restoration factory).
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

    // 2c. bootstrap(): the starter's required identity contract in a single
    //    call: user model, logout, locale options and, only when the teams
    //    feature is enabled, the team resolver trio (bootstrap() rejects a
    //    partial team-callback set, so the trio is emitted all together or
    //    not at all). Guarded on the literal call string rather than on each
    //    former use*() call name, so re-running the installer on an
    //    already-bootstrapped provider does not append a second call; the
    //    string is specific enough that no other generated code can match it.
    if (!content.contains('MagicStarter.bootstrap(')) {
      final String teamArgs = (features['teams'] ?? false)
          ? '''
      currentTeam: () => User.current.currentTeam?.toMagicStarterTeam(),
      allTeams: () => User.current.allTeams.map((t) => t.toMagicStarterTeam()).toList(),
      onSwitch: (teamId) => MagicStarterTeamController.instance.switchTeam(teamId),
'''
          : '';

      content = _injectBeforeBootClosingBrace(
        content,
        '''

    // Magic Starter: Register the required identity contract in one call.
    MagicStarter.bootstrap(
      userFactory: (data) => User.fromMap(data),
      onLogout: () async {
        await Auth.logout();
        MagicRoute.to(MagicStarterConfig.loginRoute());
      },
      locales: {
        'en': 'English',
      },
$teamArgs    );
''',
      );
    }

    FileHelper.writeFile(targetPath, content);
    ctx.output.info('Injected: lib/app/providers/app_service_provider.dart');
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

  void _createTranslationFile(
    ArtisanContext ctx, {
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
      ctx.output.info('Merged: $relativePath');
    } else if (exists && force) {
      // Force — overwrite entirely.
      JsonEditor.mergeJsonData(targetPath, sourceData, force: true);
      ctx.output.warning('Overwritten: $relativePath');
    } else {
      // Fresh write — target does not exist.
      JsonEditor.mergeJsonData(targetPath, sourceData);
      ctx.output.success('Created: $relativePath');
    }
  }

  void _stageUserModel(
    PluginInstaller installer, {
    required bool force,
    required Map<String, bool> features,
  }) {
    final String targetPath = '$projectRoot/lib/app/models/user.dart';
    if (_shouldSkip(targetPath, force: force)) {
      return;
    }

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
    final List<dynamic> data = getAttribute('all_teams') as List<dynamic>? ?? [];
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
    installer.writeFile(targetPath: targetPath, content: rendered);
  }

  void _stageTeamModel(
    PluginInstaller installer, {
    required bool force,
  }) {
    final String targetPath = '$projectRoot/lib/app/models/team.dart';
    if (_shouldSkip(targetPath, force: force)) {
      return;
    }

    final String stub = StubLoader.load(
      'install/team',
      searchPaths: getStubSearchPaths(),
    );

    installer.writeFile(targetPath: targetPath, content: stub);
  }

  void _stageDashboardView(
    PluginInstaller installer, {
    required bool force,
  }) {
    final String targetPath =
        '$projectRoot/lib/resources/views/dashboard_view.dart';
    if (_shouldSkip(targetPath, force: force)) {
      return;
    }

    final String stub = StubLoader.load(
      'install/dashboard_view',
      searchPaths: getStubSearchPaths(),
    );

    Directory('$projectRoot/lib/resources/views').createSync(recursive: true);
    installer.writeFile(targetPath: targetPath, content: stub);
  }

  void _stageAppRoutes(
    PluginInstaller installer, {
    required bool force,
  }) {
    final String targetPath = '$projectRoot/lib/routes/app.dart';

    // When routes file already exists and --force is not set, inject the
    // dashboard imports and layout group into the existing routes file.
    // That read-modify-write cannot be a deferred op, so it runs eagerly here
    // (the file already exists, so no transactional write is staged).
    if (FileHelper.fileExists(targetPath) && !force) {
      _injectIntoExistingAppRoutes(targetPath: targetPath);
      return;
    }

    final String stub = StubLoader.load(
      'install/app_routes',
      searchPaths: getStubSearchPaths(),
    );

    Directory('$projectRoot/lib/routes').createSync(recursive: true);
    installer.writeFile(targetPath: targetPath, content: stub);
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
      importStatement: "import 'package:magic_starter/magic_starter.dart';",
    );
    ConfigEditor.addImportToFile(
      filePath: targetPath,
      importStatement: "import '../resources/views/dashboard_view.dart';",
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
      }
    }
  }

  /// Returns `true` when [path] already exists and [force] is not set, meaning
  /// the transactional write should be skipped to preserve the existing file.
  bool _shouldSkip(String path, {required bool force}) {
    return FileHelper.fileExists(path) && !force;
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

    // Early return if no REAL (uncommented) assets: key in the flutter section
    // (a plain contains() would match the commented `# assets:` example).
    if (!RegExp(r'^\s*assets:', multiLine: true).hasMatch(flutterSection)) {
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

    // Skip if a REAL (uncommented) assets: key already exists. A plain
    // `contains('assets:')` would match the commented `# assets:` example that
    // `flutter create` ships, causing this to bail out and append a SECOND
    // `flutter:` section -> duplicate top-level key -> invalid YAML.
    if (RegExp(r'^\s*assets:', multiLine: true).hasMatch(flutterSection)) {
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

  Future<void> _setupNotifications(
    ArtisanContext ctx, {
    required Map<String, bool> features,
  }) async {
    if (!(features['notifications'] ?? false)) {
      return;
    }

    final String pubspecPath = '$projectRoot/pubspec.yaml';
    if (FileHelper.fileExists(pubspecPath)) {
      try {
        ConfigEditor.addDependencyToPubspec(
          pubspecPath: pubspecPath,
          name: 'magic_notifications',
          version: '^0.0.1-alpha.1',
        );
      } catch (_) {
        // Ignore YAML update failures to keep install resilient.
      }
    }

    // OneSignal setup needs a user-specific App ID, so it cannot be auto-run
    // here. magic_notifications also has no standalone entrypoint post
    // artisan-migration; its installer surfaces through the host app's artisan
    // binary. Point the operator at the correct command instead of shelling out.
    ctx.output.info(
      'Notifications enabled. Complete OneSignal setup by running:\n'
      '  dart run <app>:artisan notifications:install --app-id=<your-onesignal-app-id>',
    );
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
