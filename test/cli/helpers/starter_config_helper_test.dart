import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/src/cli/helpers/starter_config_helper.dart';

void main() {
  group(
    'StarterConfigHelper',
    () {
      group(
        'parseFeatures',
        () {
          test(
            'extracts teams feature from config content',
            () {
              const content = """
Map<String, dynamic> get magicStarterConfig => {
      'magic_starter': {
        'features': {
          'teams': true,
          'registration': false,
        },
      },
    };
""";
              final features = StarterConfigHelper.parseFeatures(content);
              expect(features['teams'], true);
              expect(features['registration'], false);
            },
          );

          test(
            'extracts all 12 feature toggles',
            () {
              const content = """
Map<String, dynamic> get magicStarterConfig => {
      'magic_starter': {
        'features': {
          'teams': true,
          'registration': false,
          'extended_profile': true,
          'profile_photos': false,
          'social_login': true,
          'two_factor': false,
          'sessions': true,
          'phone_otp': false,
          'newsletter': true,
          'notifications': false,
          'email_verification': true,
          'guest_auth': false,
        },
      },
    };
""";
              final features = StarterConfigHelper.parseFeatures(content);
              expect(features['teams'], true);
              expect(features['registration'], false);
              expect(features['extended_profile'], true);
              expect(features['profile_photos'], false);
              expect(features['social_login'], true);
              expect(features['two_factor'], false);
              expect(features['sessions'], true);
              expect(features['phone_otp'], false);
              expect(features['newsletter'], true);
              expect(features['notifications'], false);
              expect(features['email_verification'], true);
              expect(features['guest_auth'], false);
            },
          );

          test(
            'returns empty map if no features found',
            () {
              const content = "// No features here";
              final features = StarterConfigHelper.parseFeatures(content);
              expect(features, isEmpty);
            },
          );
        },
      );

      group(
        'updateFeature',
        () {
          test(
            'toggles teams from false to true',
            () {
              const content = """
Map<String, dynamic> get magicStarterConfig => {
      'magic_starter': {
        'features': {
          'teams': false,
          'registration': true,
        },
      },
    };
""";
              final updated = StarterConfigHelper.updateFeature(
                content,
                'teams',
                true,
              );
              final features = StarterConfigHelper.parseFeatures(updated);
              expect(features['teams'], true);
              expect(features['registration'], true);
            },
          );

          test(
            'toggles feature from true to false',
            () {
              const content = """
Map<String, dynamic> get magicStarterConfig => {
      'magic_starter': {
        'features': {
          'social_login': true,
          'registration': true,
        },
      },
    };
""";
              final updated = StarterConfigHelper.updateFeature(
                content,
                'social_login',
                false,
              );
              final features = StarterConfigHelper.parseFeatures(updated);
              expect(features['social_login'], false);
              expect(features['registration'], true);
            },
          );

          test(
            'is idempotent when setting same value',
            () {
              const content = """
Map<String, dynamic> get magicStarterConfig => {
      'magic_starter': {
        'features': {
          'teams': true,
          'registration': false,
        },
      },
    };
""";
              final updated1 = StarterConfigHelper.updateFeature(
                content,
                'teams',
                true,
              );
              final updated2 = StarterConfigHelper.updateFeature(
                updated1,
                'teams',
                true,
              );
              expect(updated1, updated2);
            },
          );

          test(
            'preserves whitespace and other features',
            () {
              const content = """
Map<String, dynamic> get magicStarterConfig => {
      'magic_starter': {
        'features': {
          'teams': false,
          'registration': true,
          'two_factor': false,
        },
      },
    };
""";
              final updated = StarterConfigHelper.updateFeature(
                content,
                'teams',
                true,
              );
              final features = StarterConfigHelper.parseFeatures(updated);
              expect(features['teams'], true);
              expect(features['registration'], true);
              expect(features['two_factor'], false);
            },
          );
        },
      );

      group(
        'readConfigContent',
        () {
          test(
            'reads config file from lib/config/magic_starter.dart',
            () async {
              final tempDir = Directory.systemTemp.createTempSync();
              try {
                // Create lib/config directory
                final configDir = Directory('${tempDir.path}/lib/config');
                await configDir.create(recursive: true);

                // Create config file
                final configFile = File('${configDir.path}/magic_starter.dart');
                await configFile.writeAsString(
                    "Map<String, dynamic> get magicStarterConfig => {'magic_starter': {'features': {'teams': true}}};");

                final content = StarterConfigHelper.readConfigContent(
                  tempDir.path,
                );
                expect(content, isNotNull);
                expect(content!.contains('teams'), true);
              } finally {
                tempDir.deleteSync(recursive: true);
              }
            },
          );

          test(
            'returns null if config file does not exist',
            () {
              final tempDir = Directory.systemTemp.createTempSync();
              try {
                final content = StarterConfigHelper.readConfigContent(
                  tempDir.path,
                );
                expect(content, isNull);
              } finally {
                tempDir.deleteSync(recursive: true);
              }
            },
          );
        },
      );

      group(
        'configExists',
        () {
          test(
            'returns true if config file exists',
            () async {
              final tempDir = Directory.systemTemp.createTempSync();
              try {
                final configDir = Directory('${tempDir.path}/lib/config');
                await configDir.create(recursive: true);

                final configFile = File('${configDir.path}/magic_starter.dart');
                await configFile.writeAsString('// config');

                final exists = StarterConfigHelper.configExists(tempDir.path);
                expect(exists, true);
              } finally {
                tempDir.deleteSync(recursive: true);
              }
            },
          );

          test(
            'returns false if config file does not exist',
            () {
              final tempDir = Directory.systemTemp.createTempSync();
              try {
                final exists = StarterConfigHelper.configExists(tempDir.path);
                expect(exists, false);
              } finally {
                tempDir.deleteSync(recursive: true);
              }
            },
          );
        },
      );

      group(
        'resolvePluginSourceDir',
        () {
          test(
            'parses package_config.json and returns magic_starter root',
            () async {
              final tempDir = Directory.systemTemp.createTempSync();
              try {
                // Create .dart_tool/package_config.json
                final dartToolDir = Directory('${tempDir.path}/.dart_tool');
                await dartToolDir.create(recursive: true);

                final packageConfigFile = File(
                  '${dartToolDir.path}/package_config.json',
                );
                final magicStarterRoot =
                    Directory('${tempDir.path}/plugins/magic_starter');
                await magicStarterRoot.create(recursive: true);

                await packageConfigFile.writeAsString(
                  '''{
                  "configVersion": 2,
                  "packages": [
                    {
                      "name": "magic_starter",
                      "rootUri": "file://${magicStarterRoot.path}",
                      "packageUri": "lib/"
                    }
                  ]
                }''',
                );

                final result = StarterConfigHelper.resolvePluginSourceDir(
                  projectRoot: tempDir.path,
                );
                expect(result, isNotNull);
                expect(
                  result!.endsWith('plugins/magic_starter') ||
                      result.endsWith(
                          'plugins${Platform.pathSeparator}magic_starter'),
                  true,
                );
              } finally {
                tempDir.deleteSync(recursive: true);
              }
            },
          );

          test(
            'returns null if package_config.json does not exist',
            () {
              final tempDir = Directory.systemTemp.createTempSync();
              try {
                final result = StarterConfigHelper.resolvePluginSourceDir(
                  projectRoot: tempDir.path,
                );
                expect(result, isNull);
              } finally {
                tempDir.deleteSync(recursive: true);
              }
            },
          );

          test(
            'returns null if magic_starter package not found in config',
            () async {
              final tempDir = Directory.systemTemp.createTempSync();
              try {
                final dartToolDir = Directory('${tempDir.path}/.dart_tool');
                await dartToolDir.create(recursive: true);

                final packageConfigFile = File(
                  '${dartToolDir.path}/package_config.json',
                );
                await packageConfigFile.writeAsString(
                  '''{
                  "configVersion": 2,
                  "packages": [
                    {
                      "name": "some_other_package",
                      "rootUri": "file:///some/path",
                      "packageUri": "lib/"
                    }
                  ]
                }''',
                );

                final result = StarterConfigHelper.resolvePluginSourceDir(
                  projectRoot: tempDir.path,
                );
                expect(result, isNull);
              } finally {
                tempDir.deleteSync(recursive: true);
              }
            },
          );
        },
      );
    },
  );
}
