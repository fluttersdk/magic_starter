import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('magic_starter', () => MagicStarterManager());
    Config.set('wind.colors.primary', 'indigo');
  });

  Widget wrap(Widget widget) {
    final themeData = WindThemeData(colors: {'primary': Colors.indigo});
    return WindTheme(
      data: themeData,
      child: MaterialApp(
        theme: themeData.toThemeData(),
        home: Scaffold(body: Center(child: widget)),
      ),
    );
  }

  group('MSAvatar', () {
    testWidgets('renders the photo when there is one', (tester) async {
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            photoUrl: 'https://example.test/avatar.png',
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      expect(find.byType(WImage), findsOneWidget);
      expect(find.text('AC'), findsNothing);
    });

    testWidgets('the photo fills the box rather than a band across it', (
      tester,
    ) async {
      // Reported off a TestFlight build: the header avatar was "not round, cut
      // on the left and right". It was a 36px circle holding an image laid out
      // 906 wide and 28 tall, so the clip showed one horizontal slice of it and
      // left the background above and below.
      //
      // The cause was the flex on the clipping box. A wind flex gives its child
      // the SCREEN width for `w-full` rather than its own, and starves `h-full`
      // on the cross axis, so the two utilities that should have made the image
      // fill its box did the opposite. Measured: 905.8 x 28.0 with any `flex`
      // in the class list, 36 x 36 without one.
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            photoUrl: 'https://example.test/avatar.png',
            className: 'w-9 h-9 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      // A second frame: wind resolves its className on the frame after the
      // first, so a rect read straight after `pumpWidget` is the placeholder's.
      await tester.pump();

      final Rect box = tester.getRect(find.byType(MSAvatar));
      final Rect image = tester.getRect(find.byType(WImage));

      expect(box.size, const Size(36, 36), reason: 'the box itself is square');
      expect(
        image.size,
        box.size,
        reason: 'the photo covers the whole circle, not a band across it',
      );
    });

    testWidgets('the fallback is centred without a flex on the clip box', (
      tester,
    ) async {
      // The flex that broke the photo was there to centre this, so removing it
      // has to keep the centring. It moves inside the fallback branch, where a
      // full-size child of a non-flex box does resolve to the box.
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            className: 'w-9 h-9 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      await tester.pump();

      expect(
        tester.getRect(find.text('AC')).center,
        tester.getRect(find.byType(MSAvatar)).center,
      );
    });

    testWidgets('falls back when there is no photo', (tester) async {
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      expect(find.text('AC'), findsOneWidget);
      expect(find.byType(WImage), findsNothing);
    });

    testWidgets('treats an empty url as no photo', (tester) async {
      // An API that clears a photo commonly answers `''` rather than null, and
      // a bare null check would then render an image widget pointed at nothing.
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            photoUrl: '',
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      expect(find.text('AC'), findsOneWidget);
      expect(find.byType(WImage), findsNothing);
    });

    testWidgets('falls back when the photo fails to load', (tester) async {
      // An expired signed link, or a photo deleted on another device. The
      // account effectively has no photo at that moment, so the answer is the
      // same as having none rather than a grey box. The test binding refuses
      // every network image, which is exactly the failure this branch exists
      // for.
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            photoUrl: 'https://example.test/gone.png',
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      // The load fails on a later frame, so the first pump still shows the
      // image widget with nothing in it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('AC'), findsOneWidget);
    });

    testWidgets('clips, so the shape applies to the photo', (tester) async {
      // Without `overflow-hidden` from the recipe base the rounding reaches
      // only the background behind the image, and a square photo sits inside a
      // circular frame.
      await tester.pumpWidget(
        wrap(
          const MSAvatar(
            photoUrl: 'https://example.test/avatar.png',
            className: 'w-8 h-8 rounded-full',
            fallback: WText('AC'),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsWidgets);
    });
  });
}
