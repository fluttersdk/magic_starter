import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The push and pop transition of every route in this file, long enough that
/// a pump of a fraction of it lands inside the exit window.
const Duration _transition = Duration(milliseconds: 300);

void main() {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    MagicStarter.useHostPageChrome((BuildContext context) => true);
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  Widget page(String title, {bool reports = true}) {
    return WindTheme(
      data: WindThemeData(),
      child: Scaffold(
        body: Column(
          children: [
            Text('page $title'),
            if (reports) MSPageHeader(title: title),
          ],
        ),
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: home),
    );
    await tester.pump();
  }

  /// Pushes [child] in a route whose transition takes [_transition] each way,
  /// and settles the push.
  Future<void> push(WidgetTester tester, Widget child) async {
    navigatorKey.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: _transition,
        reverseTransitionDuration: _transition,
        pageBuilder: (BuildContext context, _, _) => child,
        transitionsBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondary,
              Widget child,
            ) => FadeTransition(opacity: animation, child: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pops the top route and pumps a third of its exit, so the popped page is
  /// still on screen when the caller asserts.
  Future<void> popPartway(WidgetTester tester) async {
    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(_transition ~/ 3);
  }

  group('MSPageHeader reports only while its route is current', () {
    testWidgets('a page without a header pushed over one clears current', (
      tester,
    ) async {
      await pumpApp(tester, page('Settings'));
      expect(MagicStarter.pageChrome.current?.title, 'Settings');

      await push(tester, page('Plain', reports: false));
      expect(MagicStarter.pageChrome.current, isNull);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(MagicStarter.pageChrome.current?.title, 'Settings');
    });

    testWidgets('a popped page hands current back before its exit finishes', (
      tester,
    ) async {
      await pumpApp(tester, page('Settings'));
      await push(tester, page('Profile'));
      expect(MagicStarter.pageChrome.current?.title, 'Profile');

      await popPartway(tester);

      expect(find.text('page Profile'), findsOneWidget);
      expect(MagicStarter.pageChrome.current?.title, 'Settings');
    });

    testWidgets('a popped page withdraws before its exit finishes', (
      tester,
    ) async {
      await pumpApp(tester, page('Plain', reports: false));
      await push(tester, page('Profile'));
      expect(MagicStarter.pageChrome.current?.title, 'Profile');

      await popPartway(tester);

      expect(find.text('page Profile'), findsOneWidget);
      expect(MagicStarter.pageChrome.current, isNull);
    });

    testWidgets('a predicate flip keeps the top page current', (tester) async {
      MagicStarter.useHostPageChrome(
        (BuildContext context) => MediaQuery.sizeOf(context).width < 600,
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpApp(tester, page('Settings'));
      await push(tester, page('Profile'));
      expect(MagicStarter.pageChrome.current?.title, 'Profile');

      tester.view.physicalSize = const Size(1200, 844);
      await tester.pump();
      await tester.pump();
      expect(MagicStarter.pageChrome.current, isNull);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await tester.pump();
      expect(MagicStarter.pageChrome.current?.title, 'Profile');
    });

    testWidgets('a header outside any route still reports', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: WindTheme(
              data: WindThemeData(),
              child: const MSPageHeader(title: 'Bare'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(MagicStarter.pageChrome.current?.title, 'Bare');
    });
  });
}
