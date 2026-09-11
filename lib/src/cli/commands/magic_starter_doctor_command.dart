import 'dart:io';

import 'package:fluttersdk_artisan/artisan.dart';
import 'package:path/path.dart' as p;

/// Where the push external id prefix a report names came from.
///
/// Three states rather than a "was it declared" flag, because a key written as
/// `''` and a key nobody wrote resolve to the same prefix and need different
/// sentences: an adopter chasing a mismatch who is told the key is not set
/// goes and writes the key they already wrote, and never learns that the value
/// they wrote is the one being ignored.
enum PushPrefixSource {
  /// The key carries a usable value, and that value is the prefix.
  declared,

  /// The key is present and blank, so the default applies and what was written
  /// is discarded.
  blank,

  /// No key at all, so the default applies.
  absent,
}

/// Diagnostic health-check command for Magic Starter installations.
///
/// Runs a series of checks across the host application to verify that
/// Magic Starter was installed correctly. Each check is independent and
/// reports a pass or fail marker. The command returns exit code 0 when all
/// checks pass, and code 1 when any check fails.
///
/// ## Usage
/// ```bash
/// artisan starter:doctor
/// artisan starter:doctor --verbose
/// ```
class MagicStarterDoctorCommand extends ArtisanCommand {
  @override
  String get signature =>
      'starter:doctor '
      '{--verbose : Show file paths and detailed information for each check}';

  @override
  String get description => 'Check Magic Starter installation health';

  @override
  CommandBoot get boot => CommandBoot.none;

  /// Absolute path to the Flutter project root — resolved on access.
  String get projectRoot => getProjectRoot();

  /// Resolve the Flutter project root.
  ///
  /// Overridable in tests to supply an arbitrary temp directory.
  String getProjectRoot() => FileHelper.findProjectRoot();

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Resolve verbosity before running checks.
    final bool verbose = (ctx.input.option('verbose') as bool?) ?? false;

    // 2. Print human-readable report.
    ctx.output.writeln(generateReport(verbose: verbose));

    // 3. Collect missing requirements and return appropriate exit code.
    final List<String> missing = getMissingRequirements();

    if (missing.isEmpty) {
      ctx.output.success('All checks passed!');
      ctx.output.writeln('');
      return 0;
    }

