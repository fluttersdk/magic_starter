import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
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
        '  MagicStarter.bootstrap(userFactory: f, onLogout: g, locales: {});\n'
        '  MagicStarter.useNavigation(mainItems: []);\n'
        '}\n',
  );
  _writeFile(dir, 'assets/lang/en.json', '{}');
}

/// Set up a full install in [dir] whose config carries the notifications
/// feature at [notifications] and the push prefix key set to [value], or with
/// no prefix key at all when [value] is null.
///
/// The `'notifications'` block is written even when the feature is off,
/// because that is what tells the feature flag apart from the block holding
/// the key: a probe matching either one would read this file as having push on.
void _setupNotificationsConfig(
  Directory dir, {
  String? value,
  bool notifications = true,
}) {
  _setupFullInstall(dir);
  _writeFile(
    dir,
    'lib/config/magic_starter.dart',
    'Map<String, dynamic> get magicStarterConfig => {\n'
        "  'magic_starter': {\n"
        "    'features': {'notifications': $notifications},\n"
        "    'notifications': {"
        '${value == null ? '' : "'external_id_prefix': '$value'"}},\n'
        '  },\n'
        '};\n',
  );
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
    test('name is "starter:doctor"', () {
      expect(command.name, equals('starter:doctor'));
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
      'returns true when the identity contract is in app_service_provider.dart',
      () {
        _writeFile(
          tempDir,
          'lib/app/providers/app_service_provider.dart',
          '  MagicStarter.bootstrap(userFactory: f, onLogout: g, locales: {});\n'
              '  MagicStarter.useNavigation(mainItems: []);\n',
        );
        expect(command.checkFacadeSetup(tempDir.path), isTrue);
      },
    );

    test('returns true for an app still wired with the legacy setters', () {
      // This probe accepts exactly what the installer's idempotency guard
      // accepts. If it were narrower, an app the installer now declines to
      // touch would be reported FAIL alongside advice to run that installer.
      _writeFile(
        tempDir,
        'lib/app/providers/app_service_provider.dart',
        "  MagicStarter.useLocaleOptions({'en': 'English'});\n",
      );
      expect(command.checkFacadeSetup(tempDir.path), isTrue);
    });

    test('returns false when the only identity call is commented out', () {
      // Anchored for the same reason as the installer guard: a commented-out
      // example must not read as a configured provider.
      _writeFile(
        tempDir,
        'lib/app/providers/app_service_provider.dart',
        '  // MagicStarter.bootstrap(userFactory: f, onLogout: g, locales: {});\n',
      );
      expect(command.checkFacadeSetup(tempDir.path), isFalse);
    });

    test('returns false when the identity contract is absent', () {
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

  group('checkBillingWebOrigin', () {
    // The failure this check exists to catch is silent. The billing view builds
    // Stripe's successUrl, cancelUrl and the portal returnUrl by concatenating
    // this origin with a path, and Stripe requires absolute urls; a missing
    // origin produces a relative one, session creation fails at Stripe, and the
    // resulting BillingException is logged rather than shown to the customer.
    // An adopter who enabled billing and forgot the key is never told why
    // checkout does nothing.

    test('passes when the billing feature is off, origin or not', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/config/magic_starter.dart',
        "Map<String, dynamic> get magicStarterConfig => {\n"
            "  'magic_starter': {\n"
            "    'features': {'billing': false},\n"
            '  },\n'
            '};\n',
      );

      expect(command.checkBillingWebOrigin(tempDir.path), isTrue);
    });

    test('fails when billing is on and no web origin is configured', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/config/magic_starter.dart',
        "Map<String, dynamic> get magicStarterConfig => {\n"
            "  'magic_starter': {\n"
            "    'features': {'billing': true},\n"
            '  },\n'
            '};\n',
      );

      expect(command.checkBillingWebOrigin(tempDir.path), isFalse);
    });

    test('fails when billing is on and the web origin is an empty string', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/config/magic_starter.dart',
        "Map<String, dynamic> get magicStarterConfig => {\n"
            "  'magic_starter': {\n"
            "    'features': {'billing': true},\n"
            "    'billing': {'web_origin': ''},\n"
            '  },\n'
            '};\n',
      );

      expect(command.checkBillingWebOrigin(tempDir.path), isFalse);
    });

    test('passes when billing is on and a web origin is configured', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/config/magic_starter.dart',
        "Map<String, dynamic> get magicStarterConfig => {\n"
            "  'magic_starter': {\n"
            "    'features': {'billing': true},\n"
            "    'billing': {'web_origin': 'https://app.example.com'},\n"
            '  },\n'
            '};\n',
      );

      expect(command.checkBillingWebOrigin(tempDir.path), isTrue);
    });

    test('passes when the config file is absent', () {
      // A missing config is already reported by checkConfigExists; reporting it
      // twice would tell an adopter to fix billing when the install never ran.
      expect(command.checkBillingWebOrigin(tempDir.path), isTrue);
    });
  });

  group('pushExternalIdPrefix', () {
    // Reported rather than checked, because what can be wrong about a prefix
    // lives in the other repository: `HasNotifications`, `OneSignalChannel`
    // and `PushTestController` compose the same id on the Laravel side, and
    // OneSignal accepts a mismatch and delivers it to nobody. So these cover
    // what the report tells a human, and that it never becomes a failure.

    test('reads the prefix the config file declares', () {
      _setupNotificationsConfig(tempDir, value: 'operator-');

      expect(command.pushExternalIdPrefix(tempDir.path), (
        prefix: 'operator-',
        source: PushPrefixSource.declared,
      ));
    });

    test('falls back to user_ when the key was never written, and says so', () {
      _setupNotificationsConfig(tempDir);

      expect(command.pushExternalIdPrefix(tempDir.path), (
        prefix: 'user_',
        source: PushPrefixSource.absent,
      ));
    });

    test('tells a blank key apart from a key nobody wrote', () {
      // Both resolve to `user_` and they are not the same situation. An
      // adopter chasing a mismatch who is told the key is not set goes and
      // writes the key they already wrote, and never learns that the value
      // they wrote is the one being discarded.
      //
      // The normalisation itself has to match `MagicStarterConfig` exactly or
      // the report lies about what the app will send. Dart's
      // `Config.get<String>(key, default)` returns the STORED value whenever
      // it is a String at all, and `''` is one, so the runtime's own fallback
      // is the explicit blank check rather than the `??`.
      for (final String blank in ['', '   ']) {
        _setupNotificationsConfig(tempDir, value: blank);

        expect(command.pushExternalIdPrefix(tempDir.path), (
          prefix: 'user_',
          source: PushPrefixSource.blank,
        ), reason: 'a blank prefix of ${blank.length} chars');
      }
    });

    test('trims a declared value, the way the runtime does', () {
      _setupNotificationsConfig(tempDir, value: '  staff_  ');

      expect(command.pushExternalIdPrefix(tempDir.path), (
        prefix: 'staff_',
        source: PushPrefixSource.declared,
      ));
    });

    test('ignores a commented-out key above the live one', () {
      // How a prefix change actually looks in a config file: the old line is
      // commented out rather than deleted. The match takes the first hit in
      // the file, so without the comment strip this reports `old_`, which the
      // app has not sent since the day the line was commented out.
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/config/magic_starter.dart',
        'Map<String, dynamic> get magicStarterConfig => {\n'
            "  'magic_starter': {\n"
            "    'features': {'notifications': true},\n"
            "    // 'external_id_prefix': 'old_',\n"
            "    'notifications': {'external_id_prefix': 'new_'},\n"
            '  },\n'
            '};\n',
      );

      expect(command.pushExternalIdPrefix(tempDir.path), (
        prefix: 'new_',
        source: PushPrefixSource.declared,
      ));
    });

    test('keeps a live key that carries a trailing comment', () {
      // The other half of the comment strip: only a line that is nothing BUT a
      // comment goes. Dropping the whole line here would report the key as
      // never written.
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/config/magic_starter.dart',
        'Map<String, dynamic> get magicStarterConfig => {\n'
            "  'magic_starter': {\n"
            "    'features': {'notifications': true},\n"
            "    'billing': {'web_origin': 'https://app.example.com'},\n"
            "    'notifications': {'external_id_prefix': 'staff_'}, // was old_\n"
            '  },\n'
            '};\n',
      );

      expect(command.pushExternalIdPrefix(tempDir.path), (
        prefix: 'staff_',
        source: PushPrefixSource.declared,
      ));
    });

    test('reports nothing when the notifications feature is off', () {
      // The discriminating case for the feature probe: this file contains
      // `'notifications'` twice, once as the flag and once as the block that
      // holds the key, and only the flag decides whether push is in play.
      _setupNotificationsConfig(tempDir, value: 'user_', notifications: false);

      expect(command.pushExternalIdPrefix(tempDir.path), isNull);
    });

    test('reports nothing when the config file is absent', () {
      expect(command.pushExternalIdPrefix(tempDir.path), isNull);
    });

    test('never turns a prefix into a missing requirement', () {
      // Any prefix is valid as long as the backend uses the same one, so the
      // two configs below have to produce identical requirement lists. This
      // goes red the day somebody makes the prefix a check.
      _setupNotificationsConfig(tempDir, value: 'user_');
      final List<String> withDefault = command.getMissingRequirements();

      _setupNotificationsConfig(tempDir, value: 'zzz-');
      final List<String> withOdd = command.getMissingRequirements();

      expect(withOdd, equals(withDefault));
    });
  });

  group('generateReport: push external id prefix', () {
    test('prints the declared prefix', () {
      _setupNotificationsConfig(tempDir, value: 'operator-');

      expect(
        command.generateReport(),
        contains('Push external id prefix: operator-'),
      );
    });

    test('marks a prefix nobody set as the default', () {
      _setupNotificationsConfig(tempDir);

      expect(
        command.generateReport(),
        contains('Push external id prefix: user_ (default, key not set)'),
      );
    });

    test('says a blank key is blank rather than unset', () {
      // Same resolved prefix as the test above, different sentence, and the
      // difference is the whole point: "key not set" sends an adopter to write
      // a key that is already there.
      _setupNotificationsConfig(tempDir, value: '');

      final String report = command.generateReport();

      expect(
        report,
        contains('Push external id prefix: user_ (blank, using default)'),
      );
      expect(report, isNot(contains('key not set')));
    });

    test('says nothing at all when notifications are off', () {
      // An app that sends no push has no side to agree with, so the line is
      // absent rather than reported as not applicable.
      _setupNotificationsConfig(tempDir, value: 'user_', notifications: false);

      expect(command.generateReport(), isNot(contains('external id prefix')));
    });

    test('verbose names the key and the file on the other side', () {
      _setupNotificationsConfig(tempDir, value: 'user_');

      final String report = command.generateReport(verbose: true);

      expect(
        report,
        contains('magic_starter.notifications.external_id_prefix'),
      );
      expect(report, contains('config/magic-starter.php'));
    });

    test('non-verbose leaves the backend pointer out', () {
      _setupNotificationsConfig(tempDir, value: 'user_');

      expect(
        command.generateReport(),
        isNot(contains('config/magic-starter.php')),
      );
    });
  });

  group('getMissingRequirements', () {
    test(
      'returns empty list when project is fully and correctly installed',
      () {
        _setupFullInstall(tempDir);
        expect(command.getMissingRequirements(), isEmpty);
      },
    );

    test('includes the billing origin when billing is on without one', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/config/magic_starter.dart',
        "Map<String, dynamic> get magicStarterConfig => {\n"
            "  'magic_starter': {\n"
            "    'features': {'billing': true},\n"
            '  },\n'
            '};\n',
      );

      final missing = command.getMissingRequirements();

      expect(
        missing.any((m) => m.contains('web_origin')),
        isTrue,
        reason: 'the message has to name the key an adopter must add',
      );
    });

    test(
      'includes magic framework check when lib/config/app.dart is absent',
      () {
        _setupFullInstall(tempDir);
        File('${tempDir.path}/lib/config/app.dart').deleteSync();

        final missing = command.getMissingRequirements();

        expect(missing.any((m) => m.toLowerCase().contains('magic')), isTrue);
      },
    );

    test('includes starter config check when magic_starter.dart is absent', () {
      _setupFullInstall(tempDir);
      File('${tempDir.path}/lib/config/magic_starter.dart').deleteSync();

      final missing = command.getMissingRequirements();

      expect(missing.any((m) => m.toLowerCase().contains('config')), isTrue);
    });

    test(
      'includes provider check when MagicStarterServiceProvider is absent',
      () {
        _setupFullInstall(tempDir);
        _writeFile(tempDir, 'lib/config/app.dart', '// no provider');

        final missing = command.getMissingRequirements();

        expect(
          missing.any((m) => m.toLowerCase().contains('provider')),
          isTrue,
        );
      },
    );

    test('includes config factory check when magicStarterConfig is absent', () {
      _setupFullInstall(tempDir);
      _writeFile(tempDir, 'lib/main.dart', 'void main() {}\n');

      final missing = command.getMissingRequirements();

      expect(missing.any((m) => m.toLowerCase().contains('factory')), isTrue);
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

    test('includes facade check when the identity contract is absent', () {
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
    test(
      'contains "OK" for every passing check in a fully installed project',
      () {
        _setupFullInstall(tempDir);
        final report = command.generateReport();

        expect(report, contains('OK'));
      },
    );

    test('contains "FAIL" for each failing check', () {
      // No files created — all checks fail.
      final report = command.generateReport();

      expect(report, contains('FAIL'));
    });

    test(
      'shows passing result for magic framework when lib/config/app.dart exists',
      () {
        _writeFile(tempDir, 'lib/config/app.dart', '// app');
        final report = command.generateReport();

        expect(report, contains('Magic Framework'));
      },
    );

    test(
      'shows passing result for starter config when magic_starter.dart exists',
      () {
        _writeFile(tempDir, 'lib/config/magic_starter.dart', '// cfg');
        final report = command.generateReport();

        expect(report, contains('Starter Config'));
      },
    );

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
  // getPublishedViews
  // -------------------------------------------------------------------------

  group('getPublishedViews', () {
    test(
      'returns empty list when published views directory does not exist',
      () {
        expect(command.getPublishedViews(tempDir.path), isEmpty);
      },
    );

    test(
      'returns empty list when directory exists but contains no dart files',
      () {
        Directory(
          '${tempDir.path}/lib/resources/views/starter',
        ).createSync(recursive: true);
        expect(command.getPublishedViews(tempDir.path), isEmpty);
      },
    );

    test(
      'returns relative paths for dart files in published views directory',
      () {
        _writeFile(
          tempDir,
          'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          '// login view',
        );
        _writeFile(
          tempDir,
          'lib/resources/views/starter/auth/magic_starter_register_view.dart',
          '// register view',
        );

        final views = command.getPublishedViews(tempDir.path);

        expect(views.length, equals(2));
        expect(
          views,
          contains(
            'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          ),
        );
        expect(
          views,
          contains(
            'lib/resources/views/starter/auth/magic_starter_register_view.dart',
          ),
        );
      },
    );

    test('ignores non-dart files in the published views directory', () {
      _writeFile(
        tempDir,
        'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        '// login view',
      );
      _writeFile(
        tempDir,
        'lib/resources/views/starter/auth/README.md',
        '# readme',
      );

      final views = command.getPublishedViews(tempDir.path);

      expect(views.length, equals(1));
    });

    test('returns sorted list when multiple views exist', () {
      _writeFile(
        tempDir,
        'lib/resources/views/starter/profile/magic_starter_profile_settings_view.dart',
        '// profile',
      );
      _writeFile(
        tempDir,
        'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        '// login',
      );

      final views = command.getPublishedViews(tempDir.path);

      expect(views.first, contains('auth'));
      expect(views.last, contains('profile'));
    });
  });

  // -------------------------------------------------------------------------
  // isPublishedViewWired
  // -------------------------------------------------------------------------

  group('isPublishedViewWired', () {
    const viewPath =
        'lib/resources/views/starter/auth/magic_starter_login_view.dart';

    test('returns true when app_service_provider.dart does not exist', () {
      expect(command.isPublishedViewWired(tempDir.path, viewPath), isTrue);
    });

    test(
      'returns true when provider contains the view filename stem (registered)',
      () {
        _writeFile(
          tempDir,
          'lib/app/providers/app_service_provider.dart',
          "import '../../resources/views/starter/auth/magic_starter_login_view.dart';\n"
              "MagicStarter.view.register('auth.login', () => const MagicStarterLoginView());\n",
        );

        expect(command.isPublishedViewWired(tempDir.path, viewPath), isTrue);
      },
    );

    test(
      'returns false when provider exists but does not reference the view',
      () {
        _writeFile(
          tempDir,
          'lib/app/providers/app_service_provider.dart',
          '// empty provider — no registrations\n',
        );

        expect(command.isPublishedViewWired(tempDir.path, viewPath), isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // generateReport — published views section
  // -------------------------------------------------------------------------

  group('generateReport — published views', () {
    test(
      'report omits Published Views section when no views are published',
      () {
        _setupFullInstall(tempDir);
        final report = command.generateReport();

        expect(report, isNot(contains('Published Views')));
      },
    );

    test(
      'report includes Published Views section when views are published',
      () {
        _setupFullInstall(tempDir);
        _writeFile(
          tempDir,
          'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          '// login view',
        );

        final report = command.generateReport();

        expect(report, contains('Published Views'));
      },
    );

    test('report shows "OK" for a wired published view', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        '// login view',
      );
      // Wire the view in AppServiceProvider.
      _writeFile(
        tempDir,
        'lib/app/providers/app_service_provider.dart',
        "import 'package:magic_starter/magic_starter.dart';\n"
            'void boot() {\n'
            '  MagicStarter.bootstrap(userFactory: f, onLogout: g, locales: {});\n'
            '  MagicStarter.useNavigation(mainItems: []);\n'
            "  MagicStarter.view.register('auth.login', () => const MagicStarterLoginView());\n"
            '}\n',
      );

      final report = command.generateReport();

      // The command emits "OK <viewPath>" for a wired view.
      expect(report, contains('OK'));
      expect(
        report,
        contains(
          'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        ),
      );
    });

    test('report shows "WARN" for an unwired published view', () {
      _setupFullInstall(tempDir);
      _writeFile(
        tempDir,
        'lib/resources/views/starter/auth/magic_starter_login_view.dart',
        '// login view',
      );
      // AppServiceProvider exists but has no registration for the view.
      _writeFile(
        tempDir,
        'lib/app/providers/app_service_provider.dart',
        "import 'package:magic_starter/magic_starter.dart';\n"
            'void boot() {\n'
            '  MagicStarter.bootstrap(userFactory: f, onLogout: g, locales: {});\n'
            '  MagicStarter.useNavigation(mainItems: []);\n'
            '}\n',
      );

      final report = command.generateReport();

      expect(report, contains('WARN'));
      expect(report, contains('Not wired'));
    });

    test(
      'unwired published views do not affect getMissingRequirements count (warnings only)',
      () {
        _setupFullInstall(tempDir);
        _writeFile(
          tempDir,
          'lib/resources/views/starter/auth/magic_starter_login_view.dart',
          '// login view',
        );
        // AppServiceProvider exists but has no registration.
        _writeFile(
          tempDir,
          'lib/app/providers/app_service_provider.dart',
          "import 'package:magic_starter/magic_starter.dart';\n"
              'void boot() {\n'
              '  MagicStarter.bootstrap(userFactory: f, onLogout: g, locales: {});\n'
              '  MagicStarter.useNavigation(mainItems: []);\n'
              '}\n',
        );

        // Missing requirements count must stay at 0 — published view warnings
        // are informational and do not block the health check.
        expect(command.getMissingRequirements(), isEmpty);
      },
    );
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
      },
    );

    test('unknown flag raises ArgParserException', () {
      // The signature DSL does not register a -v abbreviation; verify that
      // an unrecognised flag causes a parse error rather than silently
      // passing through.
      final parser = ArgParser();
      command.configure(parser);

      expect(() => parser.parse(['-v']), throwsA(isA<ArgParserException>()));
    });
  });
}
