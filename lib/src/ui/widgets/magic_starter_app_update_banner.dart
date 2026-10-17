import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../configuration/magic_starter_config.dart';
import '../../http/controllers/magic_starter_releases_controller.dart';
import '../../support/app_build.dart';
import '../../support/web_deploy.dart';
import '../components/update_banner/update_banner.dart';

/// Tells the customer, without interrupting them, that a newer build of the app
/// is available, and offers to load it or to be reminded with the next one.
///
/// ## Where it looks
///
/// - **Web**: compares the running bundle's build number with the one the
///   server's `version.json` carries now. A difference is revealed
///   [revealDelay] after it is first seen, so a deploy still rolling out does
///   not flash the banner; the action reloads the page.
/// - **iOS and Android release builds installed from the store**: compares the
///   installed build number with the backend's latest store build
///   (`GET releases`), and shows at once; the action opens the store listing.
///   iOS needs [MagicStarterConfig.storeReviewAppStoreId] for that link and
///   stays hidden without it.
/// - **Anything else** (desktop, debug and profile builds, TestFlight,
///   sideloads, the feature off): renders nothing and starts nothing.
///
/// It checks once after mounting, on every resume at most once per
/// [checkInterval], and on the web also every [checkInterval]. "Later" stores
/// the offered build under [dismissedBuildKey], so the banner returns only for
/// a newer build. It never reloads on its own and never opens a dialog.
///
/// ## Failure mode
///
/// A check that cannot read a build (no network, a backend refusal, an
/// unreadable store) logs a warning and leaves the banner as it was; nothing
/// reaches the widget tree.
class MagicStarterAppUpdateBanner extends StatefulWidget {
  /// Creates a [MagicStarterAppUpdateBanner].
  const MagicStarterAppUpdateBanner({super.key});

  /// The least time between two checks, and the web's polling period.
  static const Duration checkInterval = Duration(minutes: 15);

  /// How long a newly deployed web build waits before it is revealed.
  static const Duration revealDelay = Duration(seconds: 60);

  /// The [Vault] key the build dismissed with "Later" is stored under.
  static const String dismissedBuildKey =
      'magic_starter.app_update.dismissed_build';

  /// Stands in for [fetchDeployedBuildNumber] in a test.
  @visibleForTesting
  static Future<String?> Function()? debugFetchDeployedBuild;

  /// Stands in for [reloadPage] in a test.
  @visibleForTesting
  static VoidCallback? debugReloadPage;

  /// Stands in for [Launch.url] in a test.
  @visibleForTesting
  static Future<bool> Function(String url)? debugLaunchUrl;

  /// Clears every test seam.
  @visibleForTesting
  static void resetForTesting() {
    debugFetchDeployedBuild = null;
    debugReloadPage = null;
    debugLaunchUrl = null;
  }

  @override
  State<MagicStarterAppUpdateBanner> createState() =>
      _MagicStarterAppUpdateBannerState();
}

/// Where a mounted banner looks for a newer build.
enum _Mode { inert, web, mobile }

