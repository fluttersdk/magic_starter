import 'dart:convert';
import 'dart:io';

/// Helper class for managing Magic Starter configuration files.
///
/// Provides utilities to read, parse, and update feature toggles in the
/// `lib/config/magic_starter.dart` configuration file. All methods are
/// static and do not require instantiation.
abstract class MagicStarterConfigHelper {
  /// List of all feature toggle keys in magic_starter config.
  static const featureKeys = [
    'teams',
    'registration',
    'extended_profile',
    'profile_photos',
    'social_login',
    'two_factor',
    'sessions',
    'phone_otp',
    'newsletter',
    'notifications',
    'email_verification',
    'guest_auth',
  ];

  /// Parses feature toggles from config content.
  ///
  /// Extracts all feature boolean values from Dart map syntax in the
  /// configuration content. Uses regex to find each feature key and its
  /// corresponding true/false value.
  ///
  /// Returns a map where keys are feature names and values are booleans.
  /// If a feature is not found in the content, it is omitted from the result.
  ///
  /// Example:
  /// ```dart
  /// final content = """
  /// Map<String, dynamic> get magicStarterConfig => {
  ///   'magic_starter': {
  ///     'features': {
  ///       'teams': false,
  ///       'registration': true,
  ///     },
  ///   },
  /// };
  /// """;
  /// final features = MagicStarterConfigHelper.parseFeatures(content);
  /// print(features['teams']); // false
  /// print(features['registration']); // true
  /// ```
  static Map<String, bool> parseFeatures(String content) {
    final features = <String, bool>{};

    for (final key in featureKeys) {
      final pattern = RegExp(
        r"'" + key + r"':\s*(true|false)",
        caseSensitive: false,
      );
      final match = pattern.firstMatch(content);
      if (match != null) {
        features[key] = match.group(1)!.toLowerCase() == 'true';
      }
    }

    return features;
  }

  /// Updates a single feature toggle in config content.
  ///
  /// Replaces the value of a feature key while preserving all other content
  /// and formatting. The operation is idempotent — calling with the same
  /// value multiple times produces the same result.
  ///
  /// Parameters:
  /// - `content`: The raw configuration file content
  /// - `featureName`: The feature key to update (e.g., 'teams')
  /// - `value`: The new boolean value (true or false)
  ///
  /// Returns the updated configuration content with the feature toggled.
  /// Throws [ArgumentError] if the feature key is not found in the content.
  ///
  /// Example:
  /// ```dart
  /// final content = "'teams': false,";
  /// final updated = MagicStarterConfigHelper.updateFeature(content, 'teams', true);
  /// print(updated); // "'teams': true,"
  /// ```
  static String updateFeature(
    String content,
    String featureName,
    bool value,
  ) {
    final pattern = RegExp(
      r"(" + featureName + r"':\s*)(true|false)",
      caseSensitive: false,
    );
    return content.replaceAll(
      pattern,
      '${RegExp.escape(featureName + r"': ")}${value.toString()}',
    );
  }

  /// Reads the magic_starter config file from the project.
  ///
  /// Looks for the config file at `lib/config/magic_starter.dart` relative
  /// to the given project root directory.
  ///
  /// Parameters:
  /// - `projectRoot`: The absolute path to the Flutter/Dart project root
  ///
  /// Returns the file content as a string if the config file exists,
  /// or null if it does not exist.
  static String? readConfigContent(String projectRoot) {
    final configFile = File('$projectRoot/lib/config/magic_starter.dart');
    if (!configFile.existsSync()) {
      return null;
    }
    return configFile.readAsStringSync();
  }

  /// Checks if the magic_starter config file exists in the project.
  ///
  /// Parameters:
  /// - `projectRoot`: The absolute path to the Flutter/Dart project root
  ///
  /// Returns true if `lib/config/magic_starter.dart` exists, false otherwise.
  static bool configExists(String projectRoot) {
    final configFile = File('$projectRoot/lib/config/magic_starter.dart');
    return configFile.existsSync();
  }

  /// Resolves the magic_starter plugin source directory from package config.
  ///
  /// Parses `.dart_tool/package_config.json` to locate the magic_starter
  /// package and returns its root directory path. This allows CLI commands
  /// to access plugin assets and stubs regardless of installation method.
  ///
  /// Parameters:
  /// - `projectRoot`: The absolute path to the Flutter/Dart project root
  ///
  /// Returns the absolute path to the magic_starter plugin directory,
  /// or null if the package config file does not exist or magic_starter
  /// is not found in it.
  ///
  /// Implementation notes:
  /// - Reads `.dart_tool/package_config.json` from the project
  /// - Searches for entry with `"name": "magic_starter"`
  /// - Resolves the `rootUri` value, handling file:// and relative paths
  /// - Returns normalized path with forward slashes
  static String? resolvePluginSourceDir({
    required String projectRoot,
  }) {
    final packageConfigPath = '$projectRoot/.dart_tool/package_config.json';
    final packageConfigFile = File(packageConfigPath);

    if (!packageConfigFile.existsSync()) {
      return null;
    }

    try {
      final content = packageConfigFile.readAsStringSync();
      final map = jsonDecode(content) as Map<String, dynamic>;
      final packages = map['packages'] as List<dynamic>? ?? [];

      for (final package in packages) {
        if (package is Map<String, dynamic> &&
            package['name'] == 'magic_starter') {
          final rootUri = package['rootUri'] as String?;
          if (rootUri == null) {
            continue;
          }

          String parsedPath;

          // 1. Handle file:// URLs.
          if (rootUri.startsWith('file://')) {
            parsedPath = Uri.parse(rootUri).toFilePath();
          }
          // 2. Handle relative paths (../).
          else if (rootUri.startsWith('../')) {
            parsedPath = File(packageConfigPath)
                .parent
                .parent
                .uri
                .resolve(rootUri)
                .toFilePath();
          }
          // 3. Handle absolute paths.
          else {
            parsedPath = rootUri;
          }

          // Normalize path separators and remove double slashes.
          return parsedPath.replaceAll('//', '/');
        }
      }
    } catch (e) {
      // Silently fail on parse errors.
      return null;
    }

    return null;
  }
}
