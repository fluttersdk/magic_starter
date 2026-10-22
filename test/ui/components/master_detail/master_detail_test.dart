import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';
import 'package:magic_starter/src/ui/components/master_detail/master_detail.preview.dart';

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

  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: WindTheme(
        data: WindThemeData(),
        child: Scaffold(body: SingleChildScrollView(child: widget)),
      ),
    );
  }

  const Widget list = Text('list');
  const Widget item = Text('item');
  const Widget empty = Text('pick one');

  group('MasterDetailRecipe', () {
    test('the split row is a top-aligned row with the section gap', () {
      final String cls = masterDetailSplitRecipe();

      expect(cls, contains('flex-row'));
      expect(cls, contains('items-start'));
      expect(cls, contains('gap-6'));
    });

    test('the list column is fixed and never shrinks', () {
      final String cls = masterDetailMasterColumnRecipe();

      expect(cls, contains('w-96'));
      expect(cls, contains('flex-shrink-0'));
    });

    test('the detail column takes the rest and may shrink', () {
      final String cls = masterDetailDetailColumnRecipe();

      expect(cls, contains('flex-1'));
      expect(cls, contains('min-w-0'));
    });

    test('a caller className is appended last', () {
      expect(
        masterDetailMasterColumnRecipe(className: 'w-80'),
        endsWith('w-80'),
      );
    });
  });

  group('below the breakpoint', () {
    testWidgets('shows the list alone when nothing is selected', (
      tester,
    ) async {
      setWidth(tester, 390);

      await tester.pumpWidget(
        wrap(const MSMasterDetail(master: list, placeholder: empty)),
      );

      expect(find.text('list'), findsOneWidget);
      expect(find.text('pick one'), findsNothing);
    });

    testWidgets('shows the selected item alone, as a pushed page', (
      tester,
    ) async {
      setWidth(tester, 1023);

      await tester.pumpWidget(
        wrap(const MSMasterDetail(master: list, detail: item)),
      );

      expect(find.text('item'), findsOneWidget);
      expect(find.text('list'), findsNothing);
    });
  });

  group('from the breakpoint', () {
    testWidgets('shows the list and the item side by side', (tester) async {
      setWidth(tester, 1024);

      await tester.pumpWidget(
        wrap(const MSMasterDetail(master: list, detail: item)),
      );

      expect(find.text('list'), findsOneWidget);
      expect(find.text('item'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('item')).dx,
        greaterThan(tester.getTopLeft(find.text('list')).dx),
      );
    });

    testWidgets('the list column is 384 px and the detail takes the rest', (
      tester,
    ) async {
      setWidth(tester, 1440);

      await tester.pumpWidget(
        wrap(
          const MSMasterDetail(
            master: SizedBox(key: Key('list'), height: 10),
            detail: SizedBox(key: Key('item'), height: 10),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('list'))).width, 384);
      // 1440 less the list column and the 24 px gap.
      expect(tester.getSize(find.byKey(const Key('item'))).width, 1032);
    });

    testWidgets('shows the placeholder while nothing is selected', (
      tester,
    ) async {
      setWidth(tester, 1440);

      await tester.pumpWidget(
        wrap(const MSMasterDetail(master: list, placeholder: empty)),
      );

      expect(find.text('list'), findsOneWidget);
      expect(find.text('pick one'), findsOneWidget);
    });

    testWidgets('a column override reaches the list column', (tester) async {
      setWidth(tester, 1440);

      await tester.pumpWidget(
        wrap(
          const MSMasterDetail(
            master: SizedBox(key: Key('list'), height: 10),
            masterClassName: 'w-80',
          ),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('list'))).width, 320);
    });

    testWidgets('a lower breakpoint splits a narrower window', (tester) async {
      setWidth(tester, 800);

      await tester.pumpWidget(
        wrap(
          const MSMasterDetail(master: list, detail: item, breakpoint: 'md'),
        ),
      );

      expect(find.text('list'), findsOneWidget);
      expect(find.text('item'), findsOneWidget);
    });
  });

  group('isSplit', () {
    testWidgets('answers what the widget does at each width', (tester) async {
      final List<bool> answers = <bool>[];

      for (final double width in const <double>[390, 1024]) {
        setWidth(tester, width);
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (BuildContext context) {
                answers.add(MSMasterDetail.isSplit(context));

                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }

      expect(answers, <bool>[false, true]);
    });

    testWidgets('an unknown breakpoint fails loudly rather than never splits', (
      tester,
    ) async {
      setWidth(tester, 1440);

      await tester.pumpWidget(
        wrap(const MSMasterDetail(master: list, breakpoint: 'desktop')),
      );

      final Object? error = tester.takeException();
      expect(error, isA<StateError>());
      expect(
        (error as StateError).message,
        allOf(contains('MSMasterDetail.breakpoint'), contains('"desktop"')),
      );
    });
  });

  testWidgets('MasterDetail preview renders at both widths', (tester) async {
    for (final double width in const <double>[390, 1440]) {
      setWidth(tester, width);
      await tester.pumpWidget(wrap(const MasterDetailPreview()));
      expect(find.byType(MasterDetailPreview), findsOneWidget);
    }
  });
}