class _MagicStarterAppUpdateBannerState
    extends State<MagicStarterAppUpdateBanner> {
  _Mode _mode = _Mode.inert;
  AppLifecycleListener? _lifecycle;
  Timer? _poll;
  Timer? _reveal;

  /// Runs for [MagicStarterAppUpdateBanner.checkInterval] after a check
  /// starts; a resume while it runs is not due. A timer rather than a clock
  /// reading, so the interval follows the same time source as every other
  /// timer here.
  Timer? _cooldown;

  bool _checking = false;

  /// The web build a reveal is counting down for, or was revealed for: a
  /// later check that sees it again neither restarts nor repeats the delay.
  String? _announcedBuild;

  /// The build the banner is offering, or `null` while it is hidden.
  String? _visibleBuild;

  /// Where "Update" goes on a store install.
  String? _storeUrl;

  @override
  void initState() {
    super.initState();

    _mode = _pickMode();
    if (_mode == _Mode.inert) return;

    _lifecycle = AppLifecycleListener(onResume: _checkIfDue);
    if (_mode == _Mode.web) {
      _poll = Timer.periodic(
        MagicStarterAppUpdateBanner.checkInterval,
        (_) => _check(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _reveal?.cancel();
    _cooldown?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? build = _visibleBuild;
    if (build == null) return const SizedBox.shrink();

    final bool web = _mode == _Mode.web;

    return MSUpdateBanner(
      message: trans(
        web
            ? 'magic_starter.app_update.message_web'
            : 'magic_starter.app_update.message_store',
      ),
      actionLabel: trans(
        web
            ? 'magic_starter.app_update.reload'
            : 'magic_starter.app_update.update',
      ),
      onAction: web ? _reload : _openStore,
      dismissLabel: trans('magic_starter.app_update.later'),
      onDismiss: () => _dismiss(build),
    );
  }

  /// Web on the web; iOS and Android only in a release build, since a debug or
  /// profile build is never the one a store would replace.
  static _Mode _pickMode() {
    if (!MagicStarterConfig.hasAppUpdateFeatures()) return _Mode.inert;
    if (MagicStarterAppBuild.isWeb) return _Mode.web;

    final bool mobile =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    return mobile && MagicStarterAppBuild.isReleaseMode
        ? _Mode.mobile
        : _Mode.inert;
  }

  void _checkIfDue() {
    if (_cooldown?.isActive ?? false) return;

    _check();
  }

  Future<void> _check() async {
    if (_mode == _Mode.inert || _checking) return;

    _checking = true;
    _cooldown?.cancel();
    _cooldown = Timer(MagicStarterAppUpdateBanner.checkInterval, () {});

    try {
      if (_mode == _Mode.web) {
        await _checkWeb();
      } else {
        await _checkStore();
      }
    } catch (error) {
      Log.warning('[MagicStarterAppUpdateBanner] check failed: $error');
    } finally {
      _checking = false;
    }
  }

  Future<void> _checkWeb() async {
    // 1. Both sides must name a build; an empty one is never a difference.
    final String running =
        (await MagicStarterAppBuild.info())?.buildNumber ?? '';
    final String deployed =
        await (MagicStarterAppUpdateBanner.debugFetchDeployedBuild ??
            fetchDeployedBuildNumber)() ??
        '';
    if (running.isEmpty || deployed.isEmpty || running == deployed) return;

    // 2. A build already counting down or on screen keeps its first reveal.
    if (deployed == _announcedBuild) return;
    if (deployed == await _dismissedBuild()) return;

    // 3. Wait out a rollout before bothering anyone.
    _announcedBuild = deployed;
    _reveal?.cancel();
    _reveal = Timer(MagicStarterAppUpdateBanner.revealDelay, () {
      _reveal = null;
      if (mounted) setState(() => _visibleBuild = deployed);
    });
  }

  Future<void> _checkStore() async {
    // 1. Only a store install can be replaced by the store's build; anything
    //    else stays quiet for the life of this banner.
    final PackageInfo? info = await MagicStarterAppBuild.info();
    if (info == null || !MagicStarterAppBuild.isStoreInstall(info)) {
      _mode = _Mode.inert;
      return;
    }

    // 2. iOS cannot link to its listing without the App Store id.
    final bool ios = defaultTargetPlatform == TargetPlatform.iOS;
    final String? appStoreId = MagicStarterConfig.storeReviewAppStoreId();
    if (ios && appStoreId == null) {
      Log.warning(
        '[MagicStarterAppUpdateBanner] magic_starter.store_review.app_store_id '
        'is not set; the iOS update banner stays hidden.',
      );
      _mode = _Mode.inert;
      return;
    }

    // 3. Compare build numbers; an unknown side is never "newer".
    final int? installed = int.tryParse(info.buildNumber);
    if (installed == null) return;

    final feed = await MagicStarterReleasesController.readFeed();
    final int? latest = ios ? feed?.latestIosBuild : feed?.latestAndroidBuild;
    if (latest == null || latest <= installed) return;

    final String build = '$latest';
    if (build == await _dismissedBuild()) return;

    _storeUrl = ios
        ? 'https://apps.apple.com/app/id$appStoreId'
        : 'https://play.google.com/store/apps/details?id=${info.packageName}';
    if (mounted) setState(() => _visibleBuild = build);
  }

  Future<String?> _dismissedBuild() {
    return Vault.get(MagicStarterAppUpdateBanner.dismissedBuildKey);
  }

  void _reload() {
    (MagicStarterAppUpdateBanner.debugReloadPage ?? reloadPage)();
  }

  Future<void> _openStore() async {
    final String? url = _storeUrl;
    if (url == null) return;

    final bool opened =
        await (MagicStarterAppUpdateBanner.debugLaunchUrl ?? Launch.url)(url);
    if (!opened) {
      Log.warning('[MagicStarterAppUpdateBanner] could not open $url');
    }
  }

  /// Remembers [build] as declined, so only a newer one brings the banner
  /// back, then hides it. A failed write still hides it for this session.
  Future<void> _dismiss(String build) async {
    try {
      await Vault.put(MagicStarterAppUpdateBanner.dismissedBuildKey, build);
    } catch (error) {
      Log.warning('[MagicStarterAppUpdateBanner] dismissal not stored: $error');
    }

    if (mounted) setState(() => _visibleBuild = null);
  }
}
