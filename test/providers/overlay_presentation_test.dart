import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The starter provider hands magic's router the answer to "a sheet or a
/// dialog?" for an overlay route, so `MagicStarterModalTheme.presentation`
/// governs a route's overlay as it governs `MSDialog.show`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    MagicRouter.reset();
    Config.set('magic_starter.features.notifications', false);
    Auth.fake();
  });

  tearDown(() {
    Auth.unfake();
    MagicRouter.reset();
  });

  Future<void> bootProvider() async {
    final provider = MagicStarterServiceProvider(MagicApp.instance);
    provider.register();
    await provider.boot();
  }

  /// What the installed resolver answers at [width] under [presentation].
  Future<MagicOverlayPresentation> resolve(
    WidgetTester tester, {
    required MagicStarterModalPresentation presentation,
    required double width,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    MagicStarter.useModalTheme(
      MagicStarter.manager.modalTheme.copyWith(presentation: presentation),
    );
    late BuildContext captured;
    await tester.pumpWidget(
      WindTheme(
        data: WindThemeData(),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    return MagicRouter.instance.overlayPresentation!(captured);
  }

  testWidgets('boot installs a resolver on the router', (tester) async {
    expect(MagicRouter.instance.overlayPresentation, isNull);

    await bootProvider();

    expect(MagicRouter.instance.overlayPresentation, isNotNull);
  });

  group('the installed resolver', () {
    testWidgets('answers dialog from the breakpoint up when adaptive', (
      tester,
    ) async {
      await bootProvider();

      expect(
        await resolve(
          tester,
          presentation: MagicStarterModalPresentation.adaptive,
          width: 1440,
        ),
        MagicOverlayPresentation.dialog,
      );
    });

    testWidgets('answers sheet below the breakpoint when adaptive', (
      tester,
    ) async {
      await bootProvider();

      expect(
        await resolve(
          tester,
          presentation: MagicStarterModalPresentation.adaptive,
          width: 390,
        ),
        MagicOverlayPresentation.sheet,
      );
    });

    // A theme that never asked for `adaptive` keeps every overlay route the
    // sheet it has always been.
    for (final presentation in [
      MagicStarterModalPresentation.dialog,
      MagicStarterModalPresentation.sheet,
    ]) {
      testWidgets('answers sheet at 1440 px when ${presentation.name}', (
        tester,
      ) async {
        await bootProvider();

        expect(
          await resolve(tester, presentation: presentation, width: 1440),
          MagicOverlayPresentation.sheet,
        );
      });
    }
  });
}
