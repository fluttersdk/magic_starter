/// CLI interface for magic_starter plugin.
///
/// Exports the magic_cli package which provides the Command base class
/// and Kernel for registering and executing CLI commands.
///
/// Example:
/// ```dart
/// import 'package:magic_starter/src/cli/cli.dart';
///
/// void main(List<String> args) {
///   final kernel = Kernel()
///     ..registerMany([
///       MagicStarterInstallCommand(),
///       // other commands
///     ]);
///   kernel.handle(args);
/// }
/// ```
library;

export 'package:magic_cli/magic_cli.dart';
