import 'dart:io';

import 'package:magic_starter/src/cli/starter_artisan_provider.dart';
import 'package:test/test.dart';

void main() {
  group('MagicStarterArtisanProvider', () {
    late MagicStarterArtisanProvider provider;

    setUp(() {
      provider = MagicStarterArtisanProvider();
    });

    // -------------------------------------------------------------------------
    // mcpTools curation
    // -------------------------------------------------------------------------

    group('mcpTools', () {
      test('exposes exactly one tool named starter_doctor', () {
        final tools = provider.mcpTools();

        expect(tools, hasLength(1));
        expect(tools.first.name, equals('starter_doctor'));
      });

      test('starter_doctor tool routes to the artisan dispatcher', () {
        final tool = provider.mcpTools().first;

        expect(tool.extensionMethod, equals('artisan:starter:doctor'));
      });

      test('starter_doctor tool has a non-empty description', () {
        final tool = provider.mcpTools().first;

        expect(tool.description, isNotEmpty);
      });

      test('does not expose any mutating command as an MCP tool', () {
        final names = provider.mcpTools().map((t) => t.name).toSet();

        // install, configure, publish, uninstall must never appear.
        expect(names, isNot(contains('starter_install')));
        expect(names, isNot(contains('starter_configure')));
        expect(names, isNot(contains('starter_publish')));
        expect(names, isNot(contains('starter_uninstall')));
      });

      test('tool descriptor has a valid inputSchema', () {
        final tool = provider.mcpTools().first;

        expect(tool.inputSchema, isA<Map<String, dynamic>>());
        expect(tool.inputSchema['type'], equals('object'));
      });
    });
  });

  group('magicStarterVersion', () {
    test('matches the version pubspec.yaml declares', () {
      // The two `starter:*` banners used to carry a hand-written '0.0.1' and
      // were still printing it twenty-four alpha releases later. A literal
      // nothing compares against drifts silently, so the constant they now read
      // is pinned to the one place a release actually changes.
      final pubspec = File(
        '${Directory.current.path}/pubspec.yaml',
      ).readAsStringSync();
      final declared = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(declared, isNotNull, reason: 'pubspec.yaml declares a version');
      expect(magicStarterVersion, declared!.group(1));
    });
  });
}
