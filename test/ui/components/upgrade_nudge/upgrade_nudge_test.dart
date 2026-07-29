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

  testWidgets('the lock glyph colour token actually resolves', (tester) async {
    // Guards the whole class of defect that shipped here once: this component
    // arrived referencing `text-ai` / `bg-ai-soft`, tokens defined only in one
    // consumer's hand-authored supplement. Wind CLAIMS a `text-<name>` token and
    // then resolves an unknown name to nothing, so the class is dropped
    // silently and the glyph simply inherits the default foreground. Asserting
    // the colour is non-null does not catch it (the inherited value is not
    // null), and neither does any assertion on the className string. The only
    // signature is that a dropped token renders IDENTICALLY to no colour token
    // at all, so this compares against that control.
    //
    // Depends on the recipe's `tile` slot carrying no text colour of its own: if
    // one is added there, the glyph inherits it, the control no longer matches
    // the unstyled baseline, and this comparison goes vacuous WITHOUT failing.
    // `shared_recipe_token_contract_test.dart` is the backstop that stays valid
    // either way.
    await tester
        .pumpWidget(wrap(const WIcon(Icons.lock, className: 'text-lg')));
    final Color? uncoloured = tester.widget<Icon>(find.byType(Icon)).color;

    await tester.pumpWidget(
      wrap(
        const MSUpgradeNudge(
          message: 'AI analysis is gated.',
          requiredPlan: 'Pro',
        ),
      ),
    );
    final Color? glyph = tester
        .widget<Icon>(
          find.descendant(
            of: find.byType(MSUpgradeNudge),
            matching: find.byType(Icon),
          ),
        )
        .color;

    expect(glyph, isNotNull);
    expect(
      glyph,
      isNot(uncoloured),
      reason: 'the lock glyph colour token resolved to nothing, so it renders '
          'the same as an icon with no colour class',
    );
  });

  group('upgradeNudgeRecipe', () {
    test('neutral banner fill plus a themed lock tile', () {
      final slots = upgradeNudgeRecipe(variants: const {});
      expect(slots['root'], contains('bg-surface-container'));
      expect(slots['root'], contains('rounded-xl'));
      // Must be a token the starter's own theme guarantees: an ai-* token
      // is a consumer supplement, and Wind drops an unknown token silently,
      // so the tile would render with no background in every other app.
      expect(slots['tile'], contains('bg-primary-container'));
      expect(slots['tile'], isNot(contains('ai-soft')));
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
