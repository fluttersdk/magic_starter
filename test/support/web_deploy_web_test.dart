@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/support/web_deploy_web.dart';

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
}
