import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/src/support/app_build.dart';
import 'package:magic_starter/src/support/web_deploy.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo _package({
  String version = '1.4.0',
  String buildNumber = '27',
  String? installerStore,
}) {
  return PackageInfo(
    appName: 'Uptizm',
    packageName: 'com.example.app',
    version: version,
    buildNumber: buildNumber,
    installerStore: installerStore,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    MagicStarterAppBuild.resetForTesting();
  });

  tearDown(() {
    MagicStarterAppBuild.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
  });

  group('label', () {
    test('joins version and build with a middle dot on the web', () {
      MagicStarterAppBuild.debugIsWebOverride = true;

      expect(MagicStarterAppBuild.label(_package()), '1.4.0 · 27');
    });

    test('is just the version on the web when the build is empty', () {
      MagicStarterAppBuild.debugIsWebOverride = true;

      expect(MagicStarterAppBuild.label(_package(buildNumber: '')), '1.4.0');
    });

    test('wraps the build in parentheses on mobile', () {
      MagicStarterAppBuild.debugIsWebOverride = false;

      expect(MagicStarterAppBuild.label(_package()), '1.4.0 (27)');
    });

    test('is just the version on mobile when the build is empty', () {
      MagicStarterAppBuild.debugIsWebOverride = false;

      expect(MagicStarterAppBuild.label(_package(buildNumber: '')), '1.4.0');
    });
  });

  group('isStoreInstall', () {
    test('is true for an App Store install on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(
        MagicStarterAppBuild.isStoreInstall(
          _package(installerStore: 'com.apple'),
        ),
        isTrue,
      );
    });

    test('is false for a TestFlight install on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(
        MagicStarterAppBuild.isStoreInstall(
          _package(installerStore: 'com.apple.testflight'),
        ),
        isFalse,
      );
    });

    test('is false for a simulator install on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(
        MagicStarterAppBuild.isStoreInstall(
          _package(installerStore: 'com.apple.simulator'),
        ),
        isFalse,
      );
    });

    test('is true for a Play Store install on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(
        MagicStarterAppBuild.isStoreInstall(
          _package(installerStore: 'com.android.vending'),
        ),
        isTrue,
      );
    });

    test('is false for a sideloaded Android install', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(MagicStarterAppBuild.isStoreInstall(_package()), isFalse);
    });

    test('is false on macOS whatever the installer says', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      expect(
        MagicStarterAppBuild.isStoreInstall(
          _package(installerStore: 'com.apple'),
        ),
        isFalse,
      );
    });
  });

  group('platform seams', () {
    test('isWeb follows the override and falls back to kIsWeb', () {
      expect(MagicStarterAppBuild.isWeb, kIsWeb);

      MagicStarterAppBuild.debugIsWebOverride = true;
      expect(MagicStarterAppBuild.isWeb, isTrue);

      MagicStarterAppBuild.resetForTesting();
      expect(MagicStarterAppBuild.isWeb, kIsWeb);
    });

    test(
      'isReleaseMode follows the override and falls back to kReleaseMode',
      () {
        expect(MagicStarterAppBuild.isReleaseMode, kReleaseMode);

        MagicStarterAppBuild.debugReleaseModeOverride = true;
        expect(MagicStarterAppBuild.isReleaseMode, isTrue);

        MagicStarterAppBuild.resetForTesting();
        expect(MagicStarterAppBuild.isReleaseMode, kReleaseMode);
      },
    );
  });

  group('info and prime', () {
    test('info returns the values the platform reports', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Uptizm',
        packageName: 'com.example.app',
        version: '2.0.1',
        buildNumber: '31',
        buildSignature: '',
        installerStore: 'com.android.vending',
      );

      final PackageInfo? info = await MagicStarterAppBuild.info();

      expect(info, isNotNull);
      expect(info!.version, '2.0.1');
      expect(info.buildNumber, '31');
      expect(info.installerStore, 'com.android.vending');
    });

    test('prime reads the platform once so the build is cached', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Uptizm',
        packageName: 'com.example.app',
        version: '2.0.1',
        buildNumber: '31',
        buildSignature: '',
      );

      await MagicStarterAppBuild.prime();

      expect((await MagicStarterAppBuild.info())?.buildNumber, '31');
    });
  });

  group('web deploy stub', () {
    test('fetchDeployedBuildNumber answers null off the web', () async {
      expect(await fetchDeployedBuildNumber(), isNull);
    });
  });
}
