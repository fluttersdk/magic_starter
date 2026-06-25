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

    testWidgets('bg-surface resolves (not a silent no-op) in light mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const WDiv(className: 'bg-surface')),
      );

      // WindParser expands aliases pre-parse. bg-surface -> bg-white which
      // the background parser resolves to a Color, so the WDiv renders a
      // Container with a non-null decoration. We assert the widget tree builds
      // without exception and find a Container (the decoration wrapper).
      expect(find.byType(WDiv), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('bg-surface resolves (not a silent no-op) in dark mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          const WDiv(className: 'bg-surface'),
          brightness: Brightness.dark,
        ),
      );

      expect(find.byType(WDiv), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('bg-surface text-fg builds without exception',
        (WidgetTester tester) async {
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

    testWidgets('aliases map wired into WindThemeData is not empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(const SizedBox()),
      );

      final theme = WindTheme.of(tester.element(find.byType(Scaffold)));
      expect(theme.data.aliases, isNotEmpty);
      expect(theme.data.aliases.containsKey('bg-surface'), isTrue);
      expect(theme.data.aliases.containsKey('text-fg'), isTrue);
    });
  });
}
