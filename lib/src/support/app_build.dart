import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        defaultTargetPlatform,
        kIsWeb,
        kReleaseMode,
        visibleForTesting;
import 'package:magic/magic.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The build this app is running: its version, its build number and where it
/// was installed from.
///
/// One read of the platform's package info for the whole package: the support
/// conversation's client context, the version caption and the update banner all
/// go through [info], so none of them reads it a second way.
///
/// ## Failure mode
///
/// A platform that cannot answer is logged and read as `null`; a caller leaves
/// its field out or stays quiet. Nothing here throws into the widget tree.
class MagicStarterAppBuild {
  MagicStarterAppBuild._();

  /// The installer id of an App Store install on iOS.
  static const String _appStoreInstaller = 'com.apple';

  /// The installer id of a Play Store install on Android.
  static const String _playStoreInstaller = 'com.android.vending';

  /// Stands in for `kIsWeb` in a test, which always runs on a host VM.
  @visibleForTesting
  static bool? debugIsWebOverride;

  /// Stands in for `kReleaseMode` in a test, which never runs a release build.
  @visibleForTesting
  static bool? debugReleaseModeOverride;

  /// Whether this run is the web build.
  static bool get isWeb => debugIsWebOverride ?? kIsWeb;

  /// Whether this run is a release build.
  static bool get isReleaseMode => debugReleaseModeOverride ?? kReleaseMode;

  /// The package info of the running build, or `null` when the platform cannot
  /// read it.
  ///
  /// `PackageInfo.fromPlatform()` caches per process, and this adds no cache of
  /// its own so that `PackageInfo.setMockInitialValues` keeps working in tests.
  static Future<PackageInfo?> info() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (error) {
      Log.warning('[MagicStarterAppBuild] package info: $error');

      return null;
    }
  }

  /// Reads the package info once, early.
  ///
  /// On the web call this at boot so the cached build is the one the running
  /// bundle shipped with: package_info_plus reads `version.json` once, and a
  /// later first read could see a newer deploy and report the new build as the
  /// running one.
  static Future<void> prime() async {
    await info();
  }

  /// The caption for a build: `1.4.0 · 27` on the web, `1.4.0 (27)` elsewhere,
  /// and just the version when the build number is empty.
  static String label(PackageInfo info) {
    if (info.buildNumber.isEmpty) return info.version;

    return isWeb
        ? '${info.version} · ${info.buildNumber}'
        : '${info.version} (${info.buildNumber})';
  }

  /// Whether [info] describes an install from the platform's own store: the App
  /// Store on iOS (not TestFlight, not the simulator) or Google Play on
  /// Android. Every other platform and installer is `false`.
  static bool isStoreInstall(PackageInfo info) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => info.installerStore == _appStoreInstaller,
      TargetPlatform.android => info.installerStore == _playStoreInstaller,
      _ => false,
    };
  }

  /// Clears both overrides between tests.
  @visibleForTesting
  static void resetForTesting() {
    debugIsWebOverride = null;
    debugReleaseModeOverride = null;
  }
}
