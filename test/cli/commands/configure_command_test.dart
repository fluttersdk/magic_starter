import 'dart:io';

import 'package:magic_starter/src/cli/commands/configure_command.dart';
import 'package:test/test.dart';

/// Test double that overrides [ConfigureCommand.getProjectRoot] to point at a
/// temporary directory, isolating all file I/O from the real file system.
class _TestConfigureCommand extends ConfigureCommand {
  final String _root;

  _TestConfigureCommand(this._root);

  @override
  String getProjectRoot() => _root;
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
  late _TestConfigureCommand command;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('configure_command_test_');
    command = _TestConfigureCommand(tempDir.path);
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
    test('name is configure', () {
      expect(command.name, equals('configure'));
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
      await command.runWith(['--show']);
      // If we reach here without exception, output succeeded.
    });

    test('errors when config file not found and --show is given', () async {
      File('${tempDir.path}/lib/config/magic_starter.dart').deleteSync();

      // Should not throw but should write to stderr — just verify no crash.
      await command.runWith(['--show']);
    });
  });

  // -------------------------------------------------------------------------
  // Error handling — missing config
  // -------------------------------------------------------------------------
  group('missing config', () {
    test('errors when config file not found before any toggle', () async {
      File('${tempDir.path}/lib/config/magic_starter.dart').deleteSync();

      // Must not throw — handle() should write error and return.
      await command.runWith(['--teams']);
    });
  });

  // -------------------------------------------------------------------------
  // --teams / --no-teams
  // -------------------------------------------------------------------------
  group('--teams / --no-teams', () {
    test('toggles teams feature on with --teams', () async {
      _setupConfigFile(tempDir, teams: false);

      await command.runWith(['--teams']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      expect(content, contains("'teams': true"));
    });

    test('toggles teams feature off with --no-teams', () async {
      _setupConfigFile(tempDir, teams: true);

      await command.runWith(['--no-teams']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      expect(content, contains("'teams': false"));
    });
  });

  // -------------------------------------------------------------------------
  // --social-login / --no-social-login
  // -------------------------------------------------------------------------
  group('--social-login / --no-social-login', () {
    test('toggles social-login feature on with --social-login', () async {
      _setupConfigFile(tempDir, socialLogin: false);

      await command.runWith(['--social-login']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      expect(content, contains("'social_login': true"));
    });

    test('toggles social-login feature off with --no-social-login', () async {
      _setupConfigFile(tempDir, socialLogin: true);

      await command.runWith(['--no-social-login']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
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

      await command.runWith([
        '--teams',
        '--newsletter',
        '--email-verification',
      ]);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
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

      await command.runWith(['--teams']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();

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

      await command.runWith(['--teams']);
      await command.runWith(['--teams']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      // Exactly one match — not doubled or corrupted.
      expect("'teams': true".allMatches(content).length, equals(1));
    });

    test('toggling off then on restores original value', () async {
      _setupConfigFile(tempDir, socialLogin: true);

      await command.runWith(['--no-social-login']);
      await command.runWith(['--social-login']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      expect(content, contains("'social_login': true"));
    });
  });

  // -------------------------------------------------------------------------
  // All feature flags
  // -------------------------------------------------------------------------
  group('all feature flags', () {
    test('--two-factor enables two_factor feature', () async {
      _setupConfigFile(tempDir, twoFactor: false);
      await command.runWith(['--two-factor']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      expect(content, contains("'two_factor': true"));
    });

    test('--no-sessions disables sessions feature', () async {
      _setupConfigFile(tempDir, sessions: true);
      await command.runWith(['--no-sessions']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      expect(content, contains("'sessions': false"));
    });

    test('--phone-otp enables phone_otp feature', () async {
      _setupConfigFile(tempDir, phoneOtp: false);
      await command.runWith(['--phone-otp']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      expect(content, contains("'phone_otp': true"));
    });

    test('--no-notifications disables notifications feature', () async {
      _setupConfigFile(tempDir, notifications: true);
      await command.runWith(['--no-notifications']);

      final content = File('${tempDir.path}/lib/config/magic_starter.dart')
          .readAsStringSync();
      expect(content, contains("'notifications': false"));
    });
  });
}
