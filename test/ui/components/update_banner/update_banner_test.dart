import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/ui/components/update_banner/index.dart';
import 'package:magic_starter/src/ui/components/update_banner/update_banner.preview.dart';

void main() {
  const String message = 'A new version of the app is ready.';
  const String actionLabel = 'Reload';
  const String dismissLabel = 'Later';

  Widget wrap(Widget widget) => MaterialApp(
    home: WindTheme(
      data: WindThemeData(),
      child: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );

  Future<void> mountAt(WidgetTester tester, Size size, Widget widget) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(widget));
    await tester.pumpAndSettle();
  }

  group('MSUpdateBanner', () {
    testWidgets('renders the message and both button labels', (tester) async {
      await mountAt(
        tester,
        const Size(1440, 900),
        MSUpdateBanner(
          message: message,
          actionLabel: actionLabel,
          onAction: () {},
          dismissLabel: dismissLabel,
          onDismiss: () {},
        ),
      );

      expect(find.text(message), findsOneWidget);
      expect(find.text(actionLabel), findsOneWidget);
      expect(find.text(dismissLabel), findsOneWidget);
    });

    testWidgets('tapping the action calls onAction once and not onDismiss', (
      tester,
    ) async {
      int actions = 0;
      int dismissals = 0;

      await mountAt(
        tester,
        const Size(1440, 900),
        MSUpdateBanner(
          message: message,
          actionLabel: actionLabel,
          onAction: () => actions++,
          dismissLabel: dismissLabel,
          onDismiss: () => dismissals++,
        ),
      );

      await tester.tap(find.text(actionLabel));
      await tester.pump();

      expect(actions, 1);
      expect(dismissals, 0);
    });

    testWidgets('tapping Later calls onDismiss once and not onAction', (
      tester,
    ) async {
      int actions = 0;
      int dismissals = 0;

      await mountAt(
        tester,
        const Size(1440, 900),
        MSUpdateBanner(
          message: message,
          actionLabel: actionLabel,
          onAction: () => actions++,
          dismissLabel: dismissLabel,
          onDismiss: () => dismissals++,
        ),
      );

      await tester.tap(find.text(dismissLabel));
      await tester.pump();

      expect(dismissals, 1);
      expect(actions, 0);
    });

    for (final Size size in const <Size>[Size(390, 844), Size(1440, 900)]) {
      testWidgets('renders without overflow at ${size.width.toInt()} px', (
        tester,
      ) async {
        await mountAt(
          tester,
          size,
          MSUpdateBanner(
            message:
                'A new version of the app is ready. Reload to get the latest '
                'fixes and improvements, nothing you have open is lost.',
            actionLabel: actionLabel,
            onAction: () {},
            dismissLabel: dismissLabel,
            onDismiss: () {},
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text(actionLabel), findsOneWidget);
        expect(find.text(dismissLabel), findsOneWidget);
      });
    }

    testWidgets('is announced as a live region', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await mountAt(
        tester,
        const Size(1440, 900),
        MSUpdateBanner(
          message: message,
          actionLabel: actionLabel,
          onAction: () {},
          dismissLabel: dismissLabel,
          onDismiss: () {},
        ),
      );

      expect(
        tester.getSemantics(
          find
              .descendant(
                of: find.byType(MSUpdateBanner),
                matching: find.byWidgetPredicate(
                  (Widget w) =>
                      w is Semantics && w.properties.liveRegion == true,
                ),
              )
              .first,
        ),
        isSemantics(isLiveRegion: true),
      );

      handle.dispose();
    });

    testWidgets('draws the default update icon unless one is given', (
      tester,
    ) async {
      await mountAt(
        tester,
        const Size(1440, 900),
        MSUpdateBanner(
          message: message,
          actionLabel: actionLabel,
          onAction: () {},
          dismissLabel: dismissLabel,
          onDismiss: () {},
        ),
      );
      expect(find.byIcon(Icons.system_update_alt), findsOneWidget);

      await mountAt(
        tester,
        const Size(1440, 900),
        MSUpdateBanner(
          message: message,
          actionLabel: actionLabel,
          onAction: () {},
          dismissLabel: dismissLabel,
          onDismiss: () {},
          icon: Icons.refresh,
        ),
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.system_update_alt), findsNothing);
    });

    testWidgets('preview renders without error', (tester) async {
      await mountAt(tester, const Size(1440, 900), const UpdateBannerPreview());

      expect(find.byType(MSUpdateBanner), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
