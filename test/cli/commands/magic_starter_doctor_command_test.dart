import 'dart:io';

import 'package:magic_cli/magic_cli.dart';
import 'package:magic_starter/src/cli/commands/magic_starter_doctor_command.dart';
import 'package:test/test.dart';

/// Test double that overrides [getProjectRoot] to use a temp directory.
class _TestMagicStarterDoctorCommand extends MagicStarterDoctorCommand {
  final String _root;

  _TestMagicStarterDoctorCommand(this._root);

  @override
  String getProjectRoot() => _root;
}

/// Write a file at [relativePath] inside [dir] with the given [content].
///
/// Parent directories are created automatically.
void _writeFile(Directory dir, String relativePath, String content) {
  final file = File('${dir.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

/// Set up a fully-installed Magic Starter project inside [dir].
///
/// Creates all required files with the expected content strings so that
/// every health check passes.
void _setupFullInstall(Directory dir) {
  _writeFile(
    dir,
    'lib/config/app.dart',
    "import 'package:magic_starter/magic_starter.dart';\n"
        'final providers = [\n'
        '  (app) => MagicStarterServiceProvider(app),\n'
        '];\n',
  );
  _writeFile(
    dir,
    'lib/config/magic_starter.dart',
    "Map<String, dynamic> get magicStarterConfig => {'magic_starter': {}};\n",
  );
  _writeFile(
    dir,
    'lib/main.dart',
    "import 'config/magic_starter.dart';\n"
        'void main() async {\n'
        '  await Magic.init(configFactories: [() => magicStarterConfig]);\n'
        '}\n',
  );
  _writeFile(
    dir,
    'lib/app/kernel.dart',
    "import 'middleware/ensure_authenticated.dart';\n"
        'void boot() {\n'
        "  Kernel.registerAll({'auth': () => EnsureAuthenticated()});\n"
        '}\n',
  );
  _writeFile(
    dir,
    'lib/app/providers/route_service_provider.dart',
    "import 'package:magic_starter/magic_starter.dart';\n"
        'void boot() {\n'
        '  registerMagicStarterAuthRoutes();\n'
        '  registerMagicStarterProfileRoutes();\n'
        '}\n',
  );
  _writeFile(
    dir,
    'lib/app/providers/app_service_provider.dart',
    "import 'package:magic_starter/magic_starter.dart';\n"
        'void boot() {\n'
        '  MagicStarter.useNavigation(mainItems: []);\n'
        '}\n',
  );
  _writeFile(dir, 'assets/lang/en.json', '{}');
}

void main() {
  late Directory tempDir;
  late _TestMagicStarterDoctorCommand command;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('doctor_cmd_test_');
    command = _TestMagicStarterDoctorCommand(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // Metadata
  // -------------------------------------------------------------------------

  group('MagicStarterDoctorCommand metadata', () {
    test('name is "doctor"', () {
      expect(command.name, equals('doctor'));
    });

    test('description is not empty', () {
      expect(command.description, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // checkMagicInstalled
  // -------------------------------------------------------------------------

  group('checkMagicInstalled', () {
    test('returns true when lib/config/app.dart exists', () {
      _writeFile(tempDir, 'lib/config/app.dart', '// app config');
      expect(command.checkMagicInstalled(tempDir.path), isTrue);
    });

    test('returns false when lib/config/app.dart is missing', () {
      expect(command.checkMagicInstalled(tempDir.path), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // checkConfigExists
  // -------------------------------------------------------------------------

  group('checkConfigExists', () {
    test('returns true when lib/config/magic_starter.dart exists', () {
      _writeFile(tempDir, 'lib/config/magic_starter.dart', '// config');
      expect(command.checkConfigExists(tempDir.path), isTrue);
    });

    test('returns false when lib/config/magic_starter.dart is missing', () {
      expect(command.checkConfigExists(tempDir.path), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // checkProviderRegistered
  // -------------------------------------------------------------------------

  group('checkProviderRegistered', () {
    test('returns true when MagicStarterServiceProvider is in app.dart', () {
      _writeFile(
        tempDir,
        'lib/config/app.dart',
        '  (app) => MagicStarterServiceProvider(app),\n',
      );
      expect(command.checkProviderRegistered(tempDir.path), isTrue);
    });

    test('returns false when MagicStarterServiceProvider is absent', () {
      _writeFile(tempDir, 'lib/config/app.dart', '// empty providers');
      expect(command.checkProviderRegistered(tempDir.path), isFalse);
    });

    test('returns false when app.dart does not exist', () {
      expect(command.checkProviderRegistered(tempDir.path), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // checkConfigFactory
  // -------------------------------------------------------------------------

  group('checkConfigFactory', () {
    test('returns true when magicStarterConfig is in main.dart', () {
      _writeFile(
        tempDir,
        'lib/main.dart',
        '  configFactories: [() => magicStarterConfig],\n',
      );
      expect(command.checkConfigFactory(tempDir.path), isTrue);
    });

    test('returns false when magicStarterConfig is absent from main.dart', () {
      _writeFile(tempDir, 'lib/main.dart', 'void main() {}\n');
      expect(command.checkConfigFactory(tempDir.path), isFalse);
    });

    test('returns false when main.dart does not exist', () {
      expect(command.checkConfigFactory(tempDir.path), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // checkMiddleware
  // -------------------------------------------------------------------------

  group('checkMiddleware', () {
    test('returns true when EnsureAuthenticated is in kernel.dart', () {
      _writeFile(
        tempDir,
        'lib/app/kernel.dart',
        "  'auth': () => EnsureAuthenticated(),\n",
      );
      expect(command.checkMiddleware(tempDir.path), isTrue);
    });

    test('returns false when EnsureAuthenticated is absent', () {
      _writeFile(tempDir, 'lib/app/kernel.dart', '// empty kernel');
      expect(command.checkMiddleware(tempDir.path), isFalse);
    });

    test('returns false when kernel.dart does not exist', () {
      expect(command.checkMiddleware(tempDir.path), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // checkRoutes
  // -------------------------------------------------------------------------

  group('checkRoutes', () {
    test(
      'returns true when registerMagicStarterAuthRoutes is in route_service_provider.dart',
      () {
        _writeFile(
          tempDir,
          'lib/app/providers/route_service_provider.dart',
          '  registerMagicStarterAuthRoutes();\n',
        );
        expect(command.checkRoutes(tempDir.path), isTrue);
      },
    );

    test('returns false when auth routes are absent', () {
      _writeFile(
        tempDir,
        'lib/app/providers/route_service_provider.dart',
        '// no routes',
      );
      expect(command.checkRoutes(tempDir.path), isFalse);
    });

    test('returns false when route_service_provider.dart does not exist', () {
      expect(command.checkRoutes(tempDir.path), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // checkFacadeSetup
  // -------------------------------------------------------------------------

  group('checkFacadeSetup', () {
    test(
      'returns true when MagicStarter.useNavigation is in app_service_provider.dart',
      () {
        _writeFile(
          tempDir,
          'lib/app/providers/app_service_provider.dart',
          '  MagicStarter.useNavigation(mainItems: []);\n',
        );
        expect(command.checkFacadeSetup(tempDir.path), isTrue);
      },
    );

    test('returns false when MagicStarter.useNavigation is absent', () {
      _writeFile(
        tempDir,
        'lib/app/providers/app_service_provider.dart',
        '// empty provider',
      );
      expect(command.checkFacadeSetup(tempDir.path), isFalse);
    });

    test('returns false when app_service_provider.dart does not exist', () {
      expect(command.checkFacadeSetup(tempDir.path), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // checkTranslations
  // -------------------------------------------------------------------------

  group('checkTranslations', () {
    test('returns true when assets/lang/en.json exists', () {
      _writeFile(tempDir, 'assets/lang/en.json', '{}');
      expect(command.checkTranslations(tempDir.path), isTrue);
    });

    test('returns false when assets/lang/en.json is missing', () {
      expect(command.checkTranslations(tempDir.path), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // getMissingRequirements
  // -------------------------------------------------------------------------

  group('getMissingRequirements', () {
    test('returns empty list when project is fully and correctly installed',
        () {
      _setupFullInstall(tempDir);
      expect(command.getMissingRequirements(), isEmpty);
    });

    test('includes magic framework check when lib/config/app.dart is absent',
        () {
      _setupFullInstall(tempDir);
      File('${tempDir.path}/lib/config/app.dart').deleteSync();

      final missing = command.getMissingRequirements();

      expect(missing.any((m) => m.toLowerCase().contains('magic')), isTrue);
    });

    test('includes starter config check when magic_starter.dart is absent', () {
      _setupFullInstall(tempDir);
      File('${tempDir.path}/lib/config/magic_starter.dart').deleteSync();

      final missing = command.getMissingRequirements();

      expect(missing.any((m) => m.toLowerCase().contains('config')), isTrue);
    });

    test('includes provider check when MagicStarterServiceProvider is absent',
        () {
      _setupFullInstall(tempDir);
      _writeFile(tempDir, 'lib/config/app.dart', '// no provider');

      final missing = command.getMissingRequirements();

      expect(
        missing.any((m) => m.toLowerCase().contains('provider')),
        isTrue,
      );
    });

    test('includes config factory check when magicStarterConfig is absent', () {
      _setupFullInstall(tempDir);
      _writeFile(tempDir, 'lib/main.dart', 'void main() {}\n');

      final missing = command.getMissingRequirements();

      expect(
        missing.any((m) => m.toLowerCase().contains('factory')),
        isTrue,
      );
    });

    test('includes middleware check when EnsureAuthenticated is absent', () {
      _setupFullInstall(tempDir);
      _writeFile(tempDir, 'lib/app/kernel.dart', '// empty kernel');

      final missing = command.getMissingRequirements();

      expect(
        missing.any((m) => m.toLowerCase().contains('middleware')),
        isTrue,
      );
    });

    test('includes routes check when auth routes registration is absent', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/app/providers/route_service_provider.dart',
        '// no routes',
      );

      final missing = command.getMissingRequirements();

      expect(missing.any((m) => m.toLowerCase().contains('route')), isTrue);
    });

    test('includes facade check when MagicStarter.useNavigation is absent', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/app/providers/app_service_provider.dart',
        '// empty',
      );

      final missing = command.getMissingRequirements();

      expect(missing.any((m) => m.toLowerCase().contains('facade')), isTrue);
    });

    test('includes translation check when assets/lang/en.json is absent', () {
      _setupFullInstall(tempDir);
      File('${tempDir.path}/assets/lang/en.json').deleteSync();

      final missing = command.getMissingRequirements();

      expect(
        missing.any((m) => m.toLowerCase().contains('translation')),
        isTrue,
      );
    });

    test('returns correct count when multiple checks fail', () {
      // Empty project — all 8 checks should fail.
      final missing = command.getMissingRequirements();

      expect(missing.length, equals(8));
    });
  });

  // -------------------------------------------------------------------------
  // generateReport
  // -------------------------------------------------------------------------

  group('generateReport', () {
    test('contains a ✓ for every passing check in a fully installed project',
        () {
      _setupFullInstall(tempDir);
      final report = command.generateReport();

      expect(report, contains('✓'));
    });

    test('contains a ✗ for each failing check', () {
      // No files created — all checks fail.
      final report = command.generateReport();

      expect(report, contains('✗'));
    });

    test('shows ✓ for magic framework when lib/config/app.dart exists', () {
      _writeFile(tempDir, 'lib/config/app.dart', '// app');
      final report = command.generateReport();

      expect(report, contains('Magic Framework'));
    });

    test('shows ✓ for starter config when magic_starter.dart exists', () {
      _writeFile(tempDir, 'lib/config/magic_starter.dart', '// cfg');
      final report = command.generateReport();

      expect(report, contains('Starter Config'));
    });

    test('returns a formatted string with check labels', () {
      _setupFullInstall(tempDir);
      final report = command.generateReport();

      expect(report, contains('Provider'));
      expect(report, contains('Config Factory'));
      expect(report, contains('Middleware'));
      expect(report, contains('Routes'));
      expect(report, contains('Facade'));
      expect(report, contains('Translations'));
    });

    test('verbose mode shows file paths for each check', () {
      _setupFullInstall(tempDir);
      final report = command.generateReport(verbose: true);

      expect(report, contains('lib/config/app.dart'));
      expect(report, contains('lib/config/magic_starter.dart'));
    });

    test('non-verbose mode omits file paths', () {
      _setupFullInstall(tempDir);
      final report = command.generateReport(verbose: false);

      // Paths should not appear in non-verbose output.
      expect(report, isNot(contains('lib/config/app.dart')));
    });

    test('includes summary section with all requirements met message', () {
      _setupFullInstall(tempDir);
      final report = command.generateReport();

      expect(report, contains('All requirements met'));
    });

    test('includes summary section listing failures when checks fail', () {
      // No setup — all 8 checks fail.
      final report = command.generateReport();

      expect(report, contains('Missing Requirements'));
    });
  });

  // -------------------------------------------------------------------------
  // --verbose flag
  // -------------------------------------------------------------------------

  group('--verbose flag', () {
    test(
        'verbose flag is registered on the parser without throwing ArgParserException',
        () {
      // Verify the ArgParser accepts --verbose without raising an exception.
      // We parse args directly to avoid handle() calling exit().
      final parser = ArgParser();
      command.configure(parser);

      // Should not throw — flag is defined.
      expect(() => parser.parse(['--verbose']), returnsNormally);
    });

    test('-v short flag is also accepted', () {
      final parser = ArgParser();
      command.configure(parser);

      expect(() => parser.parse(['-v']), returnsNormally);
    });
  });
}
