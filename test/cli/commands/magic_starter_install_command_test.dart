import 'dart:io';

import 'package:magic_starter/src/cli/commands/magic_starter_install_command.dart';
import 'package:test/test.dart';

class TestMagicStarterInstallCommand extends MagicStarterInstallCommand {
  TestMagicStarterInstallCommand({
    required this.projectRoot,
    required this.stubsDir,
  });

  @override
  final String projectRoot;
  final String stubsDir;

  bool didRunDartFormat = false;
  bool didRunNotificationInstaller = false;
  final List<String> infoMessages = <String>[];
  final List<String> warnMessages = <String>[];
  final List<String> successMessages = <String>[];

  @override
  String getProjectRoot() {
    return projectRoot;
  }

  @override
  List<String> getStubSearchPaths() {
    return [
      stubsDir,
    ];
  }

  @override
  Future<ProcessResult> runDartFormat(String rootPath) async {
    didRunDartFormat = true;

    return ProcessResult(
      1,
      0,
      'formatted',
      '',
    );
  }

  @override
  Future<ProcessResult> runNotificationInstaller(String rootPath) async {
    didRunNotificationInstaller = true;

    return ProcessResult(
      1,
      0,
      'notifications installed',
      '',
    );
  }

  @override
  void info(String message) {
    infoMessages.add(message);
    super.info(message);
  }

  @override
  void warn(String message) {
    warnMessages.add(message);
    super.warn(message);
  }

  @override
  void success(String message) {
    successMessages.add(message);
    super.success(message);
  }

  void clearMessages() {
    infoMessages.clear();
    warnMessages.clear();
    successMessages.clear();
  }
}

