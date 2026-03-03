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
        hostFileExists('lib/resources/views/starter/auth/magic_starter_login_view.dart'),
        isTrue,
      );
      expect(
        hostFileExists(
            'lib/resources/views/starter/profile/settings_view.dart'),
        isTrue,
      );
      expect(
        readHostFile('lib/resources/views/starter/auth/magic_starter_login_view.dart'),
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
  });
}
