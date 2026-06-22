import 'package:fluttersdk_artisan/artisan.dart';

import '../helpers/magic_starter_config_helper.dart';

/// CLI command for reading and updating Magic Starter feature configuration.
///
/// Reads `lib/config/magic_starter.dart` and allows toggling individual
/// feature flags without modifying any other file. All file I/O is delegated
/// through [MagicStarterConfigHelper] so tests can isolate execution by overriding
/// [getProjectRoot].
///
/// Usage:
/// ```
/// artisan starter:configure --show
/// artisan starter:configure --teams --no-social-login
/// ```
class MagicStarterConfigureCommand extends ArtisanCommand {
  /// The feature flag definitions: CLI flag name → config key name.
  ///
  /// CLI flags use kebab-case; config keys use snake_case.
  static const Map<String, String> _featureFlags = {
    'teams': 'teams',
    'social-login': 'social_login',
    'two-factor': 'two_factor',
    'sessions': 'sessions',
    'phone-otp': 'phone_otp',
    'newsletter': 'newsletter',
    'notifications': 'notifications',
    'email-verification': 'email_verification',
  };

  @override
  String get signature => 'starter:configure '
      '{--show : Display current feature configuration} '
      '{--teams : Enable or disable the teams feature} '
      '{--social-login : Enable or disable the social_login feature} '
      '{--two-factor : Enable or disable the two_factor feature} '
      '{--sessions : Enable or disable the sessions feature} '
      '{--phone-otp : Enable or disable the phone_otp feature} '
      '{--newsletter : Enable or disable the newsletter feature} '
      '{--notifications : Enable or disable the notifications feature} '
      '{--email-verification : Enable or disable the email_verification feature}';

  @override
  String get description => 'Update Magic Starter configuration';

  @override
  CommandBoot get boot => CommandBoot.none;

  /// Absolute path to the Flutter project root, resolved on access.
  String get projectRoot => getProjectRoot();

  /// Resolve the Flutter project root — may be overridden in tests.
  String getProjectRoot() => FileHelper.findProjectRoot();

  /// Absolute path to the magic_starter config file.
  String get _configPath => '$projectRoot/lib/config/magic_starter.dart';

  @override
  Future<int> handle(ArtisanContext ctx) async {
    // 1. Attempt to read config — bail early if missing.
    final String? content =
        MagicStarterConfigHelper.readConfigContent(projectRoot);
    if (content == null) {
      ctx.output.error('Configuration file not found: $_configPath');
      ctx.output.info('Run installation first: artisan starter:install');
      return 1;
    }

    // 2. --show: display table of current features and exit.
    if (ctx.input.option('show') as bool? ?? false) {
      _showConfig(ctx, content);
      return 0;
    }

    // 3. Collect requested updates — only flags explicitly provided.
    final Map<String, bool> updates = _collectUpdates(ctx);

    if (updates.isEmpty) {
      ctx.output.warning('No configuration updates specified.');
      ctx.output.info('Use --help to see available options.');
      ctx.output.info('Use --show to view current configuration.');
      return 0;
    }

    // 4. Apply each update sequentially to the content string.
    String updated = content;
    for (final entry in updates.entries) {
      updated = MagicStarterConfigHelper.updateFeature(
        updated,
        entry.key,
        entry.value,
      );
    }

    // 5. Write the updated content back to the config file.
    FileHelper.writeFile(_configPath, updated);

    ctx.output.success('Configuration updated successfully.');
    return 0;
  }

  /// Collects all feature flag updates that were explicitly parsed.
  ///
  /// Returns a map of config key → bool for every flag the user supplied.
  /// Flags the user did not pass are omitted via [ArtisanInput.hasOption]
  /// (i.e. `wasParsed`) so they remain untouched in the config file.
  Map<String, bool> _collectUpdates(ArtisanContext ctx) {
    final updates = <String, bool>{};

    for (final entry in _featureFlags.entries) {
      final String flag = entry.key;
      final String configKey = entry.value;

      if (!ctx.input.hasOption(flag)) {
        continue;
      }
      updates[configKey] = (ctx.input.option(flag) as bool?) ?? false;
    }

    return updates;
  }

  /// Prints a formatted table of the current feature toggles.
  ///
  /// Parses [content] via [MagicStarterConfigHelper.parseFeatures] and renders
  /// a simple two-column report into the output stream.
  void _showConfig(ArtisanContext ctx, String content) {
    final Map<String, bool> features =
        MagicStarterConfigHelper.parseFeatures(content);

    ctx.output.info('Current Magic Starter Feature Configuration:');
    ctx.output.writeln('');

    // 1. Compute the column width for the feature name.
    final int nameWidth = features.keys.fold<int>(
      'Feature'.length,
      (int max, String key) => key.length > max ? key.length : max,
    );

    // 2. Print header row.
    final String header = '${'Feature'.padRight(nameWidth)}  Status';
    ctx.output.writeln(header);
    ctx.output.writeln('${'-' * nameWidth}  ${'-' * 'Status'.length}');

    // 3. Print one row per feature.
    for (final entry in features.entries) {
      final String status = entry.value ? 'enabled' : 'disabled';
      ctx.output.writeln('${entry.key.padRight(nameWidth)}  $status');
    }
  }
}
