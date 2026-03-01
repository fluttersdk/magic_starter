import 'package:magic_cli/magic_cli.dart' hide InstallCommand;
import 'package:magic_starter/src/cli/commands/install_command.dart';
import 'package:magic_starter/src/cli/commands/publish_command.dart';
import 'package:magic_starter/src/cli/commands/configure_command.dart';
import 'package:magic_starter/src/cli/commands/doctor_command.dart';
import 'package:magic_starter/src/cli/commands/uninstall_command.dart';

/// Magic Starter CLI entry point.
void main(List<String> args) async {
  final kernel = Kernel();

  // 1. Register all starter commands.
  kernel.registerMany([
    InstallCommand(),
    PublishCommand(),
    ConfigureCommand(),
    DoctorCommand(),
    UninstallCommand(),
  ]);

  // 2. Execute requested command.
  await kernel.handle(args);
}
