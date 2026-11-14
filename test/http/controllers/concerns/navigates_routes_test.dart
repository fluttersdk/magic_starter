import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/configuration/magic_starter_config.dart';
import 'package:magic_starter/src/http/controllers/concerns/navigates_routes.dart';

/// Bare host exercising [NavigatesRoutes] in isolation, without pulling in a
/// full controller's HTTP/auth surface.
class _TestHost with NavigatesRoutes {}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    TitleManager.reset();
    MagicRouter.reset();
    Auth.fake();
  });

  tearDown(() {
    Auth.unfake();
  });

  group('NavigatesRoutes.navigateHome', () {
    testWidgets('targets the stored intended URL when one is set', (
      tester,
    ) async {
      final host = _TestHost();
      MagicRoute.page('/', () => const Text('home'));
      MagicRoute.page('/incidents/123', () => const Text('incident'));

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
      );
      await tester.pumpAndSettle();

      MagicRouter.instance.setIntendedUrl('/incidents/123');
      host.navigateHome();
      await tester.pumpAndSettle();

      expect(MagicRouter.instance.currentPath, '/incidents/123');
    });

    testWidgets(
      'falls back to the configured home route when no intent is stored',
      (tester) async {
        final host = _TestHost();
        MagicRoute.page('/', () => const Text('home'));
        MagicRoute.page('/monitors', () => const Text('monitors'));

        MagicRouter.instance.setInitialLocation('/monitors');

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        host.navigateHome();
        await tester.pumpAndSettle();

        expect(
          MagicRouter.instance.currentPath,
          MagicStarterConfig.homeRoute(),
        );
      },
    );

    testWidgets(
      'falls back to the configured home route when the stored intent is '
      'poisoned',
      (tester) async {
        final host = _TestHost();
        MagicRoute.page('/', () => const Text('home'));
        MagicRoute.page('/monitors', () => const Text('monitors'));

        MagicRouter.instance.setInitialLocation('/monitors');

        await tester.pumpWidget(
          MaterialApp.router(routerConfig: MagicRouter.instance.routerConfig),
        );
        await tester.pumpAndSettle();

        // Set directly rather than via a deep link parse, to prove
        // navigateHome itself rejects a non-leading-slash value regardless
        // of how it got stored.
        MagicRouter.instance.setIntendedUrl('https://evil.example/x');
        host.navigateHome();
        await tester.pumpAndSettle();

        expect(
          MagicRouter.instance.currentPath,
          MagicStarterConfig.homeRoute(),
        );
      },
    );
  });

  group('MagicStarterNextPath', () {
    tearDown(() => MagicRouter.instance.pullIntendedUrl());

    test('accepts an in-app path, its query and its fragment', () {
      final List<String> accepted = [
        '/',
        '/monitors',
        '/monitors/42/edit',
        '/connect?code=clm_abc',
        '/search?q=a..b',
        '/docs#install',
        '/a.b/c..d/...',
        '/şirket/ayarlar?q=çğü',
        '/日本',
        '/${'a' * 511}',
      ];

      for (final String path in accepted) {
        expect(MagicStarterNextPath.parse(path), path, reason: path);
      }
    });

    test('refuses anything that is not one in-app path', () {
      final List<String?> refused = [
        null,
        '',
        'monitors',
        'https://evil.example/x',
        '//evil.example/x',
        '///evil.example',
        r'/\evil.example',
        r'/a\b',
        '/a b',
        '/a\tb',
        '/a\nb',
        '/a\u0000b',
        '/a\u007fb',
        // What the server's `SameAppPath` refuses as `\p{C}` and `\p{Z}`:
        // a C1 control, bidi and zero-width format characters, a BOM, a
        // private-use and an unassigned code point, and Unicode separators.
        for (final int codePoint in [
          0x0085,
          0x202E,
          0x200B,
          0xFEFF,
          0xE000,
          0x0378,
          0x00A0,
          0x2028,
          0x3000,
        ])
          '/a${String.fromCharCode(codePoint)}b',
        ' /monitors',
        '/../admin',
        '/a/../b',
        '/a/..',
        '/a/%2e%2e/b',
        '/a/.%2E/b',
        '/${'a' * 512}',
      ];

      for (final String? path in refused) {
        expect(MagicStarterNextPath.parse(path), isNull, reason: path);
      }
    });

    test('remember stores a valid path as the intended url', () {
      MagicStarterNextPath.remember('/monitors/42');

      expect(MagicRouter.instance.pullIntendedUrl(), '/monitors/42');
    });

    test('remember ignores an invalid path and keeps any stored intent', () {
      MagicRouter.instance.setIntendedUrl('/teams');

      MagicStarterNextPath.remember('//evil.example');
      MagicStarterNextPath.remember(null);

      expect(MagicRouter.instance.pullIntendedUrl(), '/teams');
    });
  });
}
