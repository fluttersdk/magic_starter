import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterTeamSettingsSectionRegistry', () {
    late MagicStarterTeamSettingsSectionRegistry registry;

    setUp(() {
      registry = MagicStarterTeamSettingsSectionRegistry();
    });

    // -------------------------------------------------------------------------
    // registerSection()
    // -------------------------------------------------------------------------

    group('registerSection()', () {
      test('stores section and sections getter returns it', () {
        registry.registerSection(
          key: 'billing',
          order: 10,
          builder: (_, __) => const SizedBox(),
        );

        final sections = registry.sections;

        expect(sections, hasLength(1));
        expect(sections.first.key, 'billing');
        expect(sections.first.order, 10);
      });

      test('replaces previous entry when key already exists', () {
        const first = SizedBox(key: Key('first'));
        const second = SizedBox(key: Key('second'));

        registry.registerSection(
          key: 'billing',
          order: 10,
          builder: (_, __) => first,
        );

        registry.registerSection(
          key: 'billing',
          order: 20,
          builder: (_, __) => second,
        );

        final sections = registry.sections;

        expect(sections, hasLength(1));
        expect(sections.first.order, 20);

        final widget = sections.first.builder(_MockBuildContext(), null);
        expect(widget, same(second));
      });
    });

    // -------------------------------------------------------------------------
    // sections (sorted)
    // -------------------------------------------------------------------------

    group('sections', () {
      test('returns sections sorted by order ascending', () {
        registry.registerSection(
          key: 'integrations',
          order: 20,
          builder: (_, __) => const SizedBox(),
        );

        registry.registerSection(
          key: 'billing',
          order: 10,
          builder: (_, __) => const SizedBox(),
        );

        final sections = registry.sections;

        expect(sections, hasLength(2));
        expect(sections[0].key, 'billing');
        expect(sections[1].key, 'integrations');
      });

      test('stable sort — equal order preserves insertion order', () {
        registry.registerSection(
          key: 'alpha',
          order: 10,
          builder: (_, __) => const SizedBox(),
        );

        registry.registerSection(
          key: 'beta',
          order: 10,
          builder: (_, __) => const SizedBox(),
        );

        final sections = registry.sections;

        expect(sections, hasLength(2));
        expect(sections[0].key, 'alpha');
        expect(sections[1].key, 'beta');
      });

      test('returns empty list when no sections registered', () {
        expect(registry.sections, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // removeSection()
    // -------------------------------------------------------------------------

    group('removeSection()', () {
      test('removes section by key', () {
        registry.registerSection(
          key: 'billing',
          order: 10,
          builder: (_, __) => const SizedBox(),
        );

        registry.removeSection('billing');

        expect(registry.sections, isEmpty);
      });

      test('no-op when key does not exist', () {
        // Should not throw.
        registry.removeSection('non-existent');

        expect(registry.sections, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // clear()
    // -------------------------------------------------------------------------

    group('clear()', () {
      test('removes all registered sections', () {
        registry.registerSection(
          key: 'billing',
          order: 10,
          builder: (_, __) => const SizedBox(),
        );

        registry.registerSection(
          key: 'integrations',
          order: 20,
          builder: (_, __) => const SizedBox(),
        );

        registry.clear();

        expect(registry.sections, isEmpty);
      });
    });
  });
}

/// Minimal [BuildContext] stub for builder callback invocation.
class _MockBuildContext extends Fake implements BuildContext {}
