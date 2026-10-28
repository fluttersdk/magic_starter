import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  // -------------------------------------------------------------------------
  // defaultAliases structure
  // -------------------------------------------------------------------------

  group('MagicStarterTokens.defaultAliases', () {
    test('contains all 17 required semantic roles', () {
      // Keys follow the bg-/text-/border-color- prefix convention.
      const roles = [
        'bg-surface',
        'bg-surface-container',
        'bg-surface-container-high',
        'text-fg',
        'text-fg-muted',
        'text-fg-disabled',
        'bg-primary',
        'text-on-primary',
        'bg-primary-container',
        'bg-accent',
        'border-color-border',
        'border-color-border-subtle',
        'bg-destructive',
        'text-on-destructive',
        'bg-destructive-container',
        'bg-success',
        'bg-warning',
      ];

      for (final role in roles) {
        expect(
          MagicStarterTokens.defaultAliases,
          containsPair(role, isA<String>()),
          reason: 'missing role key: $role',
        );
      }
    });

    test('ships the soft state tints and the AI accent edge', () {
      const keys = [
        'bg-warning-soft',
        'text-warning-soft-foreground',
        'bg-success-soft',
        'text-success-soft-foreground',
        'bg-ai-soft',
        'text-ai-soft-foreground',
        'border-ai',
      ];

      for (final key in keys) {
        expect(
          MagicStarterTokens.defaultAliases,
          containsPair(key, isA<String>()),
          reason: 'missing key: $key',
        );
      }
    });

    test('every role value contains a light token and a dark: token', () {
      for (final entry in MagicStarterTokens.defaultAliases.entries) {
        final value = entry.value;
        final tokens = value.split(RegExp(r'\s+'));

        final hasLight = tokens.any((t) => !t.contains(':'));
        final hasDark = tokens.any((t) => t.startsWith('dark:'));

        expect(
          hasLight,
          isTrue,
          reason: '${entry.key} is missing a light token in "$value"',
        );
        expect(
          hasDark,
          isTrue,
          reason: '${entry.key} is missing a dark: token in "$value"',
        );
      }
    });

    test(
      'bg-prefixed keys have bg- values; text-prefixed keys have text- values',
      () {
        for (final entry in MagicStarterTokens.defaultAliases.entries) {
          final key = entry.key;
          final value = entry.value;

          if (key.startsWith('bg-')) {
            expect(
              value,
              startsWith('bg-'),
              reason: '$key value should start with bg-: got "$value"',
            );
          } else if (key.startsWith('text-')) {
            expect(
              value.contains('text-'),
              isTrue,
              reason: '$key value should contain text-: got "$value"',
            );
          } else if (key.startsWith('border-color-')) {
            expect(
              value.contains('border-'),
              isTrue,
              reason: '$key value should contain border-: got "$value"',
            );
          }
        }
      },
    );
  });

  // -------------------------------------------------------------------------
  // role()
  // -------------------------------------------------------------------------

  group('MagicStarterTokens.role', () {
    const hostRed = 'text-[#DF202E] dark:text-[#FF645F]';
    const redFallback = 'text-red-600 dark:text-red-400';

    test('returns the token when the theme defines it as an alias key', () {
      final theme = WindThemeData(aliases: {'text-destructive': hostRed});

      expect(
        MagicStarterTokens.role(theme, 'text-destructive'),
        'text-destructive',
      );
    });

    test('returns the token when the theme carries its backing colour', () {
      final theme = WindThemeData(
        colors: {
          'destructive': const MaterialColor(0xFFDF202E, {
            500: Color(0xFFDF202E),
          }),
        },
      );

      expect(
        MagicStarterTokens.role(theme, 'text-destructive'),
        'text-destructive',
      );
    });

    test('falls back to the red pair when the theme defines neither', () {
      expect(
        MagicStarterTokens.role(WindThemeData(), 'text-destructive'),
        redFallback,
      );
      expect(
        MagicStarterTokens.role(
          WindThemeData(aliases: MagicStarterTokens.defaultAliases),
          'text-destructive',
        ),
        redFallback,
      );
    });

    test('falls back to the red pair when there is no theme', () {
      expect(MagicStarterTokens.role(null, 'text-destructive'), redFallback);
    });

    // The on-colour roles of the success and warning fills. The alias contract
    // ships no such keys (only `text-on-destructive`), so a host that wants its
    // own defines them next to its `bg-success` and `bg-warning`; without them
    // the fallback has to read on the STOCK fills (green and amber 600 in
    // light, 500 in dark), which white does not (3.3:1 and 3.2:1).
    for (final role in ['text-on-success', 'text-on-warning']) {
      test('$role is the token when the theme defines it', () {
        final theme = WindThemeData(
          aliases: {role: 'text-[#0B2A18] dark:text-[#FFFFFF]'},
        );

        expect(MagicStarterTokens.role(theme, role), role);
      });

      test('$role falls back to a dark pair that reads on the stock fills', () {
        const fallback = 'text-gray-950 dark:text-gray-950';

        expect(MagicStarterTokens.role(WindThemeData(), role), fallback);
        expect(
          MagicStarterTokens.role(
            WindThemeData(aliases: MagicStarterTokens.defaultAliases),
            role,
          ),
          fallback,
        );
        expect(MagicStarterTokens.role(null, role), fallback);
      });
    }

    test('falls back to the shipped alias value for a default role', () {
      expect(
        MagicStarterTokens.role(null, 'text-fg'),
        MagicStarterTokens.defaultAliases['text-fg'],
      );
    });
  });

  // -------------------------------------------------------------------------
  // QA: bg-surface text-fg resolves (not a silent no-op)
  // -------------------------------------------------------------------------

  group('alias resolution — bg-surface text-fg', () {
    Widget wrap(Widget widget, {Brightness brightness = Brightness.light}) {
      return MaterialApp(
        home: WindTheme(
          data: WindThemeData(
            brightness: brightness,
            aliases: MagicStarterTokens.defaultAliases,
          ),
          child: Scaffold(body: widget),
        ),
      );
    }

    testWidgets('bg-surface resolves (not a silent no-op) in light mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const WDiv(className: 'bg-surface')));

      // WindParser expands aliases pre-parse. bg-surface -> bg-white which
      // the background parser resolves to a Color, so the WDiv renders a
      // DecoratedBox. We assert the widget tree builds without exception and
      // that the decoration wrapper sits under the WDiv.
      expect(find.byType(WDiv), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WDiv),
          matching: find.byType(DecoratedBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('bg-surface resolves (not a silent no-op) in dark mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(const WDiv(className: 'bg-surface'), brightness: Brightness.dark),
      );

      expect(find.byType(WDiv), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(WDiv),
          matching: find.byType(DecoratedBox),
        ),
        findsOneWidget,
      );
    });

    testWidgets('bg-surface text-fg builds without exception', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const WDiv(
            className: 'bg-surface',
            child: WText('hello', className: 'text-fg'),
          ),
        ),
      );

      expect(find.byType(WDiv), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('aliases map wired into WindThemeData is not empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox()));

      final theme = WindTheme.of(tester.element(find.byType(Scaffold)));
      expect(theme.data.aliases, isNotEmpty);
      expect(theme.data.aliases.containsKey('bg-surface'), isTrue);
      expect(theme.data.aliases.containsKey('text-fg'), isTrue);
    });
  });
}
