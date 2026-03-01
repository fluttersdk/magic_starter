import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: SingleChildScrollView(child: widget),
        ),
      ),
    );
  }

  group('MagicStarterLoginView — identity modes', () {
    setUp(() {
      MagicApp.reset();
      Magic.flush();
      Magic.singleton('log', () => LogManager());
      Magic.singleton('magic_starter', () => MagicStarterManager());
      Magic.put(StarterAuthController());
    });

    testWidgets('shows email field in email-only mode (default)',
        (tester) async {
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', false);

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));

      await tester.pumpAndSettle();

      expect(find.widgetWithText(WFormInput, trans('attributes.email')),
          findsOneWidget);
      expect(find.widgetWithText(WFormInput, trans('attributes.phone')),
          findsNothing);
    });

    testWidgets('shows phone field in phone-only mode', (tester) async {
      Config.set('magic_starter.auth.email', false);
      Config.set('magic_starter.auth.phone', true);

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));

      await tester.pumpAndSettle();

      expect(find.widgetWithText(WFormInput, trans('attributes.phone')),
          findsOneWidget);
      expect(find.widgetWithText(WFormInput, trans('attributes.email')),
          findsNothing);
    });

    testWidgets('shows segmented toggle in both mode', (tester) async {
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', true);

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));

      await tester.pumpAndSettle();

      // Segmented control renders labels as WText inside WAnchor.
      expect(find.text(trans('attributes.email')), findsWidgets);
      expect(find.text(trans('attributes.phone')), findsWidgets);
    });

    testWidgets('switching to phone tab shows phone field in both mode',
        (tester) async {
      Config.set('magic_starter.auth.email', true);
      Config.set('magic_starter.auth.phone', true);

      await tester.pumpWidget(wrap(const MagicStarterLoginView()));
      await tester.pumpAndSettle();

      // Initially shows email field.
      expect(find.widgetWithText(WFormInput, trans('attributes.email')),
          findsOneWidget);

      // Tap phone segment (WAnchor wrapping the label text).
      await tester.tap(find.text(trans('attributes.phone')).first);
      await tester.pumpAndSettle();

      // Now shows phone field.
      expect(find.widgetWithText(WFormInput, trans('attributes.phone')),
          findsOneWidget);
      expect(find.widgetWithText(WFormInput, trans('attributes.email')),
          findsNothing);
    });
  });
}
