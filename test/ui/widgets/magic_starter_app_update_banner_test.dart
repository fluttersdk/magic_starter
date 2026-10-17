import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/support/app_build.dart';
import 'package:magic_starter/src/ui/widgets/magic_starter_app_update_banner.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The package's own English copy, so the banner renders real labels.
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

/// The semantic aliases the button recipe names, which a host app's theme
/// defines and wind's defaults do not.
const Map<String, String> _semanticAliases = <String, String>{
  'bg-primary': 'bg-primary-500',
  'text-on-primary': 'text-white',
  'bg-surface-container-high': 'bg-gray-200',
  'border-color-border': 'border-gray-300',
  'text-fg': 'text-gray-900',
  'text-fg-disabled': 'text-gray-400',
};

const Duration _interval = MagicStarterAppUpdateBanner.checkInterval;
const Duration _delay = MagicStarterAppUpdateBanner.revealDelay;
const String _dismissedKey = MagicStarterAppUpdateBanner.dismissedBuildKey;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLogManager log;
  late List<String> requests;
  late int fetches;
  late String? deployed;
  late int reloads;
  late List<String> launched;

  void installed({
    String buildNumber = '14',
    String? installerStore,
    String packageName = 'com.example.app',
  }) {
    PackageInfo.setMockInitialValues(
      appName: 'Example',
      packageName: packageName,
      version: '1.4.0',
      buildNumber: buildNumber,
      buildSignature: '',
      installerStore: installerStore,
    );
  }

  void releasesFeed({int? ios = 15, int? android = 15}) {
    Http.fake((request) {
      requests.add(request.url);

      return Http.response(<String, dynamic>{
        'data': <Object>[],
        'meta': <String, dynamic>{
          'latest_build': <String, dynamic>{'ios': ios, 'android': android},
        },
      });
    });
  }

  int releaseRequests() => requests.where((u) => u.contains('releases')).length;

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    log = Log.fake();
    Config.set('magic_starter.features.app_update', true);
    Vault.fake();

    requests = <String>[];
    fetches = 0;
    deployed = '15';
    reloads = 0;
    launched = <String>[];
    releasesFeed();
    installed();

    MagicStarterAppBuild.resetForTesting();
    MagicStarterAppUpdateBanner.resetForTesting();
    MagicStarterAppUpdateBanner.debugFetchDeployedBuild = () async {
      fetches++;

      return deployed;
    };
    MagicStarterAppUpdateBanner.debugReloadPage = () => reloads++;
    MagicStarterAppUpdateBanner.debugLaunchUrl = (url) async {
      launched.add(url);

      return true;
    };

    Translator.instance.setLoader(const _ShippedLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    MagicStarterAppUpdateBanner.resetForTesting();
    MagicStarterAppBuild.resetForTesting();
    Http.unfake();
    Vault.unfake();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(
            colors: <String, MaterialColor>{'primary': Colors.green},
            aliases: _semanticAliases,
          ),
          child: const Scaffold(body: MagicStarterAppUpdateBanner()),
        ),
      ),
    );
    await tester.pump();
  }

  /// Unmounts the banner, then runs the clock past every timer it could have
  /// started: a callback reaching a disposed state, or a timer left pending,
  /// fails the test.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(_interval * 2 + _delay);
    debugDefaultTargetPlatformOverride = null;
  }

  /// Drives a full background-and-back round trip through the only legal
  /// lifecycle path `AppLifecycleListener` accepts.
  Future<void> resume(WidgetTester tester) async {
    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
  }

  final Finder reload = find.text('Reload');
  final Finder later = find.text('Later');
  final Finder update = find.text('Update');

  group('web', () {
    setUp(() {
      MagicStarterAppBuild.debugIsWebOverride = true;
    });

    testWidgets('reveals a new deploy 60 seconds after detecting it', (
      tester,
    ) async {
      await mount(tester);

      await tester.pump(const Duration(seconds: 59));
      expect(reload, findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(reload, findsOneWidget);
      expect(
        find.text('A new version of the app is available.'),
        findsOneWidget,
      );
      expect(fetches, 1);

      await finish(tester);
    });

    testWidgets('stays hidden while the deployed build is the running one', (
      tester,
    ) async {
      deployed = '14';

      await mount(tester);
      await tester.pump(_delay * 2);

      expect(reload, findsNothing);
      await finish(tester);
    });

    testWidgets('stays hidden when the deployed build is unknown', (
      tester,
    ) async {
      deployed = '';
      await mount(tester);
      await tester.pump(_delay * 2);
      expect(reload, findsNothing);

      deployed = null;
      await tester.pump(_interval);
      await tester.pump(_delay * 2);
      expect(fetches, 2);
      expect(reload, findsNothing);

      await finish(tester);
    });

    testWidgets('Later stores the build and hides the banner', (tester) async {
      await mount(tester);
      await tester.pump(_delay);
      expect(reload, findsOneWidget);

      await tester.tap(later);
      await tester.pump();

      expect(await Vault.get(_dismissedKey), '15');
      expect(reload, findsNothing);
      expect(reloads, 0);

      await tester.pump(_interval + _delay);
      expect(reload, findsNothing);

      await finish(tester);
    });

    testWidgets('a stored dismissal keeps that build hidden', (tester) async {
      await Vault.put(_dismissedKey, '15');

      await mount(tester);
      await tester.pump(_delay * 2);

      expect(reload, findsNothing);
      await finish(tester);
    });

    testWidgets('a newer build after a dismissal shows again', (tester) async {
      await Vault.put(_dismissedKey, '15');
      await mount(tester);
      await tester.pump(_delay);
      expect(reload, findsNothing);

      deployed = '16';
      await tester.pump(_interval - _delay);
      expect(fetches, 2);
      await tester.pump(_delay);

      expect(reload, findsOneWidget);
      await finish(tester);
    });

    testWidgets('Reload reloads the page once', (tester) async {
      await mount(tester);
      await tester.pump(_delay);

      await tester.tap(reload);
      await tester.pump();

      expect(reloads, 1);
      await finish(tester);
    });

    testWidgets('a later check of the same build keeps the banner up', (
      tester,
    ) async {
      await mount(tester);
      await tester.pump(_delay);
      expect(reload, findsOneWidget);

      await tester.pump(_interval);
      expect(fetches, 2);
      expect(reload, findsOneWidget);

      await finish(tester);
    });

    testWidgets('a resume within 15 minutes does not check again', (
      tester,
    ) async {
      deployed = '14';
      await mount(tester);
      expect(fetches, 1);

      await tester.pump(const Duration(minutes: 5));
      await resume(tester);

      expect(fetches, 1);
      await finish(tester);
    });

    testWidgets('the periodic check picks up a deploy after 15 minutes', (
      tester,
    ) async {
      deployed = '14';
      await mount(tester);
      await tester.pump(_delay);
      expect(reload, findsNothing);

      deployed = '15';
      await tester.pump(_interval - _delay);
      expect(fetches, 2);
      expect(reload, findsNothing);

      await tester.pump(_delay);
      expect(reload, findsOneWidget);

      await finish(tester);
    });

    testWidgets('a resume after 15 minutes checks again', (tester) async {
      // A remount restarts the polling period but not the session cooldown,
      // so the cooldown runs out before the next poll and only the resume can
      // be the check.
      deployed = '14';
      await mount(tester);
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
      await mount(tester);
      expect(fetches, 1);

      await tester.pump(const Duration(minutes: 10));
      expect(fetches, 1);

      await resume(tester);
      expect(fetches, 2);

      await finish(tester);
    });

    testWidgets('a remount shows a revealed build at once without a fetch', (
      tester,
    ) async {
      await mount(tester);
      await tester.pump(_delay);
      expect(reload, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await mount(tester);

      expect(reload, findsOneWidget);
      expect(fetches, 1);
      await finish(tester);
    });

    testWidgets('a remount during the reveal delay waits a fresh delay', (
      tester,
    ) async {
      await mount(tester);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpWidget(const SizedBox());

      await mount(tester);
      await tester.pump(_delay - const Duration(seconds: 1));
      expect(reload, findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(reload, findsOneWidget);
      expect(fetches, 1);
      await finish(tester);
    });

    testWidgets('a rollback to the running build hides the banner', (
      tester,
    ) async {
      await mount(tester);
      await tester.pump(_delay);
      expect(reload, findsOneWidget);

      deployed = '14';
      await tester.pump(_interval - _delay);
      expect(fetches, 2);
      expect(reload, findsNothing);

      // The same build deployed again is a new deploy: it waits its delay.
      deployed = '15';
      await tester.pump(_interval);
      expect(fetches, 3);
      expect(reload, findsNothing);

      await tester.pump(_delay);
      expect(reload, findsOneWidget);
      await finish(tester);
    });

    testWidgets('a rollback cancels a reveal still counting down', (
      tester,
    ) async {
      await mount(tester);
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpWidget(const SizedBox());

      deployed = '14';
      await tester.pump(_interval);
      await mount(tester);
      expect(fetches, 2);

      await tester.pump(_delay * 2);
      expect(reload, findsNothing);
      await finish(tester);
    });

    testWidgets('a failed check logs the error with its stack trace', (
      tester,
    ) async {
      MagicStarterAppUpdateBanner.debugFetchDeployedBuild = () async {
        throw StateError('offline');
      };

      await mount(tester);

      final warnings = log.entries.where(
        (e) => e.level == 'warning' && e.message.contains('check failed'),
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('offline'));
      expect(
        warnings.single.message,
        contains('magic_starter_app_update_banner_test.dart'),
      );
      expect(reload, findsNothing);
      await finish(tester);
    });

    testWidgets('unmounting during the reveal delay leaves no timer', (
      tester,
    ) async {
      await mount(tester);
      await tester.pump(const Duration(seconds: 30));

      await finish(tester);
      expect(fetches, 1);
    });
  });

  group('mobile', () {
    setUp(() {
      MagicStarterAppBuild.debugIsWebOverride = false;
      MagicStarterAppBuild.debugReleaseModeOverride = true;
      Config.set('magic_starter.store_review.app_store_id', '123');
    });

    testWidgets('an App Store install sees a newer store build at once', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      installed(installerStore: 'com.apple');

      await mount(tester);

      expect(update, findsOneWidget);
      expect(
        find.text('A new version is available in the store.'),
        findsOneWidget,
      );
      expect(fetches, 0);

      await tester.tap(update);
      await tester.pump();

      expect(launched, <String>['https://apps.apple.com/app/id123']);
      await finish(tester);
    });

    testWidgets('Later hides the store build until a newer one ships', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      installed(installerStore: 'com.apple');

      await mount(tester);
      await tester.tap(later);
      await tester.pump();

      expect(await Vault.get(_dismissedKey), '15');
      expect(update, findsNothing);

      await tester.pump(_interval);
      await resume(tester);
      expect(releaseRequests(), 2);
      expect(update, findsNothing);

      releasesFeed(ios: 16);
      await tester.pump(_interval);
      await resume(tester);
      expect(update, findsOneWidget);

      await finish(tester);
    });

    testWidgets('checks on resume at most once per 15 minutes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      installed(installerStore: 'com.apple');

      await mount(tester);
      expect(releaseRequests(), 1);

      await tester.pump(const Duration(minutes: 14));
      await resume(tester);
      expect(releaseRequests(), 1);

      await tester.pump(const Duration(minutes: 1));
      await resume(tester);
      expect(releaseRequests(), 2);

      await finish(tester);
    });

    testWidgets('a remount within 15 minutes asks the backend once', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      installed(installerStore: 'com.apple');

      await mount(tester);
      expect(releaseRequests(), 1);
      expect(update, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 5));
      await mount(tester);
      expect(releaseRequests(), 1);
      expect(update, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 10));
      await mount(tester);
      expect(releaseRequests(), 2);
      expect(update, findsOneWidget);

      await finish(tester);
    });

    testWidgets('starts no periodic check', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      installed(installerStore: 'com.apple');

      await mount(tester);
      await tester.pump(_interval * 3);

      expect(releaseRequests(), 1);
      await finish(tester);
    });

    final Map<String, void Function()> hiddenOnIos = <String, void Function()>{
      'TestFlight': () => installed(installerStore: 'com.apple.testflight'),
      'the simulator': () => installed(installerStore: 'com.apple.simulator'),
      'a debug build': () {
        installed(installerStore: 'com.apple');
        MagicStarterAppBuild.debugReleaseModeOverride = false;
      },
      'no App Store id': () {
        installed(installerStore: 'com.apple');
        Config.set('magic_starter.store_review.app_store_id', null);
      },
      'no latest build': () {
        installed(installerStore: 'com.apple');
        releasesFeed(ios: null);
      },
      'a non-numeric installed build': () {
        installed(installerStore: 'com.apple', buildNumber: '1.4.0-rc');
      },
      'the same build': () {
        installed(installerStore: 'com.apple', buildNumber: '15');
      },
    };

    for (final MapEntry<String, void Function()> entry in hiddenOnIos.entries) {
      testWidgets('stays hidden on iOS for ${entry.key}', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        entry.value();

        await mount(tester);
        await tester.pump(_delay);

        expect(update, findsNothing);
        await finish(tester);
      });
    }

    testWidgets('warns once when the App Store id is missing', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      installed(installerStore: 'com.apple');
      Config.set('magic_starter.store_review.app_store_id', null);

      await mount(tester);
      await tester.pump(_interval);
      await resume(tester);

      final warnings = log.entries.where(
        (e) => e.level == 'warning' && e.message.contains('app_store_id'),
      );
      expect(warnings, hasLength(1));
      expect(update, findsNothing);

      await finish(tester);
    });

    testWidgets('a Play install opens the Play listing of this package', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      installed(
        installerStore: 'com.android.vending',
        packageName: 'com.example.uptime',
      );

      await mount(tester);
      await tester.tap(update);
      await tester.pump();

      expect(launched, <String>[
        'https://play.google.com/store/apps/details?id=com.example.uptime',
      ]);
      await finish(tester);
    });

    testWidgets('a sideloaded Android build never asks the backend', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      installed();

      await mount(tester);
      await tester.pump(_interval);
      await resume(tester);

      expect(update, findsNothing);
      expect(releaseRequests(), 0);
      await finish(tester);
    });
  });

  testWidgets('a desktop build starts nothing', (tester) async {
    MagicStarterAppBuild.debugIsWebOverride = false;
    MagicStarterAppBuild.debugReleaseModeOverride = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    installed(installerStore: 'com.apple');

    await mount(tester);
    await tester.pump(_interval);
    await resume(tester);

    expect(fetches, 0);
    expect(requests, isEmpty);
    await finish(tester);
  });

  testWidgets('the feature off renders nothing and asks nothing', (
    tester,
  ) async {
    Config.set('magic_starter.features.app_update', false);
    MagicStarterAppBuild.debugIsWebOverride = true;

    await mount(tester);
    await tester.pump(_interval + _delay);
    await resume(tester);

    expect(
      find.descendant(
        of: find.byType(MagicStarterAppUpdateBanner),
        matching: find.byType(SizedBox),
      ),
      findsOneWidget,
    );
    expect(reload, findsNothing);
    expect(fetches, 0);
    expect(requests, isEmpty);
    await finish(tester);
  });
}
