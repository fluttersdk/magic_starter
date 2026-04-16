import 'dart:io';

import 'package:magic_starter/src/cli/commands/magic_starter_publish_command.dart';
import 'package:test/test.dart';

class TestMagicStarterPublishCommand extends MagicStarterPublishCommand {
  final String _projectRoot;
  final String _pluginSourceDir;

  TestMagicStarterPublishCommand(
    this._projectRoot,
    this._pluginSourceDir,
  );

  @override
  String getProjectRoot() => _projectRoot;

  @override
  String? getPluginSourceDir() => _pluginSourceDir;
}

void main() {
  late Directory tempDir;
  late Directory pluginDir;
  late TestMagicStarterPublishCommand command;

  void createPluginFile(
    String relativePath,
    String content,
  ) {
    final file = File('${pluginDir.path}/$relativePath');
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  void createHostFile(String relativePath, String content) {
    final file = File('${tempDir.path}/$relativePath');
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String readHostFile(String relativePath) {
    return File('${tempDir.path}/$relativePath').readAsStringSync();
  }

  bool hostFileExists(String relativePath) {
    return File('${tempDir.path}/$relativePath').existsSync();
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('publish_test_');
    pluginDir = Directory.systemTemp.createTempSync('plugin_source_');

    command = TestMagicStarterPublishCommand(
      tempDir.path,
      pluginDir.path,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }

    if (pluginDir.existsSync()) {
      pluginDir.deleteSync(recursive: true);
    }
  });

  group('MagicStarterPublishCommand', () {
    test('name is publish', () {
      expect(command.name, 'publish');
    });

    test('--tag=config copies config file from plugin to host', () async {
      createPluginFile(
        'lib/config/magic_starter.dart',
        'final map = <String, dynamic>{\'ok\': true};',
      );

      await command.runWith([
        '--tag=config',
      ]);

      expect(hostFileExists('lib/config/magic_starter.dart'), isTrue);
      expect(
        readHostFile('lib/config/magic_starter.dart'),
        'final map = <String, dynamic>{\'ok\': true};',
      );
    });

    test('--tag=config skips when file exists and no --force', () async {
      createPluginFile(
        'lib/config/magic_starter.dart',
        'new-content',
      );

      final existing = File('${tempDir.path}/lib/config/magic_starter.dart');
      existing.createSync(recursive: true);
      existing.writeAsStringSync('existing-content');

      await command.runWith([
        '--tag=config',
      ]);

      expect(existing.readAsStringSync(), 'existing-content');
    });

    test('--tag=config overwrites when --force set', () async {
      createPluginFile(
        'lib/config/magic_starter.dart',
        'forced-content',
      );

      final existing = File('${tempDir.path}/lib/config/magic_starter.dart');
      existing.createSync(recursive: true);
      existing.writeAsStringSync('existing-content');

      await command.runWith([
        '--tag=config',
        '--force',
      ]);

      expect(existing.readAsStringSync(), 'forced-content');
    });

    test('--tag=views copies view files to lib/resources/views/starter/',
        () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class LoginView {}',
      );
      createPluginFile(
        'lib/src/ui/views/profile/settings_view.dart',
        'class SettingsView {}',
      );

      await command.runWith([
        '--tag=views',
      ]);

      expect(
        hostFileExists(
            'lib/resources/views/starter/auth/magic_starter_login_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/profile/settings_view.dart'),
        isTrue,
      );
      expect(
        readHostFile(
            'lib/resources/views/starter/auth/magic_starter_login_view.dart'),
        'class LoginView {}',
      );
    });

    test('--tag=lang copies translation JSON', () async {
      createPluginFile(
        'assets/stubs/install/en.stub',
        '{"auth.login":"Login"}',
      );

      await command.runWith([
        '--tag=lang',
      ]);

      expect(hostFileExists('assets/lang/en.json'), isTrue);
      expect(readHostFile('assets/lang/en.json'), '{"auth.login":"Login"}');
    });

    test('--tag=middleware copies middleware files', () async {
      createPluginFile(
        'assets/stubs/install/ensure_authenticated.stub',
        'class EnsureAuthenticated {}',
      );
      createPluginFile(
        'assets/stubs/install/redirect_if_authenticated.stub',
        'class RedirectIfAuthenticated {}',
      );

      await command.runWith([
        '--tag=middleware',
      ]);

      expect(hostFileExists('lib/app/middleware/ensure_authenticated.dart'),
          isTrue);
      expect(
          hostFileExists('lib/app/middleware/redirect_if_authenticated.dart'),
          isTrue);
      expect(
        readHostFile('lib/app/middleware/ensure_authenticated.dart'),
        'class EnsureAuthenticated {}',
      );
      expect(
        readHostFile('lib/app/middleware/redirect_if_authenticated.dart'),
        'class RedirectIfAuthenticated {}',
      );
    });

    test('--tag=all (default) copies config + views + lang + middleware',
        () async {
      createPluginFile(
        'lib/config/magic_starter.dart',
        'config-content',
      );
      createPluginFile(
        'lib/src/ui/views/teams/magic_starter_team_settings_view.dart',
        'class TeamSettingsView {}',
      );
      createPluginFile(
        'assets/stubs/install/en.stub',
        '{"starter":true}',
      );
      createPluginFile(
        'assets/stubs/install/ensure_authenticated.stub',
        'ensure-content',
      );
      createPluginFile(
        'assets/stubs/install/redirect_if_authenticated.stub',
        'redirect-content',
      );

      await command.runWith([]);

      expect(hostFileExists('lib/config/magic_starter.dart'), isTrue);
      expect(
        hostFileExists(
            'lib/resources/views/starter/teams/magic_starter_team_settings_view.dart'),
        isTrue,
      );
      expect(hostFileExists('assets/lang/en.json'), isTrue);
      expect(hostFileExists('lib/app/middleware/ensure_authenticated.dart'),
          isTrue);
      expect(
          hostFileExists('lib/app/middleware/redirect_if_authenticated.dart'),
          isTrue);
    });

    test('creates parent directories if they do not exist', () async {
      createPluginFile(
        'lib/config/magic_starter.dart',
        'config-content',
      );

      expect(Directory('${tempDir.path}/lib').existsSync(), isFalse);

      await command.runWith([
        '--tag=config',
      ]);

      expect(Directory('${tempDir.path}/lib/config').existsSync(), isTrue);
      expect(hostFileExists('lib/config/magic_starter.dart'), isTrue);
    });

    // -------------------------------------------------------------------
    // Granular view publishing
    // -------------------------------------------------------------------

    test('--tag=views:auth publishes only auth module views', () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class LoginView {}',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_register_view.dart',
        'class RegisterView {}',
      );
      createPluginFile(
        'lib/src/ui/views/profile/magic_starter_profile_settings_view.dart',
        'class ProfileSettingsView {}',
      );

      await command.runWith([
        '--tag=views:auth',
      ]);

      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_login_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_register_view.dart'),
        isTrue,
      );
      // Profile view should NOT be published.
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/profile/magic_starter_profile_settings_view.dart'),
        isFalse,
      );
    });

    test('--tag=views:auth.login publishes single view by registry key',
        () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class LoginView {}',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_register_view.dart',
        'class RegisterView {}',
      );

      await command.runWith([
        '--tag=views:auth.login',
      ]);

      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_login_view.dart'),
        isTrue,
      );
      expect(
        readHostFile(
            'lib/resources/views/starter/views/auth/magic_starter_login_view.dart'),
        'class LoginView {}',
      );
      // Other auth views should NOT be published.
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_register_view.dart'),
        isFalse,
      );
    });

    test('--tag=views:auth publishes all six auth views when present',
        () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'login',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_register_view.dart',
        'register',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_forgot_password_view.dart',
        'forgot',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_reset_password_view.dart',
        'reset',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_two_factor_challenge_view.dart',
        'two_factor',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_otp_verify_view.dart',
        'otp',
      );

      await command.runWith([
        '--tag=views:auth',
      ]);

      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_login_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_register_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_forgot_password_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_reset_password_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_two_factor_challenge_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/auth/magic_starter_otp_verify_view.dart'),
        isTrue,
      );
    });

    test('--tag=views:notifications publishes notification module views',
        () async {
      createPluginFile(
        'lib/src/ui/views/notifications/magic_starter_notifications_list_view.dart',
        'class NotificationsListView {}',
      );
      createPluginFile(
        'lib/src/ui/views/notifications/magic_starter_notification_preferences_view.dart',
        'class NotificationPreferencesView {}',
      );

      await command.runWith([
        '--tag=views:notifications',
      ]);

      expect(
        hostFileExists(
            'lib/resources/views/starter/views/notifications/magic_starter_notifications_list_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/notifications/magic_starter_notification_preferences_view.dart'),
        isTrue,
      );
    });

    test('--tag=views:unknown reports error for unknown view scope', () async {
      await command.runWith([
        '--tag=views:unknown',
      ]);

      // No files should be created.
      expect(
        Directory('${tempDir.path}/lib/resources').existsSync(),
        isFalse,
      );
    });

    // -------------------------------------------------------------------
    // Granular layout publishing
    // -------------------------------------------------------------------

    test('--tag=layouts publishes both layout files', () async {
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_app_layout.dart',
        'class AppLayout {}',
      );
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_guest_layout.dart',
        'class GuestLayout {}',
      );

      await command.runWith([
        '--tag=layouts',
      ]);

      expect(
        hostFileExists(
            'lib/resources/layouts/starter/layouts/magic_starter_app_layout.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/layouts/starter/layouts/magic_starter_guest_layout.dart'),
        isTrue,
      );
    });

    test('--tag=layouts:app publishes only the app layout', () async {
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_app_layout.dart',
        'class AppLayout {}',
      );
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_guest_layout.dart',
        'class GuestLayout {}',
      );

      await command.runWith([
        '--tag=layouts:app',
      ]);

      expect(
        hostFileExists(
            'lib/resources/layouts/starter/layouts/magic_starter_app_layout.dart'),
        isTrue,
      );
      expect(
        readHostFile(
            'lib/resources/layouts/starter/layouts/magic_starter_app_layout.dart'),
        'class AppLayout {}',
      );
      // Guest layout should NOT be published.
      expect(
        hostFileExists(
            'lib/resources/layouts/starter/layouts/magic_starter_guest_layout.dart'),
        isFalse,
      );
    });

    test('--tag=layouts:guest publishes only the guest layout', () async {
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_guest_layout.dart',
        'class GuestLayout {}',
      );

      await command.runWith([
        '--tag=layouts:guest',
      ]);

      expect(
        hostFileExists(
            'lib/resources/layouts/starter/layouts/magic_starter_guest_layout.dart'),
        isTrue,
      );
    });

    test('--tag=layouts:unknown reports error for unknown layout scope',
        () async {
      await command.runWith([
        '--tag=layouts:unknown',
      ]);

      expect(
        Directory('${tempDir.path}/lib/resources').existsSync(),
        isFalse,
      );
    });

    // -------------------------------------------------------------------
    // Granular view publishing with --force
    // -------------------------------------------------------------------

    test('--tag=views:auth.login with --force overwrites existing file',
        () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'new-login-content',
      );

      final existing = File(
        '${tempDir.path}/lib/resources/views/starter/views/auth/magic_starter_login_view.dart',
      );
      existing.createSync(recursive: true);
      existing.writeAsStringSync('old-login-content');

      await command.runWith([
        '--tag=views:auth.login',
        '--force',
      ]);

      expect(
        readHostFile(
            'lib/resources/views/starter/views/auth/magic_starter_login_view.dart'),
        'new-login-content',
      );
    });

    test('--tag=views:auth.login without --force skips existing file',
        () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'new-login-content',
      );

      final existing = File(
        '${tempDir.path}/lib/resources/views/starter/views/auth/magic_starter_login_view.dart',
      );
      existing.createSync(recursive: true);
      existing.writeAsStringSync('old-login-content');

      await command.runWith([
        '--tag=views:auth.login',
      ]);

      expect(
        readHostFile(
            'lib/resources/views/starter/views/auth/magic_starter_login_view.dart'),
        'old-login-content',
      );
    });

    test('--tag=views:profile publishes profile module views', () async {
      createPluginFile(
        'lib/src/ui/views/profile/magic_starter_profile_settings_view.dart',
        'class ProfileSettingsView {}',
      );

      await command.runWith([
        '--tag=views:profile',
      ]);

      expect(
        hostFileExists(
            'lib/resources/views/starter/views/profile/magic_starter_profile_settings_view.dart'),
        isTrue,
      );
    });

    test('--tag=views:teams publishes team module views', () async {
      createPluginFile(
        'lib/src/ui/views/teams/magic_starter_team_create_view.dart',
        'class TeamCreateView {}',
      );
      createPluginFile(
        'lib/src/ui/views/teams/magic_starter_team_settings_view.dart',
        'class TeamSettingsView {}',
      );
      createPluginFile(
        'lib/src/ui/views/teams/magic_starter_team_invitation_accept_view.dart',
        'class TeamInvitationAcceptView {}',
      );

      await command.runWith([
        '--tag=views:teams',
      ]);

      expect(
        hostFileExists(
            'lib/resources/views/starter/views/teams/magic_starter_team_create_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/teams/magic_starter_team_settings_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/views/teams/magic_starter_team_invitation_accept_view.dart'),
        isTrue,
      );
    });

    // -------------------------------------------------------------------
    // Auto-wire into AppServiceProvider
    // -------------------------------------------------------------------

    test('auto-wires view registration into AppServiceProvider after publish',
        () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class MagicStarterLoginView {}',
      );

      // Create a mock AppServiceProvider.
      createHostFile(
        'lib/app/providers/app_service_provider.dart',
        '''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    // existing boot code
  }
}
''',
      );

      await command.runWith([
        '--tag=views:auth.login',
      ]);

      final content =
          readHostFile('lib/app/providers/app_service_provider.dart');

      // Should contain the import.
      expect(
        content,
        contains(
          "import '../../resources/views/starter/views/auth/magic_starter_login_view.dart';",
        ),
      );

      // Should contain the registration call.
      expect(
        content,
        contains(
          "MagicStarter.view.register('auth.login', () => const MagicStarterLoginView());",
        ),
      );
    });

    test('auto-wires layout registration into AppServiceProvider after publish',
        () async {
      createPluginFile(
        'lib/src/ui/layouts/magic_starter_app_layout.dart',
        'class MagicStarterAppLayout {}',
      );

      createHostFile(
        'lib/app/providers/app_service_provider.dart',
        '''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    // existing boot code
  }
}
''',
      );

      await command.runWith([
        '--tag=layouts:app',
      ]);

      final content =
          readHostFile('lib/app/providers/app_service_provider.dart');

      expect(
        content,
        contains(
          "import '../../resources/layouts/starter/layouts/magic_starter_app_layout.dart';",
        ),
      );

      expect(
        content,
        contains(
          "MagicStarter.view.registerLayout('layout.app', (child) => MagicStarterAppLayout(child: child));",
        ),
      );
    });

    test('auto-wire is idempotent: second run does not duplicate registration',
        () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class MagicStarterLoginView {}',
      );

      createHostFile(
        'lib/app/providers/app_service_provider.dart',
        '''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    // existing boot code
  }
}
''',
      );

      // First publish.
      await command.runWith([
        '--tag=views:auth.login',
        '--force',
      ]);

      // Second publish (with force to re-copy file).
      await command.runWith([
        '--tag=views:auth.login',
        '--force',
      ]);

      final content =
          readHostFile('lib/app/providers/app_service_provider.dart');

      // Count occurrences of the registration line.
      final regPattern = RegExp(
        RegExp.escape(
          "MagicStarter.view.register('auth.login', () => const MagicStarterLoginView());",
        ),
      );
      final matches = regPattern.allMatches(content).length;
      expect(matches, 1, reason: 'Registration should appear exactly once');

      // Count occurrences of the import line.
      final importPattern = RegExp(
        RegExp.escape(
          "import '../../resources/views/starter/views/auth/magic_starter_login_view.dart';",
        ),
      );
      final importMatches = importPattern.allMatches(content).length;
      expect(
        importMatches,
        1,
        reason: 'Import should appear exactly once',
      );
    });

    test('auto-wire skips when AppServiceProvider not found', () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class MagicStarterLoginView {}',
      );

      // Do NOT create AppServiceProvider file.

      await command.runWith([
        '--tag=views:auth.login',
      ]);

      // Verify the view was still published.
      expect(
        hostFileExists(
          'lib/resources/views/starter/views/auth/magic_starter_login_view.dart',
        ),
        isTrue,
      );

      // AppServiceProvider should not exist.
      expect(
        hostFileExists('lib/app/providers/app_service_provider.dart'),
        isFalse,
      );
    });

    test('auto-wires multiple view registrations for module scope', () async {
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_login_view.dart',
        'class MagicStarterLoginView {}',
      );
      createPluginFile(
        'lib/src/ui/views/auth/magic_starter_register_view.dart',
        'class MagicStarterRegisterView {}',
      );

      createHostFile(
        'lib/app/providers/app_service_provider.dart',
        '''
import 'package:magic/magic.dart';

class AppServiceProvider extends ServiceProvider {
  AppServiceProvider(super.app);

  @override
  Future<void> boot() async {
    // existing boot code
  }
}
''',
      );

      await command.runWith([
        '--tag=views:auth',
      ]);

      final content =
          readHostFile('lib/app/providers/app_service_provider.dart');

      expect(
        content,
        contains(
          "MagicStarter.view.register('auth.login', () => const MagicStarterLoginView());",
        ),
      );
      expect(
        content,
        contains(
          "MagicStarter.view.register('auth.register', () => const MagicStarterRegisterView());",
        ),
      );
    });
  });
}
