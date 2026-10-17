import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/models/magic_starter_release.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterReleaseItemType', () {
    test('tryParse maps the three wire values', () {
      expect(
        MagicStarterReleaseItemType.tryParse('new'),
        MagicStarterReleaseItemType.newFeature,
      );
      expect(
        MagicStarterReleaseItemType.tryParse('improved'),
        MagicStarterReleaseItemType.improved,
      );
      expect(
        MagicStarterReleaseItemType.tryParse('fixed'),
        MagicStarterReleaseItemType.fixed,
      );
    });

    test('tryParse answers null for an unknown or missing value', () {
      expect(MagicStarterReleaseItemType.tryParse('removed'), isNull);
      expect(MagicStarterReleaseItemType.tryParse(''), isNull);
      expect(MagicStarterReleaseItemType.tryParse(null), isNull);
    });

    test('key returns the wire value', () {
      expect(MagicStarterReleaseItemType.newFeature.key, 'new');
      expect(MagicStarterReleaseItemType.improved.key, 'improved');
      expect(MagicStarterReleaseItemType.fixed.key, 'fixed');
    });
  });

  group('MagicStarterReleaseItem.textFor', () {
    test('returns the exact language code value', () {
      const item = MagicStarterReleaseItem(
        type: MagicStarterReleaseItemType.fixed,
        text: {'en': 'Fixed it', 'tr': 'Duzeltildi'},
      );

      expect(item.textFor('tr'), 'Duzeltildi');
      expect(item.textFor('en'), 'Fixed it');
    });

    test('falls back to the default locale when the exact value is empty', () {
      const item = MagicStarterReleaseItem(
        type: MagicStarterReleaseItemType.newFeature,
        text: {'en': 'A', 'tr': ''},
      );

      expect(item.textFor('tr'), 'A');
    });

    test('falls back to the default locale when the code is absent', () {
      const item = MagicStarterReleaseItem(
        type: MagicStarterReleaseItemType.newFeature,
        text: {'en': 'A', 'tr': 'B'},
      );

      expect(item.textFor('de'), 'A');
    });

    test('honours a configured default locale', () {
      Config.set('magic_starter.defaults.locale', 'tr');
      const item = MagicStarterReleaseItem(
        type: MagicStarterReleaseItemType.improved,
        text: {'en': 'A', 'tr': 'B'},
      );

      expect(item.textFor('de'), 'B');
    });

    test('falls back to the first non-empty value', () {
      const item = MagicStarterReleaseItem(
        type: MagicStarterReleaseItemType.improved,
        text: {'en': '', 'tr': '', 'de': 'Hallo', 'fr': 'Salut'},
      );

      expect(item.textFor('es'), 'Hallo');
    });

    test('answers an empty string for an empty map', () {
      const item = MagicStarterReleaseItem(
        type: MagicStarterReleaseItemType.fixed,
        text: {},
      );

      expect(item.textFor('en'), '');
    });
  });

  group('MagicStarterRelease.fromJson', () {
    test('parses a full row', () {
      final release = MagicStarterRelease.fromJson(<String, dynamic>{
        'version': '1.1.0',
        'published_at': '2026-10-20T09:00:00.000000Z',
        'ios_build': 15,
        'android_build': 16,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'new',
            'text': <String, dynamic>{'en': 'Dark mode', 'tr': 'Koyu tema'},
          },
          <String, dynamic>{
            'type': 'fixed',
            'text': <String, dynamic>{'en': 'Crash', 'tr': 'Cokme'},
          },
        ],
      });

      expect(release.version, '1.1.0');
      expect(release.publishedAt, DateTime.utc(2026, 10, 20, 9));
      expect(release.iosBuild, 15);
      expect(release.androidBuild, 16);
      expect(release.items, hasLength(2));
      expect(release.items.first.type, MagicStarterReleaseItemType.newFeature);
      expect(release.items.first.text, {'en': 'Dark mode', 'tr': 'Koyu tema'});
      expect(release.items.last.type, MagicStarterReleaseItemType.fixed);
    });

    test('reads null builds and a missing date as null', () {
      final release = MagicStarterRelease.fromJson(<String, dynamic>{
        'version': '1.0.0',
        'published_at': null,
        'ios_build': null,
        'android_build': null,
        'items': <Map<String, dynamic>>[],
      });

      expect(release.publishedAt, isNull);
      expect(release.iosBuild, isNull);
      expect(release.androidBuild, isNull);
      expect(release.items, isEmpty);
    });

    test('skips an item with an unknown or missing type', () {
      final release = MagicStarterRelease.fromJson(<String, dynamic>{
        'version': '1.2.0',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'removed',
            'text': <String, dynamic>{'en': 'Gone'},
          },
          <String, dynamic>{
            'text': <String, dynamic>{'en': 'Typeless'},
          },
          <String, dynamic>{
            'type': 'improved',
            'text': <String, dynamic>{'en': 'Faster'},
          },
        ],
      });

      expect(release.items, hasLength(1));
      expect(release.items.single.type, MagicStarterReleaseItemType.improved);
    });

    test(
      'ignores non-string text values and tolerates a missing items key',
      () {
        final release = MagicStarterRelease.fromJson(<String, dynamic>{
          'version': '1.3.0',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'new',
              'text': <String, dynamic>{'en': 'Ok', 'tr': 42, 'de': null},
            },
          ],
        });

        expect(release.items.single.text, {'en': 'Ok'});

        final bare = MagicStarterRelease.fromJson(<String, dynamic>{
          'version': '1.4.0',
        });

        expect(bare.items, isEmpty);
      },
    );

    test('reads an unparseable date as null', () {
      final release = MagicStarterRelease.fromJson(<String, dynamic>{
        'version': '1.5.0',
        'published_at': 'not a date',
      });

      expect(release.publishedAt, isNull);
    });
  });

  group('MagicStarterReleaseFeed.fromJson', () {
    test('parses the full body', () {
      final feed = MagicStarterReleaseFeed.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'version': '1.1.0',
            'published_at': '2026-10-20T09:00:00.000000Z',
            'ios_build': 15,
            'android_build': 15,
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'new',
                'text': <String, dynamic>{'en': 'A', 'tr': 'B'},
              },
            ],
          },
          <String, dynamic>{'version': '1.0.0', 'items': <dynamic>[]},
        ],
        'meta': <String, dynamic>{
          'latest_build': <String, dynamic>{'ios': 15, 'android': 14},
        },
      });

      expect(feed.releases.map((r) => r.version), ['1.1.0', '1.0.0']);
      expect(feed.latestIosBuild, 15);
      expect(feed.latestAndroidBuild, 14);
    });

    test('reads null latest builds as null', () {
      final feed = MagicStarterReleaseFeed.fromJson(<String, dynamic>{
        'data': <dynamic>[],
        'meta': <String, dynamic>{
          'latest_build': <String, dynamic>{'ios': null, 'android': null},
        },
      });

      expect(feed.releases, isEmpty);
      expect(feed.latestIosBuild, isNull);
      expect(feed.latestAndroidBuild, isNull);
    });

    test('tolerates a missing meta and a missing data', () {
      final feed = MagicStarterReleaseFeed.fromJson(<String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'version': '1.0.0'},
        ],
      });

      expect(feed.releases, hasLength(1));
      expect(feed.latestIosBuild, isNull);
      expect(feed.latestAndroidBuild, isNull);

      final bare = MagicStarterReleaseFeed.fromJson(<String, dynamic>{});

      expect(bare.releases, isEmpty);
    });
  });
}
