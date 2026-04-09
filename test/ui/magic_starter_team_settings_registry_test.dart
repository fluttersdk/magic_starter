import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  late MagicStarterTeamSettingsRegistry registry;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    registry = MagicStarterTeamSettingsRegistry();
  });

  group('MagicStarterTeamSettingsRegistry', () {
    test('registerSection adds a section that buildSections returns', () {
      registry.registerSection(
        key: 'billing',
        order: 10,
        builder: (context, team) => const SizedBox(),
      );

      final widgets = registry.buildSections(_FakeBuildContext(), null);

      expect(widgets, hasLength(1));
      expect(widgets.first, isA<SizedBox>());
    });

    test('sections sorted by order ascending', () {
      registry.registerSection(
        key: 'second',
        order: 20,
        builder: (context, team) => const SizedBox(width: 20),
      );
      registry.registerSection(
        key: 'first',
        order: 10,
        builder: (context, team) => const SizedBox(width: 10),
      );

      final widgets = registry.buildSections(_FakeBuildContext(), null);

      expect(widgets, hasLength(2));
      expect((widgets[0] as SizedBox).width, 10);
      expect((widgets[1] as SizedBox).width, 20);
    });

    test('duplicate key replaces previous section', () {
      registry.registerSection(
        key: 'billing',
        order: 10,
        builder: (context, team) => const SizedBox(width: 100),
      );
      registry.registerSection(
        key: 'billing',
        order: 5,
        builder: (context, team) => const SizedBox(width: 200),
      );

      final widgets = registry.buildSections(_FakeBuildContext(), null);

      expect(widgets, hasLength(1));
      expect((widgets.first as SizedBox).width, 200);
    });

    test('removeSection removes a registered section', () {
      registry.registerSection(
        key: 'billing',
        order: 10,
        builder: (context, team) => const SizedBox(),
      );

      registry.removeSection('billing');

      final widgets = registry.buildSections(_FakeBuildContext(), null);

      expect(widgets, isEmpty);
    });

    test('removeSection on non-existent key does not throw', () {
      expect(() => registry.removeSection('nonexistent'), returnsNormally);
    });

    test('buildSections returns empty list when no sections registered', () {
      final widgets = registry.buildSections(_FakeBuildContext(), null);

      expect(widgets, isEmpty);
    });

    test('buildSections passes correct team argument to builder', () {
      MagicStarterTeam? receivedTeam;

      registry.registerSection(
        key: 'test',
        order: 1,
        builder: (context, team) {
          receivedTeam = team;
          return const SizedBox();
        },
      );

      final team = MagicStarterTeam(id: 42, name: 'Acme');

      registry.buildSections(_FakeBuildContext(), team);

      expect(receivedTeam, isNotNull);
      expect(receivedTeam!.id, 42);
      expect(receivedTeam!.name, 'Acme');
    });
  });

  group('Manager integration', () {
    test('MagicStarter.teamSettings.registerSection works through facade', () {
      MagicStarter.teamSettings.registerSection(
        key: 'integrations',
        order: 5,
        builder: (context, team) => const SizedBox(),
      );

      final widgets = MagicStarter.teamSettings.buildSections(
        _FakeBuildContext(),
        null,
      );

      expect(widgets, hasLength(1));
    });

    test('MagicStarterManager.reset clears registered sections', () {
      MagicStarter.teamSettings.registerSection(
        key: 'billing',
        order: 10,
        builder: (context, team) => const SizedBox(),
      );

      MagicStarter.manager.reset();

      final widgets = MagicStarter.teamSettings.buildSections(
        _FakeBuildContext(),
        null,
      );

      expect(widgets, isEmpty);
    });
  });
}

/// Minimal fake [BuildContext] for unit tests that don't need widget tree.
class _FakeBuildContext extends Fake implements BuildContext {}
