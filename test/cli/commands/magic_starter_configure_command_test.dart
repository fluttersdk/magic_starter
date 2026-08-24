import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:magic_starter/src/cli/commands/magic_starter_configure_command.dart';
import 'package:test/test.dart';

/// Test double that overrides [MagicStarterConfigureCommand.getProjectRoot] to point at a
/// temporary directory, isolating all file I/O from the real file system.
class _TestMagicStarterConfigureCommand extends MagicStarterConfigureCommand {
  final String _root;

  _TestMagicStarterConfigureCommand(this._root);

  @override
  String getProjectRoot() => _root;
}

/// Drives [command.handle] with a programmatic [ArtisanContext] composed of a
/// [MapInput] (flags) and a [BufferedOutput] (capturable).
///
/// Flags are passed as a plain map: include a key to signal "was parsed",
/// omit it to leave it untouched. Bool flags use `true`/`false` as values;
/// string options supply the string value directly.
Future<int> _runConfigure(
  MagicStarterConfigureCommand command,
  Map<String, dynamic> flags,
) {
  final ctx = ArtisanContext.bare(MapInput(flags), BufferedOutput());
  return command.handle(ctx);
}

/// Writes a canonical magic_starter config file to [dir] with the given
/// feature toggle values. Used across all test scenarios to set up state.
void _setupConfigFile(
  Directory dir, {
  bool teams = false,
  bool socialLogin = false,
  bool twoFactor = false,
  bool sessions = false,
  bool phoneOtp = false,
  bool newsletter = false,
  bool notifications = false,
  bool emailVerification = false,
}) {
  final configFile = File('${dir.path}/lib/config/magic_starter.dart');
  configFile.parent.createSync(recursive: true);
  configFile.writeAsStringSync("""
Map<String, dynamic> get magicStarterConfig => {
  'magic_starter': {
    'features': {
      'teams': $teams,
      'social_login': $socialLogin,
      'two_factor': $twoFactor,
      'sessions': $sessions,
      'phone_otp': $phoneOtp,
      'newsletter': $newsletter,
      'notifications': $notifications,
      'email_verification': $emailVerification,
    },
  },
};
""");
}

