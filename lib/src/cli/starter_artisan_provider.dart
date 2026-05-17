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
class StarterArtisanProvider extends ArtisanServiceProvider {
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
}
