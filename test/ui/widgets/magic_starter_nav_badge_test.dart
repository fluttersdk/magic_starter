import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The one catalogue line the badge reads, in its two plural forms.
class _BadgeCopyLoader implements TranslationLoader {
  const _BadgeCopyLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async => <String, dynamic>{
    'nav.badge_count': 'One item|:count items',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    MagicApp.reset();
    Magic.flush();

    Translator.instance.setLoader(const _BadgeCopyLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    Translator.reset();
    MagicApp.reset();
    Magic.flush();
  });

  Widget mount(ValueListenable<int?> count, {String? className}) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(
          body: MagicStarterNavBadge(
            count: count,
            labelKey: 'nav.badge_count',
            className: className,
          ),
        ),
      ),
    );
  }

  group('MagicStarterNavBadge visibility', () {
    testWidgets('draws nothing while the count is null', (tester) async {
      await tester.pumpWidget(mount(ValueNotifier<int?>(null)));

      expect(find.byType(MSBadge), findsNothing);
    });

    testWidgets('draws nothing at zero', (tester) async {
      await tester.pumpWidget(mount(ValueNotifier<int?>(0)));

      expect(find.byType(MSBadge), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('draws nothing below zero', (tester) async {
      await tester.pumpWidget(mount(ValueNotifier<int?>(-3)));

      expect(find.byType(MSBadge), findsNothing);
    });

    testWidgets('draws the count from one up', (tester) async {
      await tester.pumpWidget(mount(ValueNotifier<int?>(4)));

      expect(find.byType(MSBadge), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });
  });

  group('MagicStarterNavBadge cap', () {
    testWidgets('draws 99 as it is', (tester) async {
      await tester.pumpWidget(mount(ValueNotifier<int?>(99)));

      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('draws 100 as 99+', (tester) async {
      await tester.pumpWidget(mount(ValueNotifier<int?>(100)));

      expect(find.text('99+'), findsOneWidget);
      expect(find.text('100'), findsNothing);
    });

    testWidgets('draws a four digit count as 99+', (tester) async {
      await tester.pumpWidget(mount(ValueNotifier<int?>(1234)));

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('MagicStarterNavBadge live count', () {
    testWidgets('follows the notifier without a new widget', (tester) async {
      final count = ValueNotifier<int?>(null);
      addTearDown(count.dispose);

      await tester.pumpWidget(mount(count));
      expect(find.byType(MSBadge), findsNothing);

      count.value = 2;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      count.value = 7;
      await tester.pump();
      expect(find.text('2'), findsNothing);
      expect(find.text('7'), findsOneWidget);

      count.value = 0;
      await tester.pump();
      expect(find.byType(MSBadge), findsNothing);

      count.value = 120;
      await tester.pump();
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('moves to a replacement notifier', (tester) async {
      final first = ValueNotifier<int?>(3);
      final second = ValueNotifier<int?>(8);
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await tester.pumpWidget(mount(first));
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(mount(second));
      expect(find.text('8'), findsOneWidget);

      first.value = 50;
      await tester.pump();
      expect(find.text('50'), findsNothing);
    });
  });

  group('MagicStarterNavBadge accessibility', () {
    testWidgets('names the count for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(mount(ValueNotifier<int?>(4)));

      expect(find.bySemanticsLabel('4 items'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('reads the singular form for one', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(mount(ValueNotifier<int?>(1)));

      expect(find.bySemanticsLabel('One item'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('says the real count above the cap', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(mount(ValueNotifier<int?>(150)));

      expect(find.bySemanticsLabel('150 items'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('does not read the drawn number a second time', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(mount(ValueNotifier<int?>(4)));

      expect(find.bySemanticsLabel('4'), findsNothing);

      handle.dispose();
    });

    testWidgets('has no semantics node while hidden', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(mount(ValueNotifier<int?>(0)));

      expect(find.bySemanticsLabel(RegExp('items?')), findsNothing);

      handle.dispose();
    });
  });

  group('MagicStarterNavBadge styling', () {
    testWidgets('appends the caller className to the badge', (tester) async {
      await tester.pumpWidget(
        mount(ValueNotifier<int?>(4), className: 'bg-primary text-on-primary'),
      );

      final badge = tester.widget<MSBadge>(find.byType(MSBadge));

      expect(badge.className, 'bg-primary text-on-primary');
    });

    testWidgets('leaves the badge on its recipe without a className', (
      tester,
    ) async {
      await tester.pumpWidget(mount(ValueNotifier<int?>(4)));

      final badge = tester.widget<MSBadge>(find.byType(MSBadge));

      expect(badge.className, isNull);
      expect(badge.tone, BadgeTone.neutral);
    });
  });

  group('MagicStarterNavBadge catalogue', () {
    test('the default label key ships in the install stub', () {
      // A host installed from the stub gets the sentence; without it a screen
      // reader would be handed the dotted key. The widget tests above load
      // their own copy, so only this ties the default to the shipped file.
      final stub =
          jsonDecode(File('assets/stubs/install/en.stub').readAsStringSync())
              as Map<String, dynamic>;
      final nav = stub['nav'] as Map<String, dynamic>;
      final sentence = nav['badge_count'] as String;

      expect(
        const MagicStarterNavItem(
          icon: Icons.home,
          labelKey: 'x',
          path: '/',
        ).badgeLabelKey,
        'nav.badge_count',
      );
      expect(sentence.split('|'), hasLength(2));
      expect(sentence, contains(':count'));
    });
  });
}
