import 'dart:io';

import 'package:magic_starter/src/cli/commands/magic_starter_uninstall_command.dart';
import 'package:test/test.dart';

class TestMagicStarterUninstallCommand extends MagicStarterUninstallCommand {
  TestMagicStarterUninstallCommand(this._projectRoot);

  final String _projectRoot;

  bool didRunDartFormat = false;
  int confirmCalls = 0;

  @override
  String getProjectRoot() => _projectRoot;

  @override
  bool confirm(
    String question, {
    bool? defaultValue,
  }) {
    confirmCalls++;
    return false;
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
}

void main() {
  group('MagicStarterUninstallCommand', () {
    late Directory tempDir;
    late TestMagicStarterUninstallCommand command;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('magic_starter_uninstall_');
      command = TestMagicStarterUninstallCommand(tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('name is uninstall', () {
      expect(command.name, 'uninstall');
    });

    test('deletes lib/config/magic_starter.dart', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      final File configFile =
          File('${tempDir.path}/lib/config/magic_starter.dart');
      expect(configFile.existsSync(), isFalse);
    });

    test('removes MagicStarterServiceProvider line from app.dart', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      final String appContent =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();

      expect(appContent, isNot(contains('MagicStarterServiceProvider')));
    });

    test('removes magic_starter import from app.dart', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      final String appContent =
          File('${tempDir.path}/lib/config/app.dart').readAsStringSync();

      expect(
        appContent,
        isNot(contains("import 'package:magic_starter/magic_starter.dart';")),
      );
    });

    test('removes magicStarterConfig factory from main.dart', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      final String mainContent =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();

      expect(mainContent, isNot(contains('() => magicStarterConfig,')));
    });

    test('removes magic_starter config import from main.dart', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      final String mainContent =
          File('${tempDir.path}/lib/main.dart').readAsStringSync();

      expect(
        mainContent,
        isNot(contains("import 'config/magic_starter.dart';")),
      );
    });

    test('removes middleware aliases from kernel.dart', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      final String kernelContent =
          File('${tempDir.path}/lib/app/kernel.dart').readAsStringSync();

      expect(kernelContent, isNot(contains('EnsureAuthenticated')));
      expect(kernelContent, isNot(contains('RedirectIfAuthenticated')));
      expect(
        kernelContent,
        isNot(contains("import 'middleware/ensure_authenticated.dart';")),
      );
      expect(
        kernelContent,
        isNot(contains("import 'middleware/redirect_if_authenticated.dart';")),
      );
    });

    test('removes route registrations from route_service_provider.dart',
        () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      final String content =
          File('${tempDir.path}/lib/app/providers/route_service_provider.dart')
              .readAsStringSync();

      expect(content, isNot(contains('registerMagicStarterAuthRoutes();')));
      expect(content, isNot(contains('registerMagicStarterProfileRoutes();')));
      expect(content, isNot(contains('registerMagicMagicStarterTeamRoutes();')));
      expect(
        content,
        isNot(contains('registerMagicStarterNotificationRoutes();')),
      );
      expect(
        content,
        isNot(contains("import 'package:magic_starter/magic_starter.dart';")),
      );
    });

    test('--force skips confirmation prompt', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      expect(command.confirmCalls, 0);
      expect(
        File('${tempDir.path}/lib/config/magic_starter.dart').existsSync(),
        isFalse,
      );
    });

    test('handles missing config file gracefully (no crash)', () async {
      setupInstalledProject(tempDir);
      File('${tempDir.path}/lib/config/magic_starter.dart').deleteSync();

      await command.runWith([
        '--force',
      ]);

      expect(true, isTrue);
    });

    test('handles already-clean app.dart gracefully (no crash)', () async {
      setupInstalledProject(tempDir);

      _writeFile(
        tempDir,
        'lib/config/app.dart',
        '''
import 'package:magic/magic.dart';

Map<String, dynamic> get appConfig => {
  'app': {
    'providers': [
      (app) => RouteServiceProvider(app),
    ],
  },
};
''',
      );

      await command.runWith([
        '--force',
      ]);

      expect(true, isTrue);
    });

    test('runs dart format after uninstall', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      expect(command.didRunDartFormat, isTrue);
    });

    test('removes magic_starter dependency from pubspec.yaml', () async {
      setupInstalledProject(tempDir);

      await command.runWith([
        '--force',
      ]);

      final String pubspecContent =
          File('${tempDir.path}/pubspec.yaml').readAsStringSync();

      expect(pubspecContent, isNot(contains('magic_starter:')));
    });
  });
}

void setupInstalledProject(Directory dir) {
  _writeFile(
    dir,
    'pubspec.yaml',
    '''
name: test_app
description: Test host app
dependencies:
  flutter:
    sdk: flutter
  magic:
    path: ../magic
  magic_starter:
    path: ../magic_starter
''',
  );

  _writeFile(
    dir,
    'lib/config/magic_starter.dart',
    'Map<String, dynamic> get magicStarterConfig => {};',
  );

  _writeFile(
    dir,
    'lib/config/app.dart',
    '''
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

Map<String, dynamic> get appConfig => {
  'app': {
    'providers': [
      (app) => MagicStarterServiceProvider(app),
      (app) => RouteServiceProvider(app),
    ],
  },
};
''',
  );

  _writeFile(
    dir,
    'lib/main.dart',
    '''
import 'package:flutter/material.dart';
import 'package:magic/magic.dart';
import 'config/app.dart';
import 'config/magic_starter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Magic.init(
    configFactories: [
      () => appConfig,
      () => magicStarterConfig,
    ],
  );
}
''',
  );

  _writeFile(
    dir,
    'lib/app/kernel.dart',
    '''
import 'package:magic/magic.dart';
import 'middleware/ensure_authenticated.dart';
import 'middleware/redirect_if_authenticated.dart';

void registerKernel() {
  Kernel.registerAll({
    'auth': () => EnsureAuthenticated(),
    'guest': () => RedirectIfAuthenticated(),
  });
}
''',
  );

  _writeFile(
    dir,
    'lib/app/providers/route_service_provider.dart',
    '''
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

class RouteServiceProvider extends ServiceProvider {
  RouteServiceProvider(super.app);

  @override
  Future<void> boot() async {
    registerMagicStarterAuthRoutes();
    registerMagicStarterProfileRoutes();
    registerMagicMagicStarterTeamRoutes();
    registerMagicStarterNotificationRoutes();
    registerAppRoutes();
  }
}
''',
  );
}

void _writeFile(
  Directory root,
  String relativePath,
  String content,
) {
  final File file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
