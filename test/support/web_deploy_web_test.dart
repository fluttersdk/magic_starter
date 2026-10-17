@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/support/web_deploy_web.dart';
import 'package:web/web.dart' as web;

void main() {
  setUp(() {
    MagicApp.reset();
    Magic.flush();
    Magic.singleton('log', () => LogManager());
    Config.set('logging', <String, dynamic>{
      'default': 'console',
      'channels': <String, dynamic>{
        'console': <String, dynamic>{'driver': 'console', 'level': 'debug'},
      },
    });
  });

  group('fetchDeployedBuildNumber', () {
    test('returns the build_number of the fetched document', () async {
      final String? build = await fetchDeployedBuildNumber(
        url: Uri.parse('data:application/json,{"build_number":"42"}'),
      );

      expect(build, '42');
    });

    test('returns null when the document is not JSON', () async {
      final String? build = await fetchDeployedBuildNumber(
        url: Uri.parse('data:text/plain,not-json'),
      );

      expect(build, isNull);
    });

    test('returns null when the build_number is empty', () async {
      final String? build = await fetchDeployedBuildNumber(
        url: Uri.parse('data:application/json,{"build_number":""}'),
      );

      expect(build, isNull);
    });
  });
  group('defaultVersionUrl', () {
    test('resolves against the document base, not the current route', () {
      // 1. Pin a document base the way a Flutter web index.html does, so a
      //    deep route does not move it.
      final String original = web.window.location.href;
      final web.HTMLBaseElement base = web.HTMLBaseElement()
        ..href = Uri.base.resolve('./').toString();
      web.document.head!.prepend(base);
      addTearDown(() {
        base.remove();
        web.window.history.pushState(null, '', original);
      });

      // 2. Stand on a deep route, as `usePathUrlStrategy` does.
      web.window.history.pushState(null, '', '/a/b/c');

      final Uri url = defaultVersionUrl();
      final Uri expected = Uri.parse(
        web.document.baseURI,
      ).resolve('version.json');

      expect(url.path, expected.path);
      expect(url.queryParameters['cb'], isNotEmpty);
      expect(url.path, isNot(Uri.base.resolve('version.json').path));
    });
  });
}