void main() {
  late Directory tempDir;
  late _TestMagicStarterConfigureCommand command;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('configure_command_test_');
    command = _TestMagicStarterConfigureCommand(tempDir.path);
    _setupConfigFile(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  // -------------------------------------------------------------------------
  // Command identity
  // -------------------------------------------------------------------------
  group('command identity', () {
    test('name is starter:configure', () {
      expect(command.name, equals('starter:configure'));
    });

    test('description is non-empty', () {
      expect(command.description, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // --show flag
  // -------------------------------------------------------------------------
  group('--show', () {
    test('displays current configuration without errors', () async {
      await _runConfigure(command, {'show': true});
      // If we reach here without exception, output succeeded.
    });

    test('errors when config file not found and --show is given', () async {
      File('${tempDir.path}/lib/config/magic_starter.dart').deleteSync();

      // Should not throw but should write to stderr — just verify no crash.
      await _runConfigure(command, {'show': true});
    });
  });

  // -------------------------------------------------------------------------
  // Error handling — missing config
  // -------------------------------------------------------------------------
  group('missing config', () {
    test('errors when config file not found before any toggle', () async {
      File('${tempDir.path}/lib/config/magic_starter.dart').deleteSync();

      // Must not throw — handle() should write error and return.
      await _runConfigure(command, {'teams': true});
    });
  });

  // -------------------------------------------------------------------------
  // --teams / --no-teams
  // -------------------------------------------------------------------------
  group('--teams / --no-teams', () {
    test('toggles teams feature on with --teams', () async {
      _setupConfigFile(tempDir, teams: false);

      await _runConfigure(command, {'teams': true});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'teams': true"));
    });

    test('toggles teams feature off with --no-teams', () async {
      _setupConfigFile(tempDir, teams: true);

      await _runConfigure(command, {'teams': false});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'teams': false"));
    });
  });

  // -------------------------------------------------------------------------
  // --social-login / --no-social-login
  // -------------------------------------------------------------------------
  group('--social-login / --no-social-login', () {
    test('toggles social-login feature on with --social-login', () async {
      _setupConfigFile(tempDir, socialLogin: false);

      await _runConfigure(command, {'social-login': true});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'social_login': true"));
    });

    test('toggles social-login feature off with --no-social-login', () async {
      _setupConfigFile(tempDir, socialLogin: true);

      await _runConfigure(command, {'social-login': false});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'social_login': false"));
    });
  });

  // -------------------------------------------------------------------------
  // Multiple flags
  // -------------------------------------------------------------------------
  group('multiple feature flags', () {
    test('toggles multiple features in one call', () async {
      _setupConfigFile(
        tempDir,
        teams: false,
        newsletter: false,
        emailVerification: false,
      );

      await _runConfigure(command, {
        'teams': true,
        'newsletter': true,
        'email-verification': true,
      });

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'teams': true"));
      expect(content, contains("'newsletter': true"));
      expect(content, contains("'email_verification': true"));
    });
  });

  // -------------------------------------------------------------------------
  // Preserving other values
  // -------------------------------------------------------------------------
  group('preserving other config values', () {
    test('preserves other feature values when updating one feature', () async {
      _setupConfigFile(
        tempDir,
        teams: false,
        socialLogin: true,
        twoFactor: true,
        sessions: false,
        phoneOtp: false,
        newsletter: true,
        notifications: false,
        emailVerification: false,
      );

      await _runConfigure(command, {'teams': true});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();

      // Updated feature.
      expect(content, contains("'teams': true"));

      // Untouched features remain unchanged.
      expect(content, contains("'social_login': true"));
      expect(content, contains("'two_factor': true"));
      expect(content, contains("'sessions': false"));
      expect(content, contains("'phone_otp': false"));
      expect(content, contains("'newsletter': true"));
      expect(content, contains("'notifications': false"));
      expect(content, contains("'email_verification': false"));
    });
  });

  // -------------------------------------------------------------------------
  // Idempotency
  // -------------------------------------------------------------------------
  group('idempotency', () {
    test('setting same value twice does not corrupt the file', () async {
      _setupConfigFile(tempDir, teams: true);

      await _runConfigure(command, {'teams': true});
      await _runConfigure(command, {'teams': true});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      // Exactly one match — not doubled or corrupted.
      expect("'teams': true".allMatches(content).length, equals(1));
    });

    test('toggling off then on restores original value', () async {
      _setupConfigFile(tempDir, socialLogin: true);

      await _runConfigure(command, {'social-login': false});
      await _runConfigure(command, {'social-login': true});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'social_login': true"));
    });
  });

  // -------------------------------------------------------------------------
  // All feature flags
  // -------------------------------------------------------------------------
  group('all feature flags', () {
    test('--two-factor enables two_factor feature', () async {
      _setupConfigFile(tempDir, twoFactor: false);
      await _runConfigure(command, {'two-factor': true});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'two_factor': true"));
    });

    test('--no-sessions disables sessions feature', () async {
      _setupConfigFile(tempDir, sessions: true);
      await _runConfigure(command, {'sessions': false});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'sessions': false"));
    });

    test('--phone-otp enables phone_otp feature', () async {
      _setupConfigFile(tempDir, phoneOtp: false);
      await _runConfigure(command, {'phone-otp': true});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'phone_otp': true"));
    });

    test('--no-notifications disables notifications feature', () async {
      _setupConfigFile(tempDir, notifications: true);
      await _runConfigure(command, {'notifications': false});

      final content = File(
        '${tempDir.path}/lib/config/magic_starter.dart',
      ).readAsStringSync();
      expect(content, contains("'notifications': false"));
    });
  });
}
