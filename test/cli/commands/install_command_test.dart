import 'dart:io';

import 'package:magic_starter/src/cli/commands/install_command.dart';
import 'package:test/test.dart';

class TestInstallCommand extends InstallCommand {
  TestInstallCommand({
    required this.projectRoot,
    required this.stubsDir,
  });

  @override
  final String projectRoot;
  final String stubsDir;

  bool didRunDartFormat = false;
  bool didRunNotificationInstaller = false;

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
}

void main() {
  group('InstallCommand', () {
    late Directory tempDir;
    late TestInstallCommand command;
    late String stubsPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('magic_starter_install_');
      stubsPath = '${Directory.current.path}/assets/stubs';
      command = TestInstallCommand(
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
      expect(kernelContent, contains("'auth': () => EnsureAuthenticated(),"));
      expect(
          kernelContent, contains("'guest': () => RedirectIfAuthenticated(),"));
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
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content, contains('registerMagicStarterTeamRoutes();'));
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
      expect(content, isNot(contains('registerMagicStarterTeamRoutes();')));
    });

    test('replaces app_service_provider.dart content', () async {
      setupMagicProjectFiles(tempDir);

      await command.runWith([
        '--non-interactive',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();
      expect(content, contains('MagicStarter.useNavigation('));
      expect(content, contains('MagicStarter.useLogout(() async {'));
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
