import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// A host app's own shell, of the shape a consumer registers: it wraps the one
/// child it is handed and adds no keying of its own.
class _HostShell extends StatelessWidget {
  const _HostShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(child: child);
}

/// What this file asserts, and what it deliberately does not.
///
/// It asserts that the page a HOST layout receives is wrapped in a
/// [KeyedSubtree] whose key is the CURRENT ROUTE PATH, and that the key
/// changes when the route does. That is the whole of what moving the keying
/// into `makeLayout` delivers: the mechanism the default layouts already
/// carried now reaches a layout the host replaced.
///
/// It does NOT assert that the keying prevents the render-object teardown the
/// default layouts' own comments describe. That failure needs accumulated
/// navigation between scrollable views and did not reproduce in a widget test:
/// a version of this file that counted page mounts across a route change
/// passed with the wrap removed, so it was deleted rather than kept as a gate
/// that cannot fail. The mechanism is upstream's own claim and is unchanged
/// here; only its reach is.
void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Auth.fake();
    Magic.singleton('magic_starter', MagicStarterManager.new);
  });

  tearDown(Auth.unfake);

  group('the route scope makeLayout applies', () {
    testWidgets('keys the host layout page on the live route path', (
      WidgetTester tester,
    ) async {
      final MagicStarterManager manager = Magic.make<MagicStarterManager>(
        'magic_starter',
      );
      manager.view.registerLayout(
        'layout.app',
        (Widget child) => _HostShell(child: child),
      );

      // `layoutId` makes the shell PERSISTENT across the two routes, which is
      // the arrangement the keying exists for: one layout element holding one
      // child slot that two different pages take turns in.
      MagicRoute.group(
        layoutId: 'app',
        layout: (Widget child) =>
            manager.view.makeLayout('layout.app', child: child),
        routes: () {
          MagicRoute.page('/one', () => const Text('one'));
          MagicRoute.page('/two', () => const Text('two'));
        },
      );

      MagicRouter.instance.setInitialLocation('/one');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      expect(keyUnder(tester, 'one'), const ValueKey<String>('/one'));

      MagicRoute.to('/two');
      await tester.pumpAndSettle();

      expect(keyUnder(tester, 'two'), const ValueKey<String>('/two'));
    });
  });
}

/// The key of the [KeyedSubtree] wrapping the page showing [text].
///
/// `find.ancestor` rather than `find.byType`, because the framework puts
/// several unrelated [KeyedSubtree]s in a routed tree and a bare type finder
/// reports `Bad state: Too many elements`.
Key? keyUnder(WidgetTester tester, String text) {
  return tester
      .widget<KeyedSubtree>(
        find.ancestor(
          of: find.text(text),
          matching: find.byWidgetPredicate(
            (Widget w) => w is KeyedSubtree && w.key is ValueKey<String>,
          ),
        ),
      )
      .key;
}
