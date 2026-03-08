import 'package:magic_cli/magic_cli.dart';

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
/// dart run magic_starter configure --show
/// dart run magic_starter configure --teams --no-social-login
/// ```
class MagicStarterConfigureCommand extends Command {
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
  final String name = 'configure';

  @override
  final String description = 'Update Magic Starter configuration';

  /// Absolute path to the Flutter project root, resolved on access.
  String get projectRoot => getProjectRoot();

  /// Resolve the Flutter project root — may be overridden in tests.
  String getProjectRoot() => FileHelper.findProjectRoot();

  /// Absolute path to the magic_starter config file.
  String get _configPath => '$projectRoot/lib/config/magic_starter.dart';

  @override
  void configure(ArgParser parser) {
    parser.addFlag(
      'show',
      negatable: false,
      help: 'Display current feature configuration',
    );

    for (final flag in _featureFlags.keys) {
      parser.addFlag(
        flag,
        // defaultsTo: null — flag is not touched when omitted.
        defaultsTo: null,
        help: 'Enable or disable the ${flag.replaceAll('-', '_')} feature',
      );
    }
  }

  @override
  Future<void> handle() async {
    // 1. Attempt to read config — bail early if missing.
    final String? content =
        MagicStarterConfigHelper.readConfigContent(projectRoot);
    if (content == null) {
      error('Configuration file not found: $_configPath');
      info('Run installation first: dart run magic_starter install');
      return;
    }

    // 2. --show: display table of current features and exit.
    if (arguments['show'] as bool) {
      _showConfig(content);
      return;
    }

    // 3. Collect requested updates — only flags explicitly provided.
    final Map<String, bool> updates = _collectUpdates();

    if (updates.isEmpty) {
      warn('No configuration updates specified.');
      info('Use --help to see available options.');
      info('Use --show to view current configuration.');
      return;
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

    success('Configuration updated successfully.');
  }

  /// Collects all feature flag updates that were explicitly parsed.
  ///
  /// Returns a map of config key → bool for every flag the user supplied.
  /// Flags not provided (defaultsTo: null) are omitted so they remain
  /// untouched in the config file.
  Map<String, bool> _collectUpdates() {
    final updates = <String, bool>{};

    for (final entry in _featureFlags.entries) {
      final String flag = entry.key;
      final String configKey = entry.value;

      // argResults[flag] is null when the flag was not provided.
      final dynamic value = arguments[flag];
      if (value != null) {
        updates[configKey] = value as bool;
      }
    }

    return updates;
  }

  /// Prints a formatted table of the current feature toggles.
  ///
  /// Parses [content] via [MagicStarterConfigHelper.parseFeatures] and delegates
  /// display to the base [Command.table] helper.
  void _showConfig(String content) {
    final Map<String, bool> features =
        MagicStarterConfigHelper.parseFeatures(content);

    info('Current Magic Starter Feature Configuration:\n');

    final List<List<String>> rows = features.entries
        .map(
          (entry) => [
            entry.key,
            entry.value ? 'enabled' : 'disabled',
          ],
        )
        .toList();

    table(
      [
        'Feature',
        'Status',
      ],
      rows,
    );
  }
}
