import 'dart:io';

import 'package:magic_starter/src/cli/commands/magic_starter_install_command.dart';
import 'package:magic_starter/src/cli/helpers/magic_starter_config_helper.dart';
import 'package:test/test.dart';

/// The feature keys `MagicStarterConfig` actually reads, taken from its source.
///
/// Read from the file rather than listed here on purpose: a list would be a
/// second place to forget the key, which is the defect this suite exists to
/// catch.
Set<String> _featureKeysReadByConfig() {
  final String source = File(
    'lib/src/configuration/magic_starter_config.dart',
  ).readAsStringSync();

  return RegExp(
    r"'magic_starter\.features\.([a-z_]+)'",
  ).allMatches(source).map((RegExpMatch match) => match.group(1)!).toSet();
}

/// The feature keys a config template offers, read out of its `features` map.
///
/// Two shapes count as offering a key: a literal `true` / `false`, which is
/// what the in-package template carries, and a `{{ feature_x }}` placeholder,
/// which is what the install stub carries until the installer renders it.
Set<String> _featureKeysOfferedBy(String path) {
  final String source = File(path).readAsStringSync();
  final int start = source.indexOf("'features'");

  expect(
    start,
    greaterThanOrEqualTo(0),
    reason: '$path has no features map at all',
  );

  return RegExp(r"'([a-z_]+)':\s*(?:true|false|\{\{)")
      .allMatches(_braceBlockAfter(source, start))
      .map((RegExpMatch match) => match.group(1)!)
      .toSet();
}

/// The `{ ... }` block that opens after [from], matched by counting braces.
///
/// Counting rather than searching for the first `},`: the install stub writes
/// each value as a `{{ placeholder }}`, so every line inside its features map
/// already ends in `}},` and a first-match search stops after one entry. The
/// placeholders balance, so the count is unaffected by them.
String _braceBlockAfter(String source, int from) {
  final int open = source.indexOf('{', from);
  int depth = 0;

  for (int i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') depth--;
    if (depth == 0) return source.substring(open, i + 1);
  }

  fail('unbalanced braces after offset $from');
}

void main() {
  group('config template parity', () {
    late Set<String> read;

    setUp(() {
      read = _featureKeysReadByConfig();
    });

    test('every feature the config reads is offered by the package template', () {
      final Set<String> offered = _featureKeysOfferedBy(
        'lib/config/magic_starter.dart',
      );

      expect(
        read.difference(offered),
        isEmpty,
        reason:
            'A toggle MagicStarterConfig reads but the template never mentions '
            'is undiscoverable: an adopter has no way to learn it exists.',
      );
    });

    test('every feature the config reads is offered by the install stub', () {
      final Set<String> offered = _featureKeysOfferedBy(
        'assets/stubs/install/magic_starter_config.stub',
      );

      expect(
        read.difference(offered),
        isEmpty,
        reason:
            'The stub is what starter:install writes into a consumer project, '
            'so a key missing here is missing from every new installation.',
      );
    });

    test('every feature the config reads is toggleable by the installer', () {
      expect(
        read.difference(MagicStarterInstallCommand.dynamicFeatureKeys.toSet()),
        isEmpty,
        reason:
            'dynamicFeatureKeys drives both the interactive prompts and '
            '--features, so a key absent here cannot be enabled at install '
            'time.',
      );
    });

    test('every feature the config reads is visible to starter:configure', () {
      expect(
        read.difference(MagicStarterConfigHelper.featureKeys.toSet()),
        isEmpty,
        reason:
            'parseFeatures walks this list, so a key absent from it is invisible '
            'to `starter:configure --show` and cannot be toggled by it.',
      );
    });

    test('the two CLI feature lists are the same list', () {
      expect(
        MagicStarterInstallCommand.dynamicFeatureKeys,
        same(MagicStarterConfigHelper.featureKeys),
        reason:
            'Two lists of the same thing drift: this pair already had, by two '
            'keys, in opposite directions.',
      );
    });

    test('the templates offer no feature the config does not read', () {
      final Set<String> template = _featureKeysOfferedBy(
        'lib/config/magic_starter.dart',
      );
      final Set<String> stub = _featureKeysOfferedBy(
        'assets/stubs/install/magic_starter_config.stub',
      );

      expect(
        template.union(stub).difference(read),
        isEmpty,
        reason:
            'A toggle nothing reads is worse than no toggle: it looks like it '
            'does something.',
      );
    });
  });
}