void main() {
  group('MagicStarterInstallCommand', () {
    late Directory tempDir;
    late TestMagicStarterInstallCommand command;
    late String stubsPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('magic_starter_install_');
      stubsPath = '${Directory.current.path}/assets/stubs';
      command = TestMagicStarterInstallCommand(
        projectRoot: tempDir.path,
        stubsDir: stubsPath,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('name is install', () {
      expect(command.name, 'install');
    });

    test('errors when Magic not installed (no lib/config/app.dart)', () async {
      expect(
        () => command.runWith([
          '--non-interactive',
        ]),
        throwsA(
          isA<Exception>().having(
            (Exception exception) => exception.toString(),
            'message',
            contains('Magic Framework not detected'),
          ),
        ),
      );
    });

    test('creates lib/config/magic_starter.dart from stub', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final File configFile =
          File('${tempDir.path}/lib/config/magic_starter.dart');
      expect(configFile.existsSync(), isTrue);
      expect(configFile.readAsStringSync(), contains('magicStarterConfig'));
    });

    test('skips config write when exists and no --force', () async {
      setupMagicProjectFiles(tempDir);

      final File configFile =
          File('${tempDir.path}/lib/config/magic_starter.dart');
      configFile.createSync(recursive: true);
      configFile.writeAsStringSync('// existing config');

      await command.runWith([
        '--non-interactive',
      ]);

      expect(configFile.readAsStringSync(), '// existing config');
    });

    test('overwrites config when --force set', () async {
      setupMagicProjectFiles(tempDir);

      final File configFile =
          File('${tempDir.path}/lib/config/magic_starter.dart');
      configFile.createSync(recursive: true);
      configFile.writeAsStringSync('// existing config');

      await command.runWith([
        '--non-interactive',
        '--force',
      ]);

      expect(configFile.readAsStringSync(), isNot('// existing config'));
      expect(configFile.readAsStringSync(), contains('magicStarterConfig'));
    });

    test('injects import into app.dart', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String appContent =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
      expect(appContent,
          contains("import 'package:magic_starter/magic_starter.dart';"));
    });

    test('injects MagicStarterServiceProvider into app.dart providers list',
        () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String appContent =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
      expect(
          appContent, contains('(app) => MagicStarterServiceProvider(app),'));
    });

    test('skips provider injection when already present (idempotency)',
        () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);
      await command.runWith([
        '--non-interactive',
      ]);

      final String appContent =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
      final int providerCount =
          RegExp('MagicStarterServiceProvider').allMatches(appContent).length;
      expect(providerCount, 1);
    });

    test('injects magic_starter import into main.dart', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      expect(content, contains("import 'config/magic_starter.dart';"));
    });

    test('injects magicStarterConfig factory into main.dart', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      expect(content, contains('() => magicStarterConfig,'));
    });

    test('skips main.dart injection when already present (idempotency)',
        () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);
      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      final int factoryCount =
          RegExp(r'\(\) => magicStarterConfig').allMatches(content).length;
      expect(factoryCount, 1);
    });

    test('injects WindThemeData with primary color palette into main.dart',
        () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      expect(content, contains('WindThemeData'));
      expect(content, contains("'primary'"));
      expect(content, contains('MaterialColor'));
      expect(content, contains('windTheme: windTheme'));
    });

    test('injects WindThemeData import into main.dart', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      expect(
        content,
        contains("import 'package:flutter/material.dart';"),
      );
    });

    test(
        'skips WindThemeData injection when already present (idempotency)',
        () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);
      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      final int themeCount =
          RegExp('WindThemeData').allMatches(content).length;
      expect(themeCount, 1);
    });

    test('creates ensure_authenticated middleware file', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final File middlewareFile =
          File('${tempDir.path}/lib/app/middleware/ensure_authenticated.dart');
      expect(middlewareFile.existsSync(), isTrue);
      expect(middlewareFile.readAsStringSync(),
          contains('class EnsureAuthenticated'));
    });

    test('creates redirect_if_authenticated middleware file', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final File middlewareFile = File(
          '${tempDir.path}/lib/app/middleware/redirect_if_authenticated.dart');
      expect(middlewareFile.existsSync(), isTrue);
      expect(middlewareFile.readAsStringSync(),
          contains('class RedirectIfAuthenticated'));
    });

    test('skips middleware creation when exists and no --force', () async {
      setupMagicProjectFiles(tempDir);

      final File middlewareFile =
          File('${tempDir.path}/lib/app/middleware/ensure_authenticated.dart');
      middlewareFile.createSync(recursive: true);
      middlewareFile.writeAsStringSync('// keep this middleware');

      await command.runWith([
        '--non-interactive',
      ]);

      expect(middlewareFile.readAsStringSync(), '// keep this middleware');
    });

    test('injects middleware aliases into kernel.dart', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String kernelContent =
          File('${tempDir.path}/lib/app/kernel.dart').readAsStringSync();

      // Verify UNCOMMENTED Kernel.registerAll block exists.
      expect(
        RegExp(r"^\s*Kernel\.registerAll\(", multiLine: true)
            .hasMatch(kernelContent),
        isTrue,
        reason: 'Kernel.registerAll must be uncommented',
      );
      expect(kernelContent, contains("'auth': () => EnsureAuthenticated(),"));
      expect(
          kernelContent, contains("'guest': () => RedirectIfAuthenticated(),"));

      // Verify UNCOMMENTED import 'package:magic/magic.dart' exists.
      expect(
        RegExp(r"^import 'package:magic/magic\.dart';", multiLine: true)
            .hasMatch(kernelContent),
        isTrue,
        reason: 'import magic must be uncommented',
      );
      expect(kernelContent,
          contains("import 'middleware/ensure_authenticated.dart';"));
      expect(kernelContent,
          contains("import 'middleware/redirect_if_authenticated.dart';"));
    });

    test('injects auth route import into route_service_provider.dart',
        () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content,
          contains("import 'package:magic_starter/magic_starter.dart';"));
    });

    test('injects auth route registration call into RSP boot()', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content, contains('registerMagicStarterAuthRoutes();'));
      expect(content, contains('registerMagicStarterProfileRoutes();'));
    });

    test('injects team routes only when teams feature enabled', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--features=teams',
        '--force',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content, contains('registerMagicMagicStarterTeamRoutes();'));
    });

    test('does not inject team routes when teams feature disabled', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--features=social_login',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content, isNot(contains('registerMagicMagicStarterTeamRoutes();')));
    });

    test('replaces app_service_provider.dart content', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--force',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();
      expect(content, contains('MagicStarter.useNavigation('));
      expect(content, contains('MagicStarter.useLogout(() async {'));
    });

    test('middleware stubs use correct handle() signature', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String ensureContent =
          File('${tempDir.path}/lib/app/middleware/ensure_authenticated.dart')
              .readAsStringSync();
      final String redirectContent = File(
              '${tempDir.path}/lib/app/middleware/redirect_if_authenticated.dart')
          .readAsStringSync();

      // Must use correct MagicMiddleware.handle signature.
      expect(ensureContent, contains('handle(void Function() next)'));
      expect(redirectContent, contains('handle(void Function() next)'));

      // Must NOT use old MagicRequest signature.
      expect(ensureContent, isNot(contains('MagicRequest')));
      expect(redirectContent, isNot(contains('MagicRequest')));

      // Must use MagicRoute.to() not offAllNamed().
      expect(ensureContent, isNot(contains('offAllNamed')));
      expect(redirectContent, isNot(contains('offAllNamed')));
      expect(ensureContent, contains('MagicRoute.to('));
      expect(redirectContent, contains('MagicRoute.to('));

      // Must call next() without await (next returns void, not Future).
      expect(ensureContent, contains('next();'));
      expect(ensureContent, isNot(contains('await next()')));
      expect(redirectContent, contains('next();'));
      expect(redirectContent, isNot(contains('await next()')));
    });

    test('app_service_provider uses correct MagicStarterNavItem params', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--force',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();

      // Must use correct MagicStarterNavItem constructor params.
      expect(content, contains('icon:'));
      expect(content, contains('labelKey:'));
      expect(content, contains('path:'));

      // Must NOT use old wrong param names.
      expect(content, isNot(contains("label: 'Dashboard'")));
      expect(
        content,
        isNot(contains('route: MagicStarterConfig.homeRoute()')),
      );

      // Must use MagicRoute.to() not offAllNamed().
      expect(content, isNot(contains('offAllNamed')));
      expect(content, contains('MagicRoute.to('));
    });

    test('teams block uses correct useTeamResolver named params', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--features=teams',
        '--force',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();

      // Must use named parameter style.
      expect(content, contains('MagicStarter.useTeamResolver('));
      expect(content, contains('currentTeam:'));
      expect(content, contains('allTeams:'));
      expect(content, contains('onSwitch:'));

      // Must NOT use old positional callback style.
      expect(content, isNot(contains('useTeamResolver((userId)')));
    });

    test('notifications block uses correct type mapper signature', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--features=notifications',
        '--force',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();

      // Must use (type) parameter, not (notification).
      expect(content, contains('useNotificationTypeMapper((type)'));
      expect(
          content, isNot(contains('useNotificationTypeMapper((notification)')));
    });

    test('config file uses // comments not /// to avoid dangling doc lint',
        () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--force',
      ]);

      final String content =
          File('${tempDir.path}/lib/config/magic_starter.dart')
              .readAsStringSync();

      // Must NOT start with /// (dangling library doc comment).
      expect(content.trimLeft().startsWith('///'), isFalse);
      // Must still have comment header.
      expect(content, contains('// Magic Starter Configuration.'));
    });

    test('--features flag auto-enables non-interactive mode', () async {
      setupMagicProjectFiles(tempDir);

      // Pass --features WITHOUT --non-interactive.
      await command.runWith([
        '--features=teams,social_login',
      ]);

      final String config =
          File('${tempDir.path}/lib/config/magic_starter.dart')
              .readAsStringSync();

      // Features must be applied even without --non-interactive.
      expect(config, contains("'teams': true"));
      expect(config, contains("'social_login': true"));
      expect(config, contains("'newsletter': false"));
    });

    test('creates assets/lang/en.json translation file', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final File file = File('${tempDir.path}/assets/lang/en.json');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('"auth"'));
    });

    test('adds assets/lang/en.json to pubspec flutter assets', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/pubspec.yaml').readAsStringSync();
      expect(content, contains('- assets/lang/en.json'));
    });

    test('idempotent — running twice does not duplicate injections', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);
      await command.runWith([
        '--non-interactive',
      ]);

      final String app =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
      final String main =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      final String rsp =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();

      expect(RegExp('MagicStarterServiceProvider').allMatches(app).length, 1);
      expect(RegExp(r'\(\) => magicStarterConfig').allMatches(main).length, 1);
      expect(
          RegExp('registerMagicStarterAuthRoutes').allMatches(rsp).length, 1);
    });

    test('non-interactive mode with --non-interactive --features flag',
        () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--features=teams,social_login,notifications,email_verification',
      ]);

      final String config =
          File('${tempDir.path}/lib/config/magic_starter.dart')
              .readAsStringSync();
      expect(config, contains("'teams': true"));
      expect(config, contains("'social_login': true"));
      expect(config, contains("'notifications': true"));
      expect(config, contains("'email_verification': true"));
    });

    test('runs dart format after install', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      expect(command.didRunDartFormat, isTrue);
    });

    test('route registrations are on separate lines in RSP', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
        '--features=teams',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();

      // Each registration call must be on its own line.
      final List<String> lines = content.split('\n');
      for (final String line in lines) {
        final int count = 'register'.allMatches(line).length;
        expect(
          count,
          lessThanOrEqualTo(1),
          reason: 'Multiple register calls on same line: $line',
        );
      }
    });

    test('pubspec does not get duplicate assets: key with existing assets',
        () async {
      // Simulate real-world pubspec from magic install (blank line after
      // flutter:, existing assets with .env, comments below).
      final File pubspecFile = File('${tempDir.path}/pubspec.yaml');
      pubspecFile.writeAsStringSync('''
name: test_app
description: Test host app
dependencies:
  flutter:
    sdk: flutter
  magic:
    path: ../magic

flutter:

  assets:
    - .env
  uses-material-design: true

  # To add assets to your application, add an assets section
  # assets:
  #   - images/a_dot_burr.jpeg
''');

      setupAppFile(tempDir);
      setupMainFile(tempDir);
      setupKernelFile(tempDir);
      setupRouteServiceProviderFile(tempDir);
      setupAppServiceProviderFile(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content = pubspecFile.readAsStringSync();

      // Must NOT have duplicate assets: keys.
      final int assetsKeyCount =
          RegExp(r'^  assets:\s*$', multiLine: true).allMatches(content).length;
      expect(
        assetsKeyCount,
        equals(1),
        reason: 'Duplicate assets: key found in pubspec.yaml.\n\n$content',
      );

      // The en.json asset must be present.
      expect(content, contains('- assets/lang/en.json'));

      // The existing .env asset must still be present.
      expect(content, contains('- .env'));
    });

    group('new scaffolding steps', () {
      test('creates lib/app/models/user.dart after install', () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
          '--force',
        ]);

        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');
        expect(userFile.existsSync(), isTrue);
      });

      test(
          'creates team model and team accessors when teams feature is enabled',
          () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
          '--features=teams',
        ]);

        final File teamFile = File('${tempDir.path}/lib/app/models/team.dart');
        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');

        expect(teamFile.existsSync(), isTrue);
        expect(userFile.readAsStringSync(), contains('Team? get currentTeam'));
      });

      test('skips team model and team accessors when teams feature is disabled',
          () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
          '--force',
        ]);

        final File teamFile = File('${tempDir.path}/lib/app/models/team.dart');
        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');

        expect(teamFile.existsSync(), isFalse);
        expect(userFile.readAsStringSync(),
            isNot(contains('Team? get currentTeam')));
      });

      test('creates dashboard view scaffold file', () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
        ]);

        final File dashboardFile =
            File('${tempDir.path}/lib/resources/views/dashboard_view.dart');

        expect(dashboardFile.existsSync(), isTrue);
      });

      test('creates app routes scaffold file', () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
        ]);

        final File routesFile = File('${tempDir.path}/lib/routes/app.dart');
        expect(routesFile.existsSync(), isTrue);
      });

      test('safe-write skips existing files on second install without --force',
          () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
        ]);
        command.clearMessages();

        await command.runWith([
          '--non-interactive',
        ]);

        expect(
          command.infoMessages,
          contains('Skipped: lib/app/models/user.dart (already exists)'),
        );
        expect(
          command.infoMessages,
          contains(
              'Skipped: lib/resources/views/dashboard_view.dart (already exists)'),
        );
      });

      test('safe-write overwrites existing files with --force', () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
        ]);
        command.clearMessages();

        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');
        userFile.writeAsStringSync('// mutated user model');

        await command.runWith([
          '--non-interactive',
          '--force',
        ]);

        expect(
          command.warnMessages,
          contains('Overwritten: lib/app/models/user.dart'),
        );
        expect(userFile.readAsStringSync(),
            isNot(contains('// mutated user model')));
      });

      test(
          'app service provider excludes teams import and mapping when teams disabled',
          () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
        ]);

        final String content =
            File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
                .readAsStringSync();

        expect(content, isNot(contains("import '../models/team.dart';")));
        expect(content, isNot(contains('Team.fromMap')));
      });

      test('app service provider includes social login block when enabled',
          () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
          '--features=social_login',
          '--force',
        ]);

        final String content =
            File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
                .readAsStringSync();

        expect(content, contains('MagicStarter.useSocialLogin('));
      });

      test('safe-write reports created path messages for new scaffold files',
          () async {
        setupMagicProjectFiles(tempDir);

        await command.runWith([
          '--non-interactive',
        ]);

        expect(
          command.successMessages,
          contains('Created: lib/app/models/user.dart'),
        );
        expect(
          command.successMessages,
          contains('Created: lib/resources/views/dashboard_view.dart'),
        );
        expect(
          command.successMessages,
          contains('Created: lib/routes/app.dart'),
        );
      });
    });
  });
}

