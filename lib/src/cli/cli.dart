/// CLI interface for magic_starter plugin.
///
/// Exports the magic_cli package which provides the Command base class
/// and Kernel for registering and executing CLI commands. Also exports
/// all magic_starter CLI commands.
///
/// Example:
/// ```dart
/// import 'package:magic_starter/src/cli/cli.dart';
///
/// void main(List<String> args) {
///   final kernel = Kernel()
///     ..registerMany([
///       InstallCommand(),
///       PublishCommand(),
///       ConfigureCommand(),
///       DoctorCommand(),
///       UninstallCommand(),
///     ]);
///   kernel.handle(args);
/// }
/// ```
library;

export 'package:magic_cli/magic_cli.dart' hide InstallCommand;
export 'commands/install_command.dart';
export 'commands/publish_command.dart';
export 'commands/configure_command.dart';
export 'commands/doctor_command.dart';
export 'commands/uninstall_command.dart';
export 'helpers/starter_config_helper.dart';
