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
///       MagicStarterInstallCommand(),
///       MagicStarterPublishCommand(),
///       MagicStarterConfigureCommand(),
///       MagicStarterDoctorCommand(),
///       MagicStarterUninstallCommand(),
///     ]);
///   kernel.handle(args);
/// }
/// ```
library;

export 'package:magic_cli/magic_cli.dart' hide InstallCommand;
export 'commands/magic_starter_install_command.dart';
export 'commands/magic_starter_publish_command.dart';
export 'commands/magic_starter_configure_command.dart';
export 'commands/magic_starter_doctor_command.dart';
export 'commands/magic_starter_uninstall_command.dart';
export 'helpers/magic_starter_config_helper.dart';
