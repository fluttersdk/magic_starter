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
/// ## Session memory
///
/// What the banner has learned lives for the app session, not for one mounted
/// banner: the check cooldown, the build on offer and a reveal still counting
/// down survive a remount (a layout swapping its body under hidden chrome, a
/// host rebuilding its layout). A remount shows an offered build at once,
/// restarts an unfinished reveal delay and checks only when the cooldown has
/// run out, so a remount never adds a request.
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

  /// Runs for [checkInterval] after a check starts; a resume or a mount while
  /// it runs is not due. A timer rather than a clock reading, so the interval
  /// follows the same time source as every other timer here. Shared by every
  /// banner and never cancelled by one being disposed.
  static Timer? _cooldown;

  /// The web build a reveal is counting down for, or was revealed for: a
  /// later check that sees it again neither restarts nor repeats the delay.
  static String? _announcedBuild;

  /// Whether the reveal of [_announcedBuild] has yet to fire. The countdown
  /// itself belongs to a mounted banner; the next one restarts it.
  static bool _revealPending = false;

  /// The build the banner is offering, or `null` while it is hidden.
  static final ValueNotifier<String?> _visibleBuild = ValueNotifier<String?>(
    null,
  );

  /// Where "Update" goes on a store install.
  static String? _storeUrl;

  /// Whether this mobile install was found unable to take a store update (a
  /// sideload, TestFlight, a missing App Store id): no banner checks again
  /// for the rest of the session.
  static bool _storeInert = false;

  /// Clears every test seam and the session memory, cancelling the cooldown.
  @visibleForTesting
  static void resetForTesting() {
    debugFetchDeployedBuild = null;
    debugReloadPage = null;
    debugLaunchUrl = null;

    _cooldown?.cancel();
    _cooldown = null;
    _announcedBuild = null;
    _revealPending = false;
    _visibleBuild.value = null;
    _storeUrl = null;
    _storeInert = false;
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
  bool _checking = false;

  @override
  void initState() {
    super.initState();

    // 1. Decide whether this run can be offered a build at all.
    _mode = _pickMode();
    if (_mode == _Mode.inert) return;

    _lifecycle = AppLifecycleListener(onResume: _checkIfDue);
    if (_mode == _Mode.web) {
      _poll = Timer.periodic(
        MagicStarterAppUpdateBanner.checkInterval,
        (_) => _check(),
      );
    }

    // 2. Finish a reveal an earlier banner was counting down for.
    final String? announced = MagicStarterAppUpdateBanner._announcedBuild;
    if (MagicStarterAppUpdateBanner._revealPending && announced != null) {
      _scheduleReveal(announced);
    }

    // 3. Check now only when the session has not checked recently.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkIfDue();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _reveal?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _Mode.inert) return const SizedBox.shrink();

    return ValueListenableBuilder<String?>(
      valueListenable: MagicStarterAppUpdateBanner._visibleBuild,
      builder: (context, build, _) {
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
      },
    );
  }

  /// Web on the web; iOS and Android only in a release build, since a debug or
  /// profile build is never the one a store would replace, and only until the
  /// session has found the install unable to take a store update.
  static _Mode _pickMode() {
    if (!MagicStarterConfig.hasAppUpdateFeatures()) return _Mode.inert;
    if (MagicStarterAppBuild.isWeb) return _Mode.web;

    final bool mobile =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    return mobile &&
            MagicStarterAppBuild.isReleaseMode &&
            !MagicStarterAppUpdateBanner._storeInert
        ? _Mode.mobile
        : _Mode.inert;
  }

  void _checkIfDue() {
    if (MagicStarterAppUpdateBanner._cooldown?.isActive ?? false) return;

    _check();
  }

  Future<void> _check() async {
    if (_mode == _Mode.inert || _checking) return;

    _checking = true;
    MagicStarterAppUpdateBanner._cooldown?.cancel();
    MagicStarterAppUpdateBanner._cooldown = Timer(
      MagicStarterAppUpdateBanner.checkInterval,
      () {},
    );

    try {
      if (_mode == _Mode.web) {
        await _checkWeb();
      } else {
        await _checkStore();
      }
    } catch (error, stackTrace) {
      Log.warning(
        '[MagicStarterAppUpdateBanner] check failed: $error\n$stackTrace',
      );
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
    if (running.isEmpty || deployed.isEmpty) return;

    // 2. A rollback to the running build leaves nothing newer to offer.
    if (running == deployed) {
      _withdraw();
      return;
    }

    // 3. A build already announced keeps its first reveal; one whose
    //    countdown ended with an earlier banner starts it again here.
    if (deployed == MagicStarterAppUpdateBanner._announcedBuild) {
      if (MagicStarterAppUpdateBanner._revealPending && _reveal == null) {
        _scheduleReveal(deployed);
      }
      return;
    }
    if (deployed == await _dismissedBuild()) return;

    // 4. Wait out a rollout before bothering anyone.
    MagicStarterAppUpdateBanner._announcedBuild = deployed;
    MagicStarterAppUpdateBanner._revealPending = true;
    _scheduleReveal(deployed);
  }

  /// Reveals [build] after [MagicStarterAppUpdateBanner.revealDelay]. The
  /// timer belongs to this banner; a disposed one leaves the reveal pending
  /// for the next.
  void _scheduleReveal(String build) {
    if (!mounted) return;

    _reveal?.cancel();
    _reveal = Timer(MagicStarterAppUpdateBanner.revealDelay, () {
      _reveal = null;
      MagicStarterAppUpdateBanner._revealPending = false;
      MagicStarterAppUpdateBanner._visibleBuild.value = build;
    });
  }

  /// Drops the announced build, a reveal counting down for it and a banner
  /// offering it.
  void _withdraw() {
    _reveal?.cancel();
    _reveal = null;
    MagicStarterAppUpdateBanner._announcedBuild = null;
    MagicStarterAppUpdateBanner._revealPending = false;
    MagicStarterAppUpdateBanner._visibleBuild.value = null;
  }

  Future<void> _checkStore() async {
    // 1. Only a store install can be replaced by the store's build; anything
    //    else stays quiet for the rest of the session.
    final PackageInfo? info = await MagicStarterAppBuild.info();
    if (info == null || !MagicStarterAppBuild.isStoreInstall(info)) {
      _goInert();
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
      _goInert();
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

    MagicStarterAppUpdateBanner._storeUrl = ios
        ? 'https://apps.apple.com/app/id$appStoreId'
        : 'https://play.google.com/store/apps/details?id=${info.packageName}';
    MagicStarterAppUpdateBanner._visibleBuild.value = build;
  }

  void _goInert() {
    MagicStarterAppUpdateBanner._storeInert = true;
    _mode = _Mode.inert;
  }

  Future<String?> _dismissedBuild() {
    return Vault.get(MagicStarterAppUpdateBanner.dismissedBuildKey);
  }

  void _reload() {
    (MagicStarterAppUpdateBanner.debugReloadPage ?? reloadPage)();
  }

  Future<void> _openStore() async {
    final String? url = MagicStarterAppUpdateBanner._storeUrl;
    if (url == null) return;

    final bool opened =
        await (MagicStarterAppUpdateBanner.debugLaunchUrl ?? Launch.url)(url);
    if (!opened) {
      Log.warning('[MagicStarterAppUpdateBanner] could not open $url');
    }
  }

  /// Hides the banner, then remembers [build] as declined, so only a newer one
  /// brings it back. Hidden first, so a remount during the write does not
  /// offer it again; a failed write still keeps it hidden for this session.
  Future<void> _dismiss(String build) async {
    MagicStarterAppUpdateBanner._visibleBuild.value = null;

    try {
      await Vault.put(MagicStarterAppUpdateBanner.dismissedBuildKey, build);
    } catch (error) {
      Log.warning('[MagicStarterAppUpdateBanner] dismissal not stored: $error');
    }
  }
}
