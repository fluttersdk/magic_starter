import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

Map<String, dynamic> _body() {
  return <String, dynamic>{
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'version': '1.1.0',
        'published_at': '2026-10-20T09:00:00.000000Z',
        'ios_build': 15,
        'android_build': 15,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'new',
            'text': <String, dynamic>{'en': 'Dark mode', 'tr': 'Koyu tema'},
          },
        ],
      },
    ],
    'meta': <String, dynamic>{
      'latest_build': <String, dynamic>{'ios': 15, 'android': 14},
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MagicStarterReleasesController controller;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    setUpMagicStarterForTests();

    controller = MagicStarterReleasesController();
  });

  tearDown(() {
    controller.dispose();
    Http.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterReleasesController.fetchReleases', () {
    test('reads GET /releases', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'GET');
        expect(request.url, endsWith('/releases'));

        return Http.response(_body());
      });

      await controller.fetchReleases();

      fake.assertSentCount(1);
    });

    test('a feed with releases is a success carrying the feed', () async {
      Http.fake((request) => Http.response(_body()));

      await controller.fetchReleases();

      expect(controller.isSuccess, isTrue);
      final feed = controller.rxState!;
      expect(feed.releases.single.version, '1.1.0');
      expect(feed.releases.single.iosBuild, 15);
      expect(feed.latestIosBuild, 15);
      expect(feed.latestAndroidBuild, 14);
    });

    test('an empty data list is empty', () async {
      Http.fake((request) {
        return Http.response(<String, dynamic>{'data': <dynamic>[]});
      });

      await controller.fetchReleases();

      expect(controller.isEmpty, isTrue);
    });

    test('a 404 is an error with the fetch_error copy', () async {
      Log.fake();
      addTearDown(Log.unfake);
      Http.fake((request) => Http.response(<String, dynamic>{}, 404));

      await controller.fetchReleases();

      expect(controller.isError, isTrue);
      expect(
        controller.rxStatus.message,
        trans('magic_starter.releases.fetch_error'),
      );
    });

    test('ignores a call while a read is in flight', () async {
      final fake = Http.fake((request) => Http.response(_body()));

      await Future.wait(<Future<void>>[
        controller.fetchReleases(),
        controller.fetchReleases(),
      ]);

      fake.assertSentCount(1);
    });
  });

  group('MagicStarterReleasesController.readFeed', () {
    test('answers the parsed feed', () async {
      final fake = Http.fake((request) {
        expect(request.method, 'GET');
        expect(request.url, endsWith('/releases'));

        return Http.response(_body());
      });

      final MagicStarterReleaseFeed? feed =
          await MagicStarterReleasesController.readFeed();

      fake.assertSentCount(1);
      expect(feed, isNotNull);
      expect(feed!.releases, hasLength(1));
      expect(feed.latestAndroidBuild, 14);
    });

    test('answers null and logs on a 500', () async {
      final logs = Log.fake();
      addTearDown(Log.unfake);
      Http.fake((request) => Http.response(<String, dynamic>{}, 500));

      final feed = await MagicStarterReleasesController.readFeed();

      expect(feed, isNull);
      expect(logs.entries.where((e) => e.level == 'warning'), hasLength(1));
    });

    test('answers null and logs when the request throws', () async {
      final logs = Log.fake();
      addTearDown(Log.unfake);
      Http.fake((request) => throw StateError('socket closed'));

      final feed = await MagicStarterReleasesController.readFeed();

      expect(feed, isNull);
      expect(logs.entries.where((e) => e.level == 'warning'), hasLength(1));
    });
  });
}
