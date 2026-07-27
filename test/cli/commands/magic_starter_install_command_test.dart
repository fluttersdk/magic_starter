import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic_starter/src/cli/commands/magic_starter_install_command.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

/// Test double pinning the project root, stub search paths, manifest path, and
/// the external `dart format` / notifications-installer side effects so the
/// installer runs end-to-end against a temp directory with zero real I/O.
class TestMagicStarterInstallCommand extends MagicStarterInstallCommand {
  TestMagicStarterInstallCommand({
    required this.projectRoot,
    required this.stubsDir,
    required this.manifestPath,
  });

  @override
  final String projectRoot;
  final String stubsDir;
  final String manifestPath;

  bool didRunDartFormat = false;

  @override
  String getProjectRoot() => projectRoot;

  @override
  List<String> getStubSearchPaths() => <String>[stubsDir];

  @override
  Future<String?> resolveManifestPath() async => manifestPath;

  @override
  Future<ProcessResult> runDartFormat(String rootPath) async {
    didRunDartFormat = true;
    return ProcessResult(1, 0, 'formatted', '');
  }
}

/// Drives [command.handle] with a programmatic [ArtisanContext] composed of a
/// [MapInput] (flags) and a [BufferedOutput] (capturable). The four base
/// install flags are always defaulted so the [ArtisanInstallCommand] hard
/// casts (`option('force') as bool`) never trip on absence.
Future<int> runInstall(
  MagicStarterInstallCommand command, {
  bool force = false,
  bool nonInteractive = true,
  String? features,
}) {
  final options = <String, dynamic>{
    'force': force,
    'dry-run': false,
    'non-interactive': nonInteractive,
    'no-bootstrap': false,
    if (features != null) 'features': features,
  };
  final ctx = ArtisanContext.bare(MapInput(options), BufferedOutput());
  return command.handle(ctx);
}

