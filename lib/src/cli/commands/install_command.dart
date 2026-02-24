import 'dart:io';
import 'dart:isolate';

/// CLI command that publishes the default Magic Starter config template.
///
/// Copies `lib/config/magic_starter.dart` from within the `magic_starter`
/// package to the host application's `lib/config/` directory. This gives the
/// host app a local configuration file it can customise without modifying the
/// plugin source.
///
/// ## How It Works
///
/// 1. Resolves the plugin's `lib/` directory via `Isolate.resolvePackageUri`.
/// 2. Reads the bundled template at `lib/config/magic_starter.dart`.
/// 3. Writes it to `<cwd>/lib/config/magic_starter.dart`.
///
/// If the destination already exists the user is prompted before overwriting.
///
/// ## Usage
///
/// ```dart
/// final command = InstallCommand();
/// await command.handle();
/// ```
class InstallCommand {
  /// The name of the command.
  static const String name = 'starter:install';

  /// A short description shown in help output.
  static const String description =
      'Publish the Magic Starter configuration file to your application';

  /// Relative path to the config template inside the package's `lib/`.
  static const String _templateRelativePath = 'config/magic_starter.dart';

  /// Destination path relative to the current working directory.
  static const String _destinationRelativePath =
      'lib/config/magic_starter.dart';

  /// Execute the install command.
  ///
  /// Resolves the plugin package root, reads the config template, and writes
  /// it to the host application's `lib/config/` directory.
  ///
  /// @throws FileSystemException When the template file cannot be found.
  Future<void> handle() async {
    // 1. Resolve the plugin's lib/ directory from its package URI.
    final Uri packageUri = Uri.parse('package:magic_starter/');
    final Uri? resolvedUri = await Isolate.resolvePackageUri(packageUri);

    if (resolvedUri == null) {
      stderr.writeln(
        '✗ Could not resolve the magic_starter package location.',
      );
      return;
    }

    // 2. Build the path to the bundled template file.
    final String packageLibPath = resolvedUri.toFilePath();
    final String templatePath = '$packageLibPath$_templateRelativePath';
    final File templateFile = File(templatePath);

    if (!templateFile.existsSync()) {
      stderr.writeln(
        '✗ Template file not found at: $templatePath',
      );
      return;
    }

    // 3. Determine the output path relative to the current working directory.
    final String destinationPath =
        '${Directory.current.path}/$_destinationRelativePath';
    final File destinationFile = File(destinationPath);

    // 4. If the file already exists, prompt the user before overwriting.
    if (destinationFile.existsSync()) {
      stdout.write(
        '⚠ File already exists at $_destinationRelativePath. '
        'Overwrite? [y/N]: ',
      );
      final String? input = stdin.readLineSync()?.trim().toLowerCase();

      if (input != 'y' && input != 'yes') {
        stdout.writeln('  Skipped — existing file was not modified.');
        return;
      }
    }

    // 5. Ensure the destination directory exists.
    final Directory destinationDir = destinationFile.parent;
    if (!destinationDir.existsSync()) {
      destinationDir.createSync(recursive: true);
    }

    // 6. Copy the template content to the destination.
    final String content = templateFile.readAsStringSync();
    destinationFile.writeAsStringSync(content);

    stdout.writeln(
      '✓ Published config to $_destinationRelativePath',
    );
  }
}