void setupMagicProjectFiles(Directory directory) {
  setupPubspecFile(directory);
  setupAppFile(directory);
  setupMainFile(directory);
  setupKernelFile(directory);
  setupRouteServiceProviderFile(directory);
  setupAppServiceProviderFile(directory);
}

void setupPubspecFile(Directory directory) {
  final File pubspecFile = File('${directory.path}/pubspec.yaml');
  pubspecFile.createSync(recursive: true);
  pubspecFile.writeAsStringSync('''
name: test_app
description: Test host app
dependencies:
  flutter:
    sdk: flutter
  magic:
    path: ../magic

flutter:
  assets:
    - assets/stubs/install/
''');
}

void setupAppFile(Directory directory) {
  final File appFile = File('${directory.path}/lib/config/app.dart');
  appFile.createSync(recursive: true);
  appFile.writeAsStringSync('''
import 'package:magic/magic.dart';
import '../app/providers/app_service_provider.dart';
import '../app/providers/route_service_provider.dart';

/// Application Configuration.
Map<String, dynamic> get appConfig => {
  'app': {
    'name': env('APP_NAME', 'My App'),
    'env': env('APP_ENV', 'production'),
    'debug': env('APP_DEBUG', false),
    'key': env('APP_KEY'),
    'providers': [
      (app) => RouteServiceProvider(app),
      (app) => LaunchServiceProvider(app),
      (app) => AuthServiceProvider(app),
      (app) => VaultServiceProvider(app),
      (app) => DatabaseServiceProvider(app),
      (app) => NetworkServiceProvider(app),
      (app) => CacheServiceProvider(app),
      (app) => LocalizationServiceProvider(app),
      (app) => AppServiceProvider(app),
    ],
  },
};
''');
}

