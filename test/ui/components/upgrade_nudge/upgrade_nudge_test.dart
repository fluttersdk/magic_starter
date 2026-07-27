import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/components/upgrade_nudge/index.dart';
import 'package:magic_starter/src/ui/components/upgrade_nudge/upgrade_nudge.preview.dart';

/// Feeds the upsell copy so [trans] returns real English prose instead of the
/// raw key tokens.
class _UpgradeLangLoader implements TranslationLoader {
  @override
  Future<Map<String, dynamic>> load(Locale locale) async => {
    'common.upgrade_available_on': 'Available on :plan and up.',
    'common.upgrade': 'Upgrade',
  };
}

void main() {
  setUp(() async {
    Translator.instance.setLoader(_UpgradeLangLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  Widget wrap(Widget widget) => MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );

  group('upgradeNudgeRecipe', () {
    test('neutral banner fill + ai-soft lock tile', () {
      final slots = upgradeNudgeRecipe(variants: const {});
      expect(slots['root'], contains('bg-surface-container'));
      expect(slots['root'], contains('rounded-xl'));
      expect(slots['tile'], contains('bg-ai-soft'));
    });
  });

  testWidgets('renders message + plan line + Upgrade button', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSUpgradeNudge(
          message: "You've reached your 3-responder limit.",
          requiredPlan: 'Business',
        ),
      ),
    );
    expect(find.text("You've reached your 3-responder limit."), findsOneWidget);
    expect(find.text('Available on Business and up.'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
  });

  testWidgets('compact hides the Upgrade button', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSUpgradeNudge(
          message: '10-second checks need a faster plan.',
          requiredPlan: 'Business',
          compact: true,
        ),
      ),
    );
    expect(find.text('Upgrade'), findsNothing);
  });

  testWidgets('preview renders without error', (tester) async {
    await tester.pumpWidget(wrap(const UpgradeNudgePreview()));
    expect(find.byType(MSUpgradeNudge), findsNWidgets(3));
  });
}