    ctx.output.writeln('');
    ctx.output.error(
      '${missing.length} check(s) failed. Run `artisan starter:install` to fix.',
    );
    return 1;
  }

  // -------------------------------------------------------------------------
  // Individual health checks
  // -------------------------------------------------------------------------

  /// Check that the Magic Framework config exists (`lib/config/app.dart`).
  ///
  /// A missing `app.dart` indicates Magic was not installed before running
  /// `starter:install`.
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

    return File(
      appPath,
    ).readAsStringSync().contains('MagicStarterServiceProvider');
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

    return File(
      providerPath,
    ).readAsStringSync().contains('registerMagicStarterAuthRoutes');
  }

  /// Check that the identity contract is configured in
  /// `app_service_provider.dart`.
  ///
  /// Probes for `MagicStarter.bootstrap(`, the single required call. An app
  /// installed before that existed wired the same four values through the
  /// individual setters, which still work, so `MagicStarter.useUserModel(` is
  /// accepted as the legacy shape rather than reported as a failure: the check
  /// answers "is the starter configured at all", and a false FAIL on a working
  /// app is worse than no check.
  ///
  /// Returns `false` when the file is absent or contains neither shape.
  bool checkFacadeSetup(String root) {
    final String providerPath =
        '$root/lib/app/providers/app_service_provider.dart';

    if (!FileHelper.fileExists(providerPath)) {
      return false;
    }

    final String content = File(providerPath).readAsStringSync();

    // The same call set, and the same anchoring, as the installer's idempotency
    // guard. Keeping them identical matters: if this probe were narrower, an app
    // the installer refuses to touch would be reported FAIL alongside advice to
    // run the installer, which would then do nothing.
    return RegExp(
      r'^\s*MagicStarter\.(bootstrap|useUserModel|useLocaleOptions|useLogout)\(',
      multiLine: true,
    ).hasMatch(content);
  }

  /// Check that the translation file `assets/lang/en.json` exists.
  ///
  /// Returns `false` when the file is absent.
  bool checkTranslations(String root) {
    return FileHelper.fileExists('$root/assets/lang/en.json');
  }

  /// Check that an app with billing enabled configured
  /// `magic_starter.billing.web_origin`.
  ///
  /// The failure this catches is silent, which is why it earns a check of its
  /// own. The billing view builds Stripe's `successUrl`, `cancelUrl` and the
  /// portal `returnUrl` by concatenating that origin with a path, and Stripe
  /// requires absolute urls. A missing origin produces a relative one, session
  /// creation fails at Stripe, and the resulting `BillingException` is logged
  /// rather than surfaced, so an adopter who enabled billing and forgot the key
  /// sees a checkout button that does nothing and no reason why.
  ///
  /// Returns `true` when the config file is absent (a missing config is already
  /// reported by [checkConfigExists], and reporting it twice would send an
  /// adopter to fix billing when the install never ran) and when the billing
  /// feature is off. Otherwise it requires a non-empty `web_origin`.
  bool checkBillingWebOrigin(String root) {
    final String configPath = '$root/lib/config/magic_starter.dart';

    if (!FileHelper.fileExists(configPath)) {
      return true;
    }

    final String content = File(configPath).readAsStringSync();
    final bool billingEnabled = RegExp(
      r"'billing'\s*:\s*true",
    ).hasMatch(content);

    if (!billingEnabled) {
      return true;
    }

    return RegExp(r"""'web_origin'\s*:\s*['"][^'"]+['"]""").hasMatch(content);
  }

  /// The push external id prefix this app's config resolves to, and where it
  /// came from.
  ///
  /// Returns `null` when the config file is absent or the notifications feature
  /// is off, which is the signal to print nothing: an app that sends no push
  /// has no side to agree with.
  ///
  /// The reason this is reported rather than checked: four sites compose one
  /// external id and a mismatch between them is accepted by OneSignal and
  /// delivered to nobody. Three are in `magic-starter-laravel` and one is here,
  /// and nothing can verify the two repositories agree from inside either one.
  /// So this prints the client's answer for a human to read against
  /// `config/magic-starter.php`, and never fails: any prefix is valid as long
  /// as the backend uses the same one.
  ///
  /// Read TEXTUALLY from `lib/config/magic_starter.dart`, because this command
  /// boots nothing (`CommandBoot.none`) and there is no container to ask. That
  /// covers where every scaffolded app sets the key and misses an app that
  /// writes it at runtime through `Config.set`.
  ///
  /// Resolution mirrors `MagicStarterConfig.pushExternalIdPrefix`: the value is
  /// trimmed, and a blank one resolves to `user_` rather than to no prefix,
  /// since OneSignal rejects a bare numeric external id outright.
  ({String prefix, PushPrefixSource source})? pushExternalIdPrefix(
    String root,
  ) {
    final String configPath = '$root/lib/config/magic_starter.dart';

    if (!FileHelper.fileExists(configPath)) {
      return null;
    }

    final String content = _withoutCommentedLines(
      File(configPath).readAsStringSync(),
    );

    // Matches the feature flag and not the `'notifications': {` block that
    // carries the key itself, which is followed by a brace rather than `true`.
    if (!RegExp(r"'notifications'\s*:\s*true").hasMatch(content)) {
      return null;
    }

    final RegExpMatch? match = RegExp(
      """'external_id_prefix'\\s*:\\s*['"]([^'"]*)['"]""",
    ).firstMatch(content);

    if (match == null) {
      return (
        prefix: _defaultPushExternalIdPrefix,
        source: PushPrefixSource.absent,
      );
    }

    final String raw = match.group(1)!.trim();

    if (raw.isEmpty) {
      return (
        prefix: _defaultPushExternalIdPrefix,
        source: PushPrefixSource.blank,
      );
    }

    return (prefix: raw, source: PushPrefixSource.declared);
  }

  /// [content] with every whole-line `//` comment removed.
  ///
  /// A prefix change tends to leave the old line commented out above the new
  /// one, and the match below takes the first hit in the file, so without this
  /// the report would name a prefix the app stopped sending and say nothing
  /// about it.
  ///
  /// Only a line that is nothing BUT a comment goes, which is the shape a
  /// commented-out key has. A trailing comment on a live line stays, and it
  /// cannot swallow anything, since the key it would hide is already matched
  /// earlier on the same line. Stripping from every `//` instead would cut a
  /// url in half, `'https://app.example.com'` being the neighbouring value.
  ///
  /// A block comment around the key is not covered, and neither is a key
  /// written outside the `'notifications'` block.
  String _withoutCommentedLines(String content) {
    return content
        .split('\n')
        .where((String line) => !line.trimLeft().startsWith('//'))
        .join('\n');
  }

  /// Mirrors `MagicStarterConfig`'s own default, which cannot be read from here
  /// because that constant is private and this command loads no config.
  static const String _defaultPushExternalIdPrefix = 'user_';

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
        files.add(p.relative(entry.path, from: root));
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

    final fileName = p.basename(viewRelativePath);
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
      missing.add(
        'Starter config file not found (lib/config/magic_starter.dart)',
      );
    }

    if (!checkProviderRegistered(root)) {
      missing.add(
        'MagicStarterServiceProvider not registered in lib/config/app.dart',
      );
    }

    if (!checkConfigFactory(root)) {
      missing.add('magicStarterConfig factory not wired in lib/main.dart');
    }

    if (!checkMiddleware(root)) {
      missing.add(
        'EnsureAuthenticated middleware not registered in lib/app/kernel.dart',
      );
    }

    if (!checkRoutes(root)) {
      missing.add(
        'registerMagicStarterAuthRoutes() not called in route_service_provider.dart',
      );
    }

    if (!checkFacadeSetup(root)) {
      missing.add(
        'MagicStarter facade not configured in app_service_provider.dart',
      );
    }

    if (!checkTranslations(root)) {
      missing.add('Translation file not found (assets/lang/en.json)');
    }

    if (!checkBillingWebOrigin(root)) {
      missing.add(
        'Billing is enabled but magic_starter.billing.web_origin is not set. '
        'Stripe checkout and the billing portal need an absolute url; without '
        'it the session fails at Stripe and the error is only logged.',
      );
    }

    return missing;
  }

  /// Generate a human-readable diagnostic report.
  ///
  /// When [verbose] is `true`, each check line includes the file path that
  /// was inspected. Returns a formatted string with pass/fail markers per
  /// check and a summary section at the bottom.
  String generateReport({bool verbose = false}) {
    final String root = projectRoot;
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('Magic Starter — Doctor Report');
    buffer.writeln('=' * 50);
    buffer.writeln();

    // 1. Magic Framework.
    final bool magicInstalled = checkMagicInstalled(root);
    buffer.writeln('Magic Framework: ${magicInstalled ? 'OK' : 'FAIL'}');
    if (verbose) {
      buffer.writeln('    Path: lib/config/app.dart');
    }

    // 2. Starter config file.
    final bool configExists = checkConfigExists(root);
    buffer.writeln('Starter Config: ${configExists ? 'OK' : 'FAIL'}');
    if (verbose) {
      buffer.writeln('    Path: lib/config/magic_starter.dart');
    }

    // 3. Service provider registration.
    final bool providerRegistered = checkProviderRegistered(root);
    buffer.writeln('Provider: ${providerRegistered ? 'OK' : 'FAIL'}');
    if (verbose) {
      buffer.writeln('    File: lib/config/app.dart');
      buffer.writeln('    Contains: MagicStarterServiceProvider');
    }

    // 4. Config factory in main.
    final bool configFactory = checkConfigFactory(root);
    buffer.writeln('Config Factory: ${configFactory ? 'OK' : 'FAIL'}');
    if (verbose) {
      buffer.writeln('    File: lib/main.dart');
      buffer.writeln('    Contains: magicStarterConfig');
    }

    // 5. Middleware.
    final bool middleware = checkMiddleware(root);
    buffer.writeln('Middleware: ${middleware ? 'OK' : 'FAIL'}');
    if (verbose) {
      buffer.writeln('    File: lib/app/kernel.dart');
      buffer.writeln('    Contains: EnsureAuthenticated');
    }

    // 6. Auth routes.
    final bool routes = checkRoutes(root);
    buffer.writeln('Routes: ${routes ? 'OK' : 'FAIL'}');
    if (verbose) {
      buffer.writeln('    File: lib/app/providers/route_service_provider.dart');
      buffer.writeln('    Contains: registerMagicStarterAuthRoutes');
    }

    // 7. Facade setup.
    final bool facadeSetup = checkFacadeSetup(root);
    buffer.writeln('Facade: ${facadeSetup ? 'OK' : 'FAIL'}');
    if (verbose) {
      buffer.writeln('    File: lib/app/providers/app_service_provider.dart');
      buffer.writeln(
        '    Contains: MagicStarter.bootstrap( '
        '(or a legacy MagicStarter.use* identity setter)',
      );
    }

    // 8. Translation file.
    final bool translations = checkTranslations(root);
    buffer.writeln('Translations: ${translations ? 'OK' : 'FAIL'}');
    if (verbose) {
      buffer.writeln('    Path: assets/lang/en.json');
    }

    // 9. Billing origin, reported only when billing is on: an app that does not
    //    sell anything has no reason to read a line about Stripe.
    final bool billingOrigin = checkBillingWebOrigin(root);
    if (!billingOrigin) {
      buffer.writeln('Billing web origin: FAIL');
      if (verbose) {
        buffer.writeln('    Key: magic_starter.billing.web_origin');
        buffer.writeln(
          '    Needed: an absolute url, since Stripe rejects a relative '
          'successUrl / cancelUrl / returnUrl',
        );
      }
    }

    // 10. Push external id prefix, reported rather than checked: any value is
    //     valid, and the only thing that can be wrong about it lives in the
    //     other repository.
    final prefix = pushExternalIdPrefix(root);
    if (prefix != null) {
      final String origin = switch (prefix.source) {
        PushPrefixSource.declared => '',
        PushPrefixSource.blank => ' (blank, using default)',
        PushPrefixSource.absent => ' (default, key not set)',
      };
      buffer.writeln('Push external id prefix: ${prefix.prefix}$origin');
      if (verbose) {
        buffer.writeln(
          '    Key: magic_starter.notifications.external_id_prefix',
        );
        buffer.writeln(
          '    Backend must match: config/magic-starter.php -> '
          'onesignal.external_id_prefix',
        );
        buffer.writeln(
          '    A mismatch is accepted by OneSignal and delivered to nobody',
        );
      }
    }

    // 11. Published views section.
    final List<String> publishedViews = getPublishedViews(root);
    if (publishedViews.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Published Views:');
      for (final String viewPath in publishedViews) {
        final bool wired = isPublishedViewWired(root, viewPath);
        buffer.writeln('  ${wired ? 'OK' : 'WARN'} $viewPath');
        if (!wired) {
          buffer.writeln(
            '      Not wired: add MagicStarter.view.register() in AppServiceProvider',
          );
        }
      }
    }

    buffer.writeln();

    // 12. Summary section.
    final List<String> missing = getMissingRequirements();
    if (missing.isEmpty) {
      buffer.writeln('All requirements met!');
    } else {
      buffer.writeln('Missing Requirements:');
      for (final String issue in missing) {
        buffer.writeln('  FAIL $issue');
      }
    }

    return buffer.toString();
  }
}