void setupMainFile(Directory directory) {
  final File mainFile = File('${directory.path}/lib/main.dart');
  mainFile.createSync(recursive: true);
  mainFile.writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'config/app.dart';
import 'config/view.dart';
import 'config/auth.dart';
import 'config/database.dart';
import 'config/network.dart';
import 'config/cache.dart';
import 'config/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => viewConfig,
      () => authConfig,
      () => databaseConfig,
      () => networkConfig,
      () => cacheConfig,
      () => loggingConfig,
    ],
  );

  runApp(
    MagicApplication(title: 'Starter App'),
  );
}
''');
}

void setupKernelFile(Directory directory) {
  final File kernelFile = File('${directory.path}/lib/app/kernel.dart');
  kernelFile.createSync(recursive: true);
  kernelFile.writeAsStringSync('''
// Import Magic to access Kernel, middleware base classes, etc.:
// import 'package:magic/magic.dart';

void registerKernel() {
  // ---------------------------------------------------------------------------
  // Global Middleware
  // ---------------------------------------------------------------------------
  // Kernel.global([
  //   () => LoggingMiddleware(),
  // ]);

  // ---------------------------------------------------------------------------
  // Route Middleware
  // ---------------------------------------------------------------------------
  // Uncomment and add your middleware aliases below:
  // Kernel.registerAll({
  //   'auth': () => EnsureAuthenticated(),
  //   'guest': () => RedirectIfAuthenticated(),
  // });
}
''');
}

void setupRouteServiceProviderFile(Directory directory) {
  final File file =
      File('${directory.path}/lib/app/providers/route_service_provider.dart');
  file.createSync(recursive: true);
  file.writeAsStringSync('''
import 'package:magic/magic.dart';

import '../kernel.dart';
import '../../routes/app.dart';

class RouteServiceProvider extends ServiceProvider {
  RouteServiceProvider(super.app);

  @override
  void register() {
    registerKernel();
  }

  @override
  Future<void> boot() async {
    registerAppRoutes();
  }
}
''');
}

void setupAppServiceProviderFile(Directory directory) {
  final File file =
      File('${directory.path}/lib/app/providers/app_service_provider.dart');
  file.createSync(recursive: true);
  file.writeAsStringSync('''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  void register() {
    // noop
  }

  @override
  Future<void> boot() async {
    // noop
  }
}
''');
}
