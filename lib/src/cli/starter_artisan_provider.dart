import 'package:fluttersdk_artisan/artisan.dart';

import 'commands/magic_starter_configure_command.dart';
import 'commands/magic_starter_doctor_command.dart';
import 'commands/magic_starter_install_command.dart';
import 'commands/magic_starter_publish_command.dart';
import 'commands/magic_starter_uninstall_command.dart';

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
          description: 'Check Magic Starter installation health in the '
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
                'description': 'Show file paths and detailed information for '
                    'each check. Defaults to false.',
              },
            },
            'additionalProperties': false,
          },
          extensionMethod: 'artisan:starter:doctor',
        ),
      ];
}
