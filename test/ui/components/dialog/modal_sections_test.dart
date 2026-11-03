import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/src/ui/components/dialog/modal_sections.dart';

/// The layout behind every starter modal: the header stays pinned while it
/// takes at most half the scroll viewport, measured, and scrolls with the
/// body above that; the footer stays put either way.
void main() {
  const Key headerKey = Key('header');
  const Key footerKey = Key('footer');
  int headerTaps = 0;

  setUp(() => headerTaps = 0);

  Future<void> pump(
    WidgetTester tester, {
    required double height,
    double headerHeight = 100,
    bool scrollable = true,
    Widget? body,
    bool withFooter = false,
    bool bouncing = false,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: bouncing
            ? const MaterialScrollBehavior().copyWith(
                physics: const BouncingScrollPhysics(),
              )
            : null,
        home: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: ModalSections(
              scrollable: scrollable,
              header: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => headerTaps++,
                child: SizedBox(
                  key: headerKey,
                  height: headerHeight,
                  child: const Text('Title'),
                ),
              ),
              body:
                  body ??
                  Column(
                    children: [
                      for (int i = 0; i < 40; i++)
                        SizedBox(height: 50, child: Text('row $i')),
                    ],
                  ),
              footer: withFooter
                  ? const SizedBox(key: footerKey, height: 60)
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> scrollBody(WidgetTester tester) async {
    await tester.drag(find.text('row 0'), const Offset(0, -300));
    await tester.pumpAndSettle();
  }

  group('ModalSections header', () {
    testWidgets('stays pinned at exactly half the viewport', (tester) async {
      await pump(tester, height: 200);
      await scrollBody(tester);

      expect(tester.getRect(find.byKey(headerKey)).top, 0);
    });

    testWidgets('scrolls with the body just above half the viewport', (
      tester,
    ) async {
      await pump(tester, height: 199);
      await scrollBody(tester);

      expect(tester.getRect(find.byKey(headerKey)).top, lessThan(0));
    });

    testWidgets('a pinned header holds still while the body bounces', (
      tester,
    ) async {
      await pump(tester, height: 400, bouncing: true);
      final double rowTop = tester.getRect(find.text('row 0')).top;

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.text('row 0')),
      );
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();

      expect(tester.getRect(find.text('row 0')).top, greaterThan(rowTop));
      expect(tester.getRect(find.byKey(headerKey)).top, 0);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    bool insideScrolling(SemanticsNode node) {
      for (SemanticsNode? n = node.parent; n != null; n = n.parent) {
        if (n.flagsCollection.hasImplicitScrolling) return true;
      }

      return false;
    }

    testWidgets('a pinned header is its own node outside the scroll', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, height: 400);
      await scrollBody(tester);

      expect(insideScrolling(tester.getSemantics(find.text('row 8'))), isTrue);
      expect(insideScrolling(tester.getSemantics(find.text('Title'))), isFalse);
      handle.dispose();
    });

    testWidgets('a scrolled header stays in the scrolling node', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, height: 199);

      expect(insideScrolling(tester.getSemantics(find.text('Title'))), isTrue);
      handle.dispose();
    });

    testWidgets('a pinned header covers the body it is over', (tester) async {
      await pump(tester, height: 400);
      await scrollBody(tester);

      await tester.tapAt(const Offset(200, 50));

      expect(headerTaps, 1);
    });
  });

  group('ModalSections without its own scroll', () {
    testWidgets('keeps the header fixed and bounds the body by what is left', (
      tester,
    ) async {
      BoxConstraints? seen;

      await pump(
        tester,
        height: 300,
        scrollable: false,
        withFooter: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            seen = constraints;

            return ListView(
              children: [
                for (int i = 0; i < 40; i++)
                  SizedBox(height: 50, child: Text('row $i')),
              ],
            );
          },
        ),
      );

      expect(tester.takeException(), isNull);
      expect(seen!.maxHeight, 300 - 100 - 60);
      await tester.dragUntilVisible(
        find.text('row 39'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('row 39').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.byKey(headerKey)).top, 0);
      expect(tester.getRect(find.byKey(footerKey)).bottom, 300);
    });
  });
}
