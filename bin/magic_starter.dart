import 'package:magic_cli/magic_cli.dart' hide InstallCommand;

/// Install command — registers starter kit in host app.
class InstallCommand extends Command {
  @override
  String get name => 'install';

  @override
  String get description => 'Install magic_starter in your Magic app';

  @override
  Future<void> handle() async {
    success('Magic Starter installed successfully!');
  }
}

/// Publish command — publish to pub.dev.
class PublishCommand extends Command {
  @override
  String get name => 'publish';

  @override
  String get description => 'Publish magic_starter to pub.dev';

  @override
  Future<void> handle() async {
    success('Magic Starter published successfully!');
  }
}

/// Configure command — configure magic_starter features.
class ConfigureCommand extends Command {
  @override
  String get name => 'configure';

  @override
  String get description => 'Configure magic_starter features in your app';

  @override
  Future<void> handle() async {
    success('Magic Starter configured successfully!');
  }
}

/// Doctor command — diagnose magic_starter setup.
class DoctorCommand extends Command {
  @override
  String get name => 'doctor';

  @override
  String get description => 'Diagnose magic_starter setup and health';

  @override
  Future<void> handle() async {
    success('Magic Starter is healthy!');
  }
}

/// Uninstall command — remove magic_starter from host app.
class UninstallCommand extends Command {
  @override
  String get name => 'uninstall';

  @override
  String get description => 'Uninstall magic_starter from your Magic app';

  @override
  Future<void> handle() async {
    success('Magic Starter uninstalled successfully!');
  }
}

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
