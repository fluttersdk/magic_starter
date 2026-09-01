import 'package:fluttersdk_artisan/artisan.dart';

import 'commands/magic_starter_configure_command.dart';
import 'commands/magic_starter_doctor_command.dart';
import 'commands/magic_starter_install_command.dart';
import 'commands/magic_starter_publish_command.dart';
import 'commands/magic_starter_uninstall_command.dart';

/// Version the `starter:*` command banners print.
///
/// Mirrors the `version` field of this package's `pubspec.yaml`, which stays the
/// release's single source of truth. `starter_artisan_provider_test.dart` reads
/// both and fails when they disagree, so a banner cannot drift behind a release
/// the way the two hand-written `'0.0.1'` literals did: they were written before
/// the first alpha and were still claiming 0.0.1 twenty-four releases later.
const String magicStarterVersion = '0.0.1-alpha.24';

/// Magic Starter's contribution to the host application's artisan registry.
///
/// Host apps register this provider in their `appConfig['artisan']['providers']`
/// list so that `artisan starter:install`, `starter:configure`,
/// `starter:doctor`, `starter:publish`, and `starter:uninstall` become
/// discoverable through the unified `artisan` binary.
class MagicStarterArtisanProvider extends ArtisanServiceProvider {
  @override
  String get providerName => 'magic_starter';

  @override
  List<ArtisanCommand> commands() => <ArtisanCommand>[
    MagicStarterInstallCommand(),
    MagicStarterPublishCommand(),
    MagicStarterConfigureCommand(),
    MagicStarterDoctorCommand(),
    MagicStarterUninstallCommand(),
  ];

  @override
  List<McpToolDescriptor> mcpTools() => const <McpToolDescriptor>[
    McpToolDescriptor(
      name: 'starter_doctor',
      description:
          'Check Magic Starter installation health in the '
          'running Flutter project. '
          'Reports pass or fail for each setup requirement: Magic '
          'Framework config, Starter config file, service provider '
          'registration, config factory wiring, middleware, auth routes, '
          'facade setup, and translation file. '
          'Usage: call with no arguments for a summary report, or pass '
          '`verbose: true` to include the inspected file path for each '
          'check.',
      inputSchema: <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'verbose': <String, dynamic>{
            'type': 'boolean',
            'description':
                'Show file paths and detailed information for '
                'each check. Defaults to false.',
          },
        },
        'additionalProperties': false,
      },
      extensionMethod: 'artisan:starter:doctor',
    ),
  ];
}
