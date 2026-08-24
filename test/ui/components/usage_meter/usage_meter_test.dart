import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// Top-level so it tears off as a compile-time constant, letting the widget
/// instantiations below stay `const`.
String toStringFormatter(int value) => value.toString();

/// Reads the resolved fill colour off the single `Container` nested under the
/// meter's `FractionallySizedBox` (the bar). A dropped/unknown colour token
/// renders a `Container` with no decoration at all, which this helper
/// surfaces as `null` rather than throwing, so callers can assert on it.
Color? fillColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(Container),
    ),
  );
  final decoration = container.decoration;
  if (decoration is! BoxDecoration) return null;
  return decoration.color;
}

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  // The QA this step exists for is "the fill is visible using only what the
  // package ships, with no consumer supplement anywhere". That is
  // `MagicStarterTokens.defaultAliases`, the package's own "stable contract"
  // (see `magic_starter_tokens.dart`), not an empty theme: an empty alias map
  // would fail every semantic-alias-keyed recipe in this package, including
  // `badge.recipe.dart`, which this component's tokens now match.
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(aliases: MagicStarterTokens.defaultAliases),
        child: Scaffold(body: widget),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recipe token contract (mirrors badge.recipe.dart's own tone tokens)
  // ---------------------------------------------------------------------------

  group('usageMeterRecipe', () {
    test('success tone emits the bg-success alias key', () {
      final slots = usageMeterRecipe(
        variants: {kUsageMeterToneAxis: 'success'},
      );
      expect(slots['bar'], contains('bg-success'));
    });

    test('warning tone emits the bg-warning alias key', () {
      final slots = usageMeterRecipe(
        variants: {kUsageMeterToneAxis: 'warning'},
      );
      expect(slots['bar'], contains('bg-warning'));
    });

    test('destructive tone emits the bg-destructive alias key', () {
      final slots = usageMeterRecipe(
        variants: {kUsageMeterToneAxis: 'destructive'},
      );
      expect(slots['bar'], contains('bg-destructive'));
    });

    test(
      'every colour token is one MagicStarterTokens.defaultAliases guarantees',
      () {
        const guaranteedColourTokens = {
          'text-fg',
          'text-fg-muted',
          'bg-surface-container-high',
          'bg-success',
          'bg-warning',
          'bg-destructive',
        };
        // `text-sm` / `text-xs` are font-size utilities, not colour tokens; a
        // bare `text-` prefix is not enough to tell the two apart.
        const nonColourTextUtilities = {'text-sm', 'text-xs'};

        for (final tone in ['success', 'warning', 'destructive']) {
          final slots = usageMeterRecipe(variants: {kUsageMeterToneAxis: tone});
          for (final className in slots.values) {
            for (final token in className.split(' ')) {
              if (!token.startsWith('bg-') && !token.startsWith('text-')) {
                continue;
              }
              if (nonColourTextUtilities.contains(token)) {
                continue;
              }
              expect(
                guaranteedColourTokens.contains(token),
                isTrue,
                reason:
                    '"$token" is not a key MagicStarterTokens.defaultAliases '
                    'guarantees, so it renders no colour in every app that has '
                    'not hand-authored it',
              );
            }
          }
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // QA: the fill must be visible using only what the package ships (its own
  // default alias map), no consumer supplement anywhere. A dropped/unknown
  // token renders a perfectly laid-out widget with no background, so only
  // checking the label passes against exactly the bug this guards.
  // ---------------------------------------------------------------------------

  testWidgets(
    'the fill is visible with only MagicStarterTokens.defaultAliases wired, '
    'no consumer supplement',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const MSUsageMeter(
            label: 'Monitors',
            used: 4,
            limit: 50,
            formatNumber: toStringFormatter,
          ),
        ),
      );

      final color = fillColor(tester);
      expect(
        color,
        isNotNull,
        reason: 'the fill colour token resolved to nothing',
      );
      expect(
        color,
        isNot(Colors.transparent),
        reason:
            'the fill colour token resolved to transparent, same as no '
            'colour at all',
      );
    },
  );

  // ---------------------------------------------------------------------------
  // A null limit
  // ---------------------------------------------------------------------------

  testWidgets(
    'a null limit renders the used count without a denominator and does '
    'not divide by null or by zero',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          const MSUsageMeter(
            label: 'Monitors',
            used: 420,
            limit: null,
            formatNumber: toStringFormatter,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('420 / ∞'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // Over-quota
  // ---------------------------------------------------------------------------

  testWidgets('used greater than limit does not overflow the bar or throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MSUsageMeter(
          label: 'Alerts',
          used: 120,
          limit: 100,
          formatNumber: toStringFormatter,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final fractionallySizedBox = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(
      fractionallySizedBox.widthFactor,
      1.0,
      reason:
          'an over-quota ratio must be capped at 1.0, not overflow the '
          'track',
    );
    expect(find.text('120 / 100'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // A zero (or negative) limit: the DEFAULT state for a plan that includes
  // none of the resource, not an edge case. `0 / 0` is NaN in Dart, and a NaN
  // widthFactor fails FractionallySizedBox's own assert; a non-positive limit
  // must never reach that division.
  // ---------------------------------------------------------------------------

  group('a non-positive limit', () {
    testWidgets(
      'used: 0, limit: 0 renders as fully consumed at the destructive tone, '
      'not NaN',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const MSUsageMeter(
              label: 'Responders',
              used: 0,
              limit: 0,
              formatNumber: toStringFormatter,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final fractionallySizedBox = tester.widget<FractionallySizedBox>(
          find.byType(FractionallySizedBox),
        );
        expect(
          fractionallySizedBox.widthFactor,
          1.0,
          reason: '0 / 0 must resolve to fully consumed, not NaN',
        );
        expect(find.text('0 / 0'), findsOneWidget);

        final zeroLimitColor = fillColor(tester);

        // Prove the tone is genuinely destructive (not merely "some colour")
        // by comparing against an explicit over-quota meter's fill.
        await tester.pumpWidget(
          wrap(
            const MSUsageMeter(
              label: 'Responders',
              used: 120,
              limit: 100,
              formatNumber: toStringFormatter,
            ),
          ),
        );
        final overQuotaColor = fillColor(tester);

        expect(
          zeroLimitColor,
          overQuotaColor,
          reason:
              'a zero limit must render at the same at-limit tone as an '
              'explicit over-quota meter',
        );
      },
    );

    testWidgets('used: 4, limit: 0 also renders as fully consumed, not NaN', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const MSUsageMeter(
            label: 'Responders',
            used: 4,
            limit: 0,
            formatNumber: toStringFormatter,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final fractionallySizedBox = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fractionallySizedBox.widthFactor, 1.0);
      expect(find.text('4 / 0'), findsOneWidget);
    });

    testWidgets('a negative limit does not reach the division either', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const MSUsageMeter(
            label: 'Responders',
            used: 4,
            limit: -5,
            formatNumber: toStringFormatter,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final fractionallySizedBox = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fractionallySizedBox.widthFactor, 1.0);
      expect(find.text('4 / -5'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // formatNumber is actually wired, not merely accepted
  // ---------------------------------------------------------------------------

  testWidgets('formatNumber is called for the rendered numbers', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        MSUsageMeter(
          label: 'Monitors',
          used: 4,
          limit: 50,
          formatNumber: (int n) => 'X${n}X',
        ),
      ),
    );

    expect(find.text('X4X / X50X'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Optional unit
  // ---------------------------------------------------------------------------

  testWidgets('unit renders when given', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSUsageMeter(
          label: 'Checks',
          used: 4,
          limit: 50,
          unit: 'min',
          formatNumber: toStringFormatter,
        ),
      ),
    );

    expect(find.text('4 min / 50 min'), findsOneWidget);
  });

  testWidgets('unit is absent when not given', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MSUsageMeter(
          label: 'Checks',
          used: 4,
          limit: 50,
          formatNumber: toStringFormatter,
        ),
      ),
    );

    expect(find.text('4 / 50'), findsOneWidget);
    expect(find.textContaining('min'), findsNothing);
  });
}
