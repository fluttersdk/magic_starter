import 'package:magic_starter/src/cli/starter_artisan_provider.dart';
import 'package:test/test.dart';

void main() {
  group('StarterArtisanProvider', () {
    late StarterArtisanProvider provider;

    setUp(() {
      provider = StarterArtisanProvider();
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
}
