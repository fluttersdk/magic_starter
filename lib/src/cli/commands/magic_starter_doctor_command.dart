import 'dart:io';

import 'package:magic_cli/magic_cli.dart';

/// Diagnostic health-check command for Magic Starter installations.
///
/// Runs a series of checks across the host application to verify that
/// Magic Starter was installed correctly. Each check is independent and
/// reports ✓ (pass) or ✗ (fail). The command exits with code 0 when all
/// checks pass, and code 1 when any check fails.
///
/// ## Usage
/// ```bash
/// dart run magic_starter doctor
/// dart run magic_starter doctor --verbose
/// ```
class MagicStarterDoctorCommand extends Command {
  @override
  String get name => 'doctor';

  @override
  String get description => 'Check Magic Starter installation health';

  /// Absolute path to the Flutter project root — resolved on access.
  String get projectRoot => getProjectRoot();

  /// Resolve the Flutter project root.
  ///
  /// Overridable in tests to supply an arbitrary temp directory.
  String getProjectRoot() => FileHelper.findProjectRoot();

  @override
  void configure(ArgParser parser) {
    parser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show file paths and detailed information for each check.',
    );
  }

  @override
  Future<void> handle() async {
    // 1. Resolve verbosity before running checks.
    final bool verbose = arguments['verbose'] as bool;

    // 2. Print human-readable report.
    stdout.write(generateReport(verbose: verbose));

    // 3. Collect missing requirements and exit with appropriate code.
    final List<String> missing = getMissingRequirements();

    if (missing.isEmpty) {
      success('All checks passed!');
      newLine();
      exit(0);
    } else {
      newLine();
      error(
          '${missing.length} check(s) failed. Run `dart run magic_starter install` to fix.');
      exit(1);
    }
  }

  // -------------------------------------------------------------------------
  // Individual health checks
  // -------------------------------------------------------------------------

  /// Check that the Magic Framework config exists (`lib/config/app.dart`).
  ///
  /// A missing `app.dart` indicates Magic was not installed before running
  /// `magic_starter install`.
  bool checkMagicInstalled(String root) {
    return FileHelper.fileExists('$root/lib/config/app.dart');
  }

  /// Check that the Magic Starter config file was generated.
  ///
  /// Looks for `lib/config/magic_starter.dart` — created by `install`.
  bool checkConfigExists(String root) {
    return FileHelper.fileExists('$root/lib/config/magic_starter.dart');
  }

  /// Check that [MagicStarterServiceProvider] is registered in `app.dart`.
  ///
  /// Returns `false` when `app.dart` is absent or does not contain the
  /// provider registration string.
  bool checkProviderRegistered(String root) {
    final String appPath = '$root/lib/config/app.dart';

    if (!FileHelper.fileExists(appPath)) {
      return false;
    }

    return File(appPath)
        .readAsStringSync()
        .contains('MagicStarterServiceProvider');
  }

  /// Check that the `magicStarterConfig` factory is wired into `main.dart`.
  ///
  /// Returns `false` when `main.dart` is absent or does not call the factory.
  bool checkConfigFactory(String root) {
    final String mainPath = '$root/lib/main.dart';

    if (!FileHelper.fileExists(mainPath)) {
      return false;
    }

    return File(mainPath).readAsStringSync().contains('magicStarterConfig');
  }

  /// Check that the `EnsureAuthenticated` middleware is registered in `kernel.dart`.
  ///
  /// Returns `false` when `kernel.dart` is absent or does not contain the alias.
  bool checkMiddleware(String root) {
    final String kernelPath = '$root/lib/app/kernel.dart';

    if (!FileHelper.fileExists(kernelPath)) {
      return false;
    }

    return File(kernelPath).readAsStringSync().contains('EnsureAuthenticated');
  }

  /// Check that the starter auth routes are registered in `route_service_provider.dart`.
  ///
  /// Returns `false` when the file is absent or does not call the registration
  /// function.
  bool checkRoutes(String root) {
    final String providerPath =
        '$root/lib/app/providers/route_service_provider.dart';

    if (!FileHelper.fileExists(providerPath)) {
      return false;
    }

    return File(providerPath)
        .readAsStringSync()
        .contains('registerMagicStarterAuthRoutes');
  }

  /// Check that `MagicStarter.useNavigation` is configured in `app_service_provider.dart`.
  ///
  /// Returns `false` when the file is absent or does not contain the facade setup.
  bool checkFacadeSetup(String root) {
    final String providerPath =
        '$root/lib/app/providers/app_service_provider.dart';

    if (!FileHelper.fileExists(providerPath)) {
      return false;
    }

    return File(providerPath)
        .readAsStringSync()
        .contains('MagicStarter.useNavigation');
  }

  /// Check that the translation file `assets/lang/en.json` exists.
  ///
  /// Returns `false` when the file is absent.
  bool checkTranslations(String root) {
    return FileHelper.fileExists('$root/assets/lang/en.json');
  }

  /// Scan `lib/resources/views/starter/` for published view `.dart` files.
  ///
  /// Returns a list of relative file paths (relative to [root]) for every
  /// `.dart` file found in the published views directory. Returns an empty
  /// list when the directory does not exist or contains no Dart files.
  List<String> getPublishedViews(String root) {
    final dir = Directory('$root/lib/resources/views/starter');

    if (!dir.existsSync()) {
      return [];
    }

    final files = <String>[];

    for (final entry in dir.listSync(recursive: true)) {
      if (entry is File && entry.path.endsWith('.dart')) {
        files.add(entry.path.substring(root.length + 1));
      }
    }

    files.sort();

    return files;
  }

  /// Check whether a published view file has a corresponding
  /// `MagicStarter.view.register()` call in `app_service_provider.dart`.
  ///
  /// [viewRelativePath] is relative to [root] (e.g.,
  /// `lib/resources/views/starter/auth/magic_starter_login_view.dart`).
  ///
  /// Returns `true` when the registration is found or when the provider file
  /// does not exist (cannot verify — treat as wired to avoid false positives).
  bool isPublishedViewWired(String root, String viewRelativePath) {
    final providerPath = '$root/lib/app/providers/app_service_provider.dart';

    if (!FileHelper.fileExists(providerPath)) {
      return true;
    }

    final fileName = viewRelativePath.split('/').last;
    final content = File(providerPath).readAsStringSync();

    return content.contains(fileName.replaceAll('.dart', ''));
  }

  // -------------------------------------------------------------------------
  // Report
  // -------------------------------------------------------------------------

  /// Return a list of human-readable failure messages for every failed check.
  ///
  /// An empty list means the installation is healthy.
  List<String> getMissingRequirements() {
    final String root = projectRoot;
    final List<String> missing = [];

    if (!checkMagicInstalled(root)) {
      missing.add('Magic Framework not detected (lib/config/app.dart missing)');
    }

    if (!checkConfigExists(root)) {
      missing
          .add('Starter config file not found (lib/config/magic_starter.dart)');
    }

    if (!checkProviderRegistered(root)) {
      missing.add(
          'MagicStarterServiceProvider not registered in lib/config/app.dart');
    }

    if (!checkConfigFactory(root)) {
      missing.add('magicStarterConfig factory not wired in lib/main.dart');
    }

    if (!checkMiddleware(root)) {
      missing.add(
          'EnsureAuthenticated middleware not registered in lib/app/kernel.dart');
    }

    if (!checkRoutes(root)) {
      missing.add(
        'registerMagicStarterAuthRoutes() not called in route_service_provider.dart',
      );
    }

    if (!checkFacadeSetup(root)) {
      missing.add(
          'MagicStarter facade not configured in app_service_provider.dart');
    }

    if (!checkTranslations(root)) {
      missing.add('Translation file not found (assets/lang/en.json)');
    }

    return missing;
  }

  /// Generate a human-readable diagnostic report.
  ///
  /// When [verbose] is `true`, each check line includes the file path that
  /// was inspected. Returns a formatted string with ✓/✗ per check and a
  /// summary section at the bottom.
  String generateReport({bool verbose = false}) {
    final String root = projectRoot;
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('Magic Starter — Doctor Report');
    buffer.writeln('=' * 50);
    buffer.writeln();

    // 1. Magic Framework.
    final bool magicInstalled = checkMagicInstalled(root);
    buffer.writeln('Magic Framework: ${magicInstalled ? '✓' : '✗'}');
    if (verbose) {
      buffer.writeln('    Path: lib/config/app.dart');
    }

    // 2. Starter config file.
    final bool configExists = checkConfigExists(root);
    buffer.writeln('Starter Config: ${configExists ? '✓' : '✗'}');
    if (verbose) {
      buffer.writeln('    Path: lib/config/magic_starter.dart');
    }

    // 3. Service provider registration.
    final bool providerRegistered = checkProviderRegistered(root);
    buffer.writeln('Provider: ${providerRegistered ? '✓' : '✗'}');
    if (verbose) {
      buffer.writeln('    File: lib/config/app.dart');
      buffer.writeln('    Contains: MagicStarterServiceProvider');
    }

    // 4. Config factory in main.
    final bool configFactory = checkConfigFactory(root);
    buffer.writeln('Config Factory: ${configFactory ? '✓' : '✗'}');
    if (verbose) {
      buffer.writeln('    File: lib/main.dart');
      buffer.writeln('    Contains: magicStarterConfig');
    }

    // 5. Middleware.
    final bool middleware = checkMiddleware(root);
    buffer.writeln('Middleware: ${middleware ? '✓' : '✗'}');
    if (verbose) {
      buffer.writeln('    File: lib/app/kernel.dart');
      buffer.writeln('    Contains: EnsureAuthenticated');
    }

    // 6. Auth routes.
    final bool routes = checkRoutes(root);
    buffer.writeln('Routes: ${routes ? '✓' : '✗'}');
    if (verbose) {
      buffer.writeln('    File: lib/app/providers/route_service_provider.dart');
      buffer.writeln('    Contains: registerMagicStarterAuthRoutes');
    }

    // 7. Facade setup.
    final bool facadeSetup = checkFacadeSetup(root);
    buffer.writeln('Facade: ${facadeSetup ? '✓' : '✗'}');
    if (verbose) {
      buffer.writeln('    File: lib/app/providers/app_service_provider.dart');
      buffer.writeln('    Contains: MagicStarter.useUserModel');
    }

    // 8. Translation file.
    final bool translations = checkTranslations(root);
    buffer.writeln('Translations: ${translations ? '✓' : '✗'}');
    if (verbose) {
      buffer.writeln('    Path: assets/lang/en.json');
    }

    // 9. Published views section.
    final List<String> publishedViews = getPublishedViews(root);
    if (publishedViews.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Published Views:');
      for (final String viewPath in publishedViews) {
        final bool wired = isPublishedViewWired(root, viewPath);
        buffer.writeln('  ${wired ? '✓' : '⚠'} $viewPath');
        if (!wired) {
          buffer.writeln(
            '      Not wired: add MagicStarter.view.register() in AppServiceProvider',
          );
        }
      }
    }

    buffer.writeln();

    // 10. Summary section.
    final List<String> missing = getMissingRequirements();
    if (missing.isEmpty) {
      buffer.writeln('✓ All requirements met!');
    } else {
      buffer.writeln('Missing Requirements:');
      for (final String issue in missing) {
        buffer.writeln('  ✗ $issue');
      }
    }

    return buffer.toString();
  }
}