void main() {
  group('MagicStarterInstallCommand', () {
    late Directory tempDir;
    late TestMagicStarterInstallCommand command;
    late String stubsPath;
    late String manifestPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('magic_starter_install_');
      stubsPath = '${Directory.current.path}/assets/stubs';
      manifestPath = '${Directory.current.path}/install.yaml';
      command = TestMagicStarterInstallCommand(
        projectRoot: tempDir.path,
        stubsDir: stubsPath,
        manifestPath: manifestPath,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('extends ArtisanInstallCommand', () {
      expect(command, isA<ArtisanInstallCommand>());
    });

    test('name is starter:install', () {
      expect(command.name, 'starter:install');
    });

    test('errors when Magic not installed (no lib/config/app.dart)', () async {
      expect(
        () => runInstall(command),
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

      await runInstall(command);

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

      await runInstall(command);

      expect(configFile.readAsStringSync(), '// existing config');
    });

    test('overwrites config when --force set', () async {
      setupMagicProjectFiles(tempDir);

      final File configFile =
          File('${tempDir.path}/lib/config/magic_starter.dart');
      configFile.createSync(recursive: true);
      configFile.writeAsStringSync('// existing config');

      await runInstall(command, force: true);

      expect(configFile.readAsStringSync(), isNot('// existing config'));
      expect(configFile.readAsStringSync(), contains('magicStarterConfig'));
    });

    test('injects import into app.dart', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String appContent =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
      expect(appContent,
          contains("import 'package:magic_starter/magic_starter.dart';"));
    });

    test('injects MagicStarterServiceProvider into app.dart providers list',
        () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String appContent =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
      expect(
          appContent, contains('(app) => MagicStarterServiceProvider(app),'));
    });

    test('skips provider injection when already present (idempotency)',
        () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);
      await runInstall(command);

      final String appContent =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();
      final int providerCount =
          RegExp('MagicStarterServiceProvider').allMatches(appContent).length;
      expect(providerCount, 1);
    });

    test('injects magic_starter import into main.dart', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      expect(content, contains("import 'config/magic_starter.dart';"));
    });

    test('injects magicStarterConfig factory into main.dart', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      expect(content, contains('() => magicStarterConfig,'));
    });

    test('skips main.dart injection when already present (idempotency)',
        () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);
      await runInstall(command);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      final int factoryCount =
          RegExp(r'\(\) => magicStarterConfig').allMatches(content).length;
      expect(factoryCount, 1);
    });

    test('injects WindThemeData with primary color palette into main.dart',
        () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      expect(content, contains('WindThemeData'));
      expect(content, contains("'primary'"));
      expect(content, contains('MaterialColor'));
      expect(content, contains('windTheme: windTheme'));
    });

    test(
        'injects windTheme into multi-arg MagicApplication preserving '
        'title and titleSuffix', () async {
      setupMagicProjectFiles(tempDir);

      // Rewrite main.dart with the multi-argument MagicApplication signature
      // scaffolded once magic gained titleSuffix/titleSeparator support.
      final File mainFile = File('${tempDir.path}/lib/main.dart');
      mainFile.writeAsStringSync(
        mainFile.readAsStringSync().replaceFirst(
              "MagicApplication(title: 'Starter App'),",
              "MagicApplication(title: 'Starter App', "
                  "titleSuffix: 'Starter App'),",
            ),
      );

      await runInstall(command);

      final String content = mainFile.readAsStringSync();
      expect(content, contains('windTheme: windTheme'));
      expect(content, contains("title: 'Starter App'"));
      expect(content, contains("titleSuffix: 'Starter App'"));
      // The injected windTheme must not collide with the preserved trailing
      // args into a double comma (invalid Dart).
      expect(content, isNot(contains(',,')));
      expect(
        content,
        contains("windTheme: windTheme, titleSuffix: 'Starter App'"),
      );
    });

    test('injects material.dart import into main.dart', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      expect(content, contains("import 'package:flutter/material.dart';"));
    });

    test('skips WindThemeData injection when already present (idempotency)',
        () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);
      await runInstall(command);

      final String content =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();
      final int themeCount = RegExp('WindThemeData').allMatches(content).length;
      expect(themeCount, 1);
    });

    test('creates ensure_authenticated middleware file', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final File middlewareFile =
          File('${tempDir.path}/lib/app/middleware/ensure_authenticated.dart');
      expect(middlewareFile.existsSync(), isTrue);
      expect(middlewareFile.readAsStringSync(),
          contains('class EnsureAuthenticated'));
    });

    test('creates redirect_if_authenticated middleware file', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

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

      await runInstall(command);

      expect(middlewareFile.readAsStringSync(), '// keep this middleware');
    });

    test('injects middleware aliases into kernel.dart', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String kernelContent =
          File('${tempDir.path}/lib/app/kernel.dart').readAsStringSync();

      expect(
        RegExp(r"^\s*Kernel\.registerAll\(", multiLine: true)
            .hasMatch(kernelContent),
        isTrue,
        reason: 'Kernel.registerAll must be uncommented',
      );
      expect(kernelContent, contains("'auth': () => EnsureAuthenticated(),"));
      expect(
          kernelContent, contains("'guest': () => RedirectIfAuthenticated(),"));

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

      await runInstall(command);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content,
          contains("import 'package:magic_starter/magic_starter.dart';"));
    });

    test('injects auth route registration call into RSP boot()', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content, contains('registerMagicStarterAuthRoutes();'));
      expect(content, contains('registerMagicStarterProfileRoutes();'));
    });

    test('injects team routes only when teams feature enabled', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, force: true, features: 'teams');

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content, contains('registerMagicStarterTeamRoutes();'));
    });

    test('does not inject team routes when teams feature disabled', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, features: 'social_login');

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();
      expect(content, isNot(contains('registerMagicStarterTeamRoutes();')));
    });

    test('replaces app_service_provider.dart content', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, force: true);

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();
      expect(content, contains('MagicStarter.useNavigation('));

      // The logout body moved inside bootstrap() as the onLogout argument; it
      // is still wired, just not through the standalone setter.
      expect(content, contains('onLogout: () async {'));
      expect(content, contains('await Auth.logout();'));
    });

    test('middleware stubs use correct handle() signature', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String ensureContent =
          File('${tempDir.path}/lib/app/middleware/ensure_authenticated.dart')
              .readAsStringSync();
      final String redirectContent = File(
              '${tempDir.path}/lib/app/middleware/redirect_if_authenticated.dart')
          .readAsStringSync();

      expect(ensureContent, contains('handle(void Function() next)'));
      expect(redirectContent, contains('handle(void Function() next)'));

      expect(ensureContent, isNot(contains('MagicRequest')));
      expect(redirectContent, isNot(contains('MagicRequest')));

      expect(ensureContent, isNot(contains('offAllNamed')));
      expect(redirectContent, isNot(contains('offAllNamed')));
      expect(ensureContent, contains('MagicRoute.to('));
      expect(redirectContent, contains('MagicRoute.to('));

      expect(ensureContent, contains('next();'));
      expect(ensureContent, isNot(contains('await next()')));
      expect(redirectContent, contains('next();'));
      expect(redirectContent, isNot(contains('await next()')));
    });

    test('app_service_provider uses correct MagicStarterNavItem params',
        () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, force: true);

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();

      expect(content, contains('icon:'));
      expect(content, contains('labelKey:'));
      expect(content, contains('path:'));

      expect(content, isNot(contains("label: 'Dashboard'")));
      expect(
        content,
        isNot(contains('route: MagicStarterConfig.homeRoute()')),
      );

      expect(content, isNot(contains('offAllNamed')));
      expect(content, contains('MagicRoute.to('));
    });

    test('team callbacks render inside bootstrap() with named params', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, force: true, features: 'teams');

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();

      // The team trio lives INSIDE bootstrap() rather than in a separate
      // useTeamResolver() statement, because bootstrap() takes all three or
      // none and enforces that at runtime.
      expect(content, contains('MagicStarter.bootstrap('));
      expect(content, contains('currentTeam:'));
      expect(content, contains('allTeams:'));
      expect(content, contains('onSwitch:'));
      expect(content, isNot(contains('MagicStarter.useTeamResolver(')));

      // Guards the callback signature: onSwitch takes the team id, and a
      // positional or misnamed parameter would silently not compile in the
      // generated app.
      expect(content, contains('onSwitch: (teamId)'));
    });

    test('bootstrap() omits the team trio when teams is off', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, force: true);

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();

      // A partial team set throws ArgumentError, so a teamless install must
      // emit none of the three rather than some of them.
      expect(content, contains('MagicStarter.bootstrap('));
      expect(content, isNot(contains('currentTeam:')));
      expect(content, isNot(contains('allTeams:')));
      expect(content, isNot(contains('onSwitch:')));
    });

    test('bootstrap() replaces the loose identity setters entirely', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, force: true, features: 'teams');

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();

      // The four identity setters are still public API, but the scaffold must
      // not emit them: a generated provider on the loose calls would keep the
      // silent-omission failure mode bootstrap() exists to remove.
      expect(content, contains('MagicStarter.bootstrap('));
      expect(content, isNot(contains('MagicStarter.useUserModel(')));
      expect(content, isNot(contains('MagicStarter.useLogout(')));
      expect(content, isNot(contains('MagicStarter.useLocaleOptions(')));

      // The optional setters stay outside bootstrap() and must survive.
      expect(content, contains('MagicStarter.useNavigation('));
    });

    test('notifications block uses correct type mapper signature', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, force: true, features: 'notifications');

      final String content =
          File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
              .readAsStringSync();

      expect(content, contains('useNotificationTypeMapper((type)'));
      expect(
          content, isNot(contains('useNotificationTypeMapper((notification)')));
    });

    test('config file uses // comments not /// to avoid dangling doc lint',
        () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, force: true);

      final String content =
          File('${tempDir.path}/lib/config/magic_starter.dart')
              .readAsStringSync();

      expect(content.trimLeft().startsWith('///'), isFalse);
      expect(content, contains('// Magic Starter Configuration.'));
    });

    test('--features flag auto-enables non-interactive mode', () async {
      setupMagicProjectFiles(tempDir);

      // Pass --features WITHOUT --non-interactive.
      await runInstall(
        command,
        nonInteractive: false,
        features: 'teams,social_login',
      );

      final String config =
          File('${tempDir.path}/lib/config/magic_starter.dart')
              .readAsStringSync();

      expect(config, contains("'teams': true"));
      expect(config, contains("'social_login': true"));
      expect(config, contains("'newsletter': false"));
    });

    test('creates assets/lang/en.json translation file', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final File file = File('${tempDir.path}/assets/lang/en.json');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('"auth"'));
    });

    test('adds assets/lang/en.json to pubspec flutter assets', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);

      final String content =
          File('${tempDir.path}/pubspec.yaml').readAsStringSync();
      expect(content, contains('- assets/lang/en.json'));
    });

    test('idempotent — running twice does not duplicate injections', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command);
      await runInstall(command);

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

      await runInstall(
        command,
        features: 'teams,social_login,notifications,email_verification',
      );

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

      await runInstall(command);

      expect(command.didRunDartFormat, isTrue);
    });

    test('route registrations are on separate lines in RSP', () async {
      setupMagicProjectFiles(tempDir);

      await runInstall(command, features: 'teams');

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();

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

      await runInstall(command);

      final String content = pubspecFile.readAsStringSync();

      final int assetsKeyCount =
          RegExp(r'^  assets:\s*$', multiLine: true).allMatches(content).length;
      expect(
        assetsKeyCount,
        equals(1),
        reason: 'Duplicate assets: key found in pubspec.yaml.\n\n$content',
      );

      expect(content, contains('- assets/lang/en.json'));
      expect(content, contains('- .env'));
    });

    test(
        'pubspec with only the commented `# assets:` example does not get a '
        'duplicate flutter: section (invalid YAML)', () async {
      // Reproduces the real `flutter create` pubspec: a flutter: section whose
      // ONLY assets reference is the commented-out example. A naive
      // contains('assets:') check matches that comment and appends a SECOND
      // flutter: key, producing invalid YAML that breaks all flutter tooling.
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
  uses-material-design: true

  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
''');

      setupAppFile(tempDir);
      setupMainFile(tempDir);
      setupKernelFile(tempDir);
      setupRouteServiceProviderFile(tempDir);
      setupAppServiceProviderFile(tempDir);

      await runInstall(command);

      final String content = pubspecFile.readAsStringSync();

      final int flutterKeyCount =
          RegExp(r'^flutter:\s*$', multiLine: true).allMatches(content).length;
      expect(
        flutterKeyCount,
        equals(1),
        reason: 'Duplicate top-level flutter: key (invalid YAML).\n\n$content',
      );
      expect(content, contains('- assets/lang/en.json'));
    });

    group('new scaffolding steps', () {
      test('creates lib/app/models/user.dart after install', () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command, force: true);

        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');
        expect(userFile.existsSync(), isTrue);
      });

      test(
          'creates team model and team accessors when teams feature is enabled',
          () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command, features: 'teams');

        final File teamFile = File('${tempDir.path}/lib/app/models/team.dart');
        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');

        expect(teamFile.existsSync(), isTrue);
        expect(userFile.readAsStringSync(), contains('Team? get currentTeam'));
      });

      test('skips team model and team accessors when teams feature is disabled',
          () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command, force: true);

        final File teamFile = File('${tempDir.path}/lib/app/models/team.dart');
        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');

        expect(teamFile.existsSync(), isFalse);
        expect(userFile.readAsStringSync(),
            isNot(contains('Team? get currentTeam')));
      });

      test('creates dashboard view scaffold file', () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command);

        final File dashboardFile =
            File('${tempDir.path}/lib/resources/views/dashboard_view.dart');

        expect(dashboardFile.existsSync(), isTrue);
      });

      test('creates app routes scaffold file', () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command);

        final File routesFile = File('${tempDir.path}/lib/routes/app.dart');
        expect(routesFile.existsSync(), isTrue);
      });

      test('safe-write skips existing files on second install without --force',
          () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command);

        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');
        userFile.writeAsStringSync('// keep this user');

        await runInstall(command);

        expect(userFile.readAsStringSync(), '// keep this user');
      });

      test('safe-write overwrites existing files with --force', () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command);

        final File userFile = File('${tempDir.path}/lib/app/models/user.dart');
        userFile.writeAsStringSync('// mutated user model');

        await runInstall(command, force: true);

        expect(userFile.readAsStringSync(),
            isNot(contains('// mutated user model')));
      });

      test(
          'app service provider excludes teams import and mapping when teams disabled',
          () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command);

        final String content =
            File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
                .readAsStringSync();

        expect(content, isNot(contains("import '../models/team.dart';")));
        expect(content, isNot(contains('Team.fromMap')));
      });

      test('app service provider includes social login block when enabled',
          () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command, force: true, features: 'social_login');

        final String content =
            File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
                .readAsStringSync();

        expect(content, contains('MagicStarter.useSocialLogin('));
      });
    });

    group('bootstrap() injection into an existing app_service_provider.dart',
        () {
      test(
          'injects a single MagicStarter.bootstrap() call instead of the '
          'four loose use*() calls', () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command);

        final String content =
            File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
                .readAsStringSync();

        expect(content, contains('MagicStarter.bootstrap('));
        expect(content, contains('userFactory:'));
        expect(content, contains('onLogout:'));
        expect(content, contains('locales:'));

        expect(content, isNot(contains('MagicStarter.useUserModel(')));
        expect(content, isNot(contains('MagicStarter.useLogout(')));
        expect(content, isNot(contains('MagicStarter.useLocaleOptions(')));
        expect(content, isNot(contains('MagicStarter.useTeamResolver(')));
      });

      test(
          'includes the team resolver trio inside bootstrap() when the teams '
          'feature is enabled', () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command, features: 'teams');

        final String content =
            File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
                .readAsStringSync();

        expect(content, contains('MagicStarter.bootstrap('));
        expect(content, contains('currentTeam:'));
        expect(content, contains('allTeams:'));
        expect(content, contains('onSwitch:'));
      });

      test(
          'omits the team resolver trio from bootstrap() when the teams '
          'feature is disabled', () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command);

        final String content =
            File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
                .readAsStringSync();

        expect(content, contains('MagicStarter.bootstrap('));
        expect(content, isNot(contains('currentTeam:')));
        expect(content, isNot(contains('allTeams:')));
        expect(content, isNot(contains('onSwitch:')));
      });

      test(
          're-running the installer on an already-bootstrapped provider does '
          'not append a second bootstrap() call', () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command);
        await runInstall(command);

        final String content =
            File('${tempDir.path}/lib/app/providers/app_service_provider.dart')
                .readAsStringSync();

        expect('MagicStarter.bootstrap('.allMatches(content).length, 1);
      });
    });

    test(
      'notifications feature adds magic_notifications as version dependency, '
      'not path dependency',
      () async {
        setupMagicProjectFiles(tempDir);

        await runInstall(command, force: true, features: 'notifications');

        final String pubspecContent =
            File('${tempDir.path}/pubspec.yaml').readAsStringSync();

        expect(
          pubspecContent,
          contains('magic_notifications'),
          reason: 'magic_notifications dependency should be added to pubspec',
        );
        expect(
          pubspecContent,
          isNot(contains('path: ../magic_notifications')),
          reason: 'magic_notifications must not be a hardcoded path dependency',
        );
      },
    );

    test('install.yaml manifest exists and declares the starter provider',
        () async {
      final File manifestFile = File(manifestPath);
      expect(manifestFile.existsSync(), isTrue);

      final manifest = ManifestParser.parseFile(p.normalize(manifestPath));
      expect(manifest.pluginName, 'magic_starter');
      expect(manifest.magic.provider, 'MagicStarterServiceProvider');
    });

    test(
        'provider injection is staged AFTER all transactional writeFile ops '
        '(no-rollback ordering)', () async {
      setupMagicProjectFiles(tempDir);

      final manifest = ManifestParser.parseFile(p.normalize(manifestPath));
      final installer = command.stageInstaller(
        command.buildContext(
          ArtisanContext.bare(
              MapInput(const <String, dynamic>{}), BufferedOutput()),
        ),
        manifest,
        features: <String, bool>{
          for (final String key
              in MagicStarterInstallCommand.dynamicFeatureKeys)
            key: false,
        },
        force: true,
      );

      final List<InstallOperation> ops = installer.pendingOps;

      // The provider injection import targets lib/config/app.dart; it is the
      // first op the injectProvider composite enqueues.
      final int providerInjectIndex = ops.indexWhere(
        (InstallOperation op) =>
            op is InjectImport && op.targetFile == 'lib/config/app.dart',
      );
      expect(providerInjectIndex, greaterThanOrEqualTo(0),
          reason: 'provider injection must be staged');

      // Every transactional WriteFile op must precede the helper-backed
      // provider injection (the .tmp swap covers WriteFile only; injectProvider
      // commits synchronously and does not roll back).
      final List<int> writeFileIndexes = <int>[
        for (int i = 0; i < ops.length; i++)
          if (ops[i] is WriteFile) i,
      ];
      expect(writeFileIndexes, isNotEmpty,
          reason: 'transactional writes must be staged');
      for (final int writeIndex in writeFileIndexes) {
        expect(
          writeIndex,
          lessThan(providerInjectIndex),
          reason: 'writeFile op at $writeIndex must precede the provider '
              'injection at $providerInjectIndex',
        );
      }
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
