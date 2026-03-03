import 'package:magic_cli/magic_cli.dart' hide InstallCommand;
import 'package:magic_starter/src/cli/commands/magic_starter_install_command.dart';
import 'package:magic_starter/src/cli/commands/magic_starter_publish_command.dart';
import 'package:magic_starter/src/cli/commands/magic_starter_configure_command.dart';
import 'package:magic_starter/src/cli/commands/magic_starter_doctor_command.dart';
import 'package:magic_starter/src/cli/commands/magic_starter_uninstall_command.dart';

/// Magic Starter CLI entry point.
void main(List<String> args) async {
  final kernel = Kernel();

  // 1. Register all starter commands.
  kernel.registerMany([
    MagicStarterInstallCommand(),
    MagicStarterPublishCommand(),
    MagicStarterConfigureCommand(),
    MagicStarterDoctorCommand(),
    MagicStarterUninstallCommand(),
  ]);

  // 2. Execute requested command.
  await kernel.handle(args);
}
