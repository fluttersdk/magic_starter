import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The package's own English copy, so the page renders real prose.
class _ShippedLoader implements TranslationLoader {
  const _ShippedLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final raw = File(
      '${Directory.current.path}/assets/stubs/install/en.stub',
    ).readAsStringSync();

    return _flatten(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = <String, dynamic>{};

    for (final MapEntry<String, dynamic> entry in json.entries) {
      final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';

      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }

    return result;
  }
}

Map<String, dynamic> _feed() {
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
          <String, dynamic>{
            'type': 'improved',
            'text': <String, dynamic>{'en': 'Faster charts'},
          },
        ],
      },
      <String, dynamic>{
        'version': '1.0.0',
        'published_at': null,
        'ios_build': null,
        'android_build': null,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'fixed',
            'text': <String, dynamic>{'en': 'Login redirect'},
          },
        ],
      },
    ],
    'meta': <String, dynamic>{
      'latest_build': <String, dynamic>{'ios': 15, 'android': 15},
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    MagicStarterAppBuild.resetForTesting();
    setUpMagicStarterForTests();

    Magic.singleton('log', () => LogManager());
    Config.set('logging', <String, dynamic>{
      'default': 'console',
      'channels': <String, dynamic>{
        'console': <String, dynamic>{'driver': 'console', 'level': 'debug'},
      },
    });
    Config.set('app.timezone', 'UTC');
    Log.fake();

    PackageInfo.setMockInitialValues(
      appName: 'Uptizm',
      packageName: 'com.example.app',
      version: '1.2.0',
      buildNumber: '34',
      buildSignature: '',
    );
    MagicStarterAppBuild.debugIsWebOverride = false;

    Translator.instance.setLoader(const _ShippedLoader());
    await Translator.instance.setLocale(const Locale('en'));

    Magic.put(MagicStarterReleasesController());
  });

  tearDown(() {
    Log.unfake();
    Http.unfake();
    MagicStarterAppBuild.resetForTesting();
    MagicApp.reset();
    Magic.flush();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(aliases: MagicStarterTokens.defaultAliases),
          child: const Scaffold(body: MagicStarterChangelogView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MagicStarterChangelogView', () {
    testWidgets('fetches the feed when it opens', (tester) async {
      final fake = Http.fake((request) => Http.response(_feed()));

      await mount(tester);

      fake.assertSentCount(1);
    });

    testWidgets('titles the page and shows the version caption on top', (
      tester,
    ) async {
      Http.fake((request) => Http.response(_feed()));

      await mount(tester);

      expect(find.text("What's new"), findsOneWidget);
      expect(find.byType(MagicStarterAppVersion), findsOneWidget);
      expect(find.text('Version 1.2.0 (34)'), findsOneWidget);
    });

    testWidgets('shows a skeleton while the feed is loading', (tester) async {
      Http.fake((request) => Http.response(_feed()));

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: WindTheme(
            data: WindThemeData(aliases: MagicStarterTokens.defaultAliases),
            child: const Scaffold(body: MagicStarterChangelogView()),
          ),
        ),
      );

      expect(find.byType(MSSkeleton), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.byType(MSSkeleton), findsNothing);
    });

    testWidgets('renders one card per release with badges and copy', (
      tester,
    ) async {
      Http.fake((request) => Http.response(_feed()));

      await mount(tester);

      expect(find.byType(MSCard), findsNWidgets(2));
      expect(find.text('1.1.0'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.text('Dark mode'), findsOneWidget);
      expect(find.text('Faster charts'), findsOneWidget);
      expect(find.text('Login redirect'), findsOneWidget);
      expect(find.widgetWithText(WBadge, 'New'), findsOneWidget);
      expect(find.widgetWithText(WBadge, 'Improved'), findsOneWidget);
      expect(find.widgetWithText(WBadge, 'Fixed'), findsOneWidget);
    });

    testWidgets('tones each badge by the kind of change', (tester) async {
      Http.fake((request) => Http.response(_feed()));

      await mount(tester);

      final Map<String, BadgeTone> tones = <String, BadgeTone>{
        for (final MSBadge badge in tester.widgetList<MSBadge>(
          find.byType(MSBadge),
        ))
          badge.label: badge.tone,
      };

      expect(tones, <String, BadgeTone>{
        'New': BadgeTone.primary,
        'Improved': BadgeTone.accent,
        'Fixed': BadgeTone.success,
      });
    });

    testWidgets('shows the date only for a release that has one', (
      tester,
    ) async {
      Http.fake((request) => Http.response(_feed()));

      await mount(tester);

      final String date = Carbon.fromDateTime(
        DateTime.parse('2026-10-20T09:00:00.000000Z'),
      ).toFormattedDateString();

      expect(find.text(date), findsOneWidget);
    });

    testWidgets('shows a release near midnight UTC on the reader local day', (
      tester,
    ) async {
      const String instant = '2026-10-20T23:30:00.000000Z';
      final Map<String, dynamic> feed = _feed();
      ((feed['data'] as List<Map<String, dynamic>>).first)['published_at'] =
          instant;
      Http.fake((request) => Http.response(feed));

      await mount(tester);

      final String date = Carbon.fromDateTime(
        DateTime.parse(instant).toLocal(),
      ).toFormattedDateString();

      expect(find.text(date), findsOneWidget);
    });

    testWidgets('picks the reader language, falling back to the default', (
      tester,
    ) async {
      await Translator.instance.setLocale(const Locale('tr'));
      Http.fake((request) => Http.response(_feed()));

      await mount(tester);

      // The tr copy where the backend sent one...
      expect(find.text('Koyu tema'), findsOneWidget);
      expect(find.text('Dark mode'), findsNothing);
      // ...and the en copy for an item that has no tr entry.
      expect(find.text('Faster charts'), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no releases', (
      tester,
    ) async {
      Http.fake((request) {
        return Http.response(<String, dynamic>{'data': <dynamic>[]});
      });

      await mount(tester);

      expect(find.byType(MSEmptyState), findsOneWidget);
      expect(find.text('No releases yet'), findsOneWidget);
      expect(
        find.text('Release notes appear here when a new version ships.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the error state and retries the read', (tester) async {
      bool failing = true;
      final fake = Http.fake((request) {
        return failing
            ? Http.response(<String, dynamic>{}, 500)
            : Http.response(_feed());
      });

      await mount(tester);

      expect(find.byType(MSErrorState), findsOneWidget);
      expect(find.text('Release notes could not be loaded.'), findsOneWidget);
      fake.assertSentCount(1);

      failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      fake.assertSentCount(2);
      expect(find.byType(MSErrorState), findsNothing);
      expect(find.text('Dark mode'), findsOneWidget);
    });
  });
}
