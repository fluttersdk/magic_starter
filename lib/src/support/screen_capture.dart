import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import '../configuration/magic_starter_config.dart';

/// Captures the screen a customer leaves for support, so a new conversation
/// can carry it as an `auto_screenshot` the customer previews first.
///
/// ## Once per entry, never continuously
///
/// [wrap] puts one [RepaintBoundary] around the app, and the capture runs only
/// when navigation crosses INTO a support route from outside it (the profile
/// menu's Support item, the billing screen's Contact sales, a host's own
/// link). At that moment the boundary still holds the last painted frame of
/// the screen being left, which is the screen the customer needs help with.
/// Moving between support routes captures nothing.
///
/// ## What is never captured
///
/// A screen on the starter's deny-list (profile, security, two-factor,
/// billing, teams) or on the host's `magic_starter.diagnostics.deny_capture_routes`,
/// and any screen with a dialog or popup over it: those carry passwords, codes,
/// cards and the questions a dialog asks. A refused capture also empties the
/// holder, so an older screenshot is never offered for a newer visit.
///
/// The bytes live in memory only ([holder]), are dropped on the next sign-in,
/// and leave the device only when the customer sends them.
class MagicStarterScreenCapture {
  MagicStarterScreenCapture._();

  static MagicStarterCapturedScreen _holder = MagicStarterCapturedScreen._();

  static MagicStarterPopupObserver _observer = MagicStarterPopupObserver._();

  static Future<void> _lastCapture = Future<void>.value();

  /// The screenshot waiting for the next new conversation.
  static MagicStarterCapturedScreen get holder => _holder;

  /// Tells whether a dialog or popup route is open. The support routes add it
  /// to the router when the diagnostics feature is on (see
  /// `registerMagicStarterSupportRoutes`).
  static MagicStarterPopupObserver get observer => _observer;

  /// Completes when the capture the last navigation started has settled.
  @visibleForTesting
  static Future<void> get debugCaptureSettled => _lastCapture;

  /// Wraps the app for capture; pass it the `child` of `MagicApplication`'s
  /// `builder`.
  ///
  /// ```dart
  /// MagicApplication(
  ///   builder: (context, child) => MagicStarterScreenCapture.wrap(child!),
  /// )
  /// ```
  static Widget wrap(Widget child) =>
      _MagicStarterCaptureBoundary(child: child);

  /// Whether [path] is a screen that must never be captured.
  ///
  /// An entry matches its own path and everything under it, segment by
  /// segment, and a `:param` or `*` segment matches any one segment: `/teams`
  /// covers `/teams/billing`, and `/reports/:id` covers `/reports/7/edit`.
  static bool isDenied(String path) {
    final segments = _segments(path);

    return _deniedRoutes().any((pattern) {
      final patternSegments = _segments(pattern);
      if (patternSegments.length > segments.length) return false;

      for (var i = 0; i < patternSegments.length; i++) {
        final expected = patternSegments[i];
        if (expected == '*' || expected.startsWith(':')) continue;
        if (expected != segments[i]) return false;
      }

      return true;
    });
  }

  /// Drops the held screenshot and the popup bookkeeping between tests.
  @visibleForTesting
  static void resetForTesting() {
    _holder = MagicStarterCapturedScreen._();
    _observer = MagicStarterPopupObserver._();
    _lastCapture = Future<void>.value();
  }

  static List<String> _deniedRoutes() {
    final profile = MagicStarterConfig.profilePrefix();

    return <String>[
      MagicStarterConfig.profileRoute(),
      '$profile/security',
      MagicStarterConfig.twoFactorChallengeRoute(),
      MagicStarterConfig.billingRoute(),
      MagicStarterConfig.teamsPrefix(),
      ...MagicStarterConfig.diagnosticsDenyCaptureRoutes(),
    ];
  }

  static List<String> _segments(String path) => <String>[
    for (final segment in path.split('/'))
      if (segment.isNotEmpty) segment,
  ];

  static bool _isSupport(String path) {
    final support = MagicStarterConfig.supportRoute();

    return path == support || path.startsWith('$support/');
  }
}

/// The screenshot captured on the way into support, with the path of the
/// screen it shows.
///
/// [SessionScoped]: a sign-in drops it, so one account never sees the screen
/// another account left.
class MagicStarterCapturedScreen implements SessionScoped {
  MagicStarterCapturedScreen._();

  Uint8List? _bytes;
  String? _route;

  /// Bumped by every new entry and every reset; a capture that finishes under
  /// an older value belongs to a visit that is already over.
  int _generation = 0;

  /// PNG bytes of the screen that was left, at logical size. Null when that
  /// screen may not be captured, or the customer removed it.
  Uint8List? get bytes => _bytes;

  /// The path (no query) of the screen that was left, kept even when its
  /// pixels were not.
  String? get route => _route;

  /// Removes the screenshot, keeping the route: the customer said no to the
  /// picture, not to the rest of the client info.
  void discard() => _bytes = null;

  /// Forgets everything, once a conversation carried it.
  void clear() {
    _generation++;
    _bytes = null;
    _route = null;
  }

  /// Seeds the holder as a capture would, for a screen test.
  @visibleForTesting
  void debugHold(Uint8List bytes, {required String route}) {
    _bytes = bytes;
    _route = route;
  }

  @override
  Future<void> resetForSession() async => clear();

  /// Starts a new visit from [route] with nothing captured yet.
  int _begin(String route) {
    clear();
    _route = route;

    return _generation;
  }

  void _complete(int generation, Uint8List bytes) {
    if (generation != _generation) return;

    _bytes = bytes;
  }
}

/// Counts the dialog and popup routes open on the navigator it observes.
class MagicStarterPopupObserver extends NavigatorObserver {
  MagicStarterPopupObserver._();

  final Set<Route<dynamic>> _open = <Route<dynamic>>{};

  /// Whether a dialog, bottom sheet or menu route is open.
  bool get hasPopup => _open.isNotEmpty;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _open.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _open.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _open.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _open.remove(oldRoute);
    if (newRoute is PopupRoute) _open.add(newRoute);
  }
}

class _MagicStarterCaptureBoundary extends StatefulWidget {
  const _MagicStarterCaptureBoundary({required this.child});

  final Widget child;

  @override
  State<_MagicStarterCaptureBoundary> createState() =>
      _MagicStarterCaptureBoundaryState();
}

class _MagicStarterCaptureBoundaryState
    extends State<_MagicStarterCaptureBoundary> {
  final GlobalKey _boundaryKey = GlobalKey();

  /// The router's delegate, which hears every navigation, including the ones
  /// inside a layout's nested navigator that a root observer never sees.
  late final Listenable _delegate;

  String _previousPath = '';

  @override
  void initState() {
    super.initState();

    final delegate = MagicRouter.instance.routerConfig.routerDelegate;
    _delegate = delegate;
    _previousPath = _currentPath();
    delegate.addListener(_onNavigated);
    SessionScope.register(MagicStarterScreenCapture.holder);
  }

  @override
  void dispose() {
    _delegate.removeListener(_onNavigated);
    SessionScope.unregister(MagicStarterScreenCapture.holder);
    super.dispose();
  }

  String _currentPath() {
    return MagicRouter
        .instance
        .routerConfig
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
  }

  /// Runs synchronously with the navigation, before the next frame paints the
  /// new screen, so the boundary still holds the one being left.
  void _onNavigated() {
    final previous = _previousPath;
    final next = _currentPath();
    _previousPath = next;

    if (!MagicStarterConfig.hasSupportDiagnosticsFeatures()) return;
    if (previous.isEmpty || !MagicStarterScreenCapture._isSupport(next)) return;
    if (MagicStarterScreenCapture._isSupport(previous)) return;

    MagicStarterScreenCapture._lastCapture = _capture(previous);
  }

  Future<void> _capture(String route) async {
    // 1. A new visit replaces whatever an older one held.
    final holder = MagicStarterScreenCapture.holder;
    final generation = holder._begin(route);

    // 2. Screens that may not be captured leave the holder empty.
    if (MagicStarterScreenCapture.isDenied(route)) return;
    if (MagicStarterScreenCapture.observer.hasPopup) return;

    // 3. A boundary with a paint pending holds no finished frame to read; in
    //    a release build the flag is always false and the last frame is read.
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) return;

    // 4. Encode. The capture is optional chrome, so a failure is logged and
    //    leaves the conversation without a screenshot rather than in error.
    try {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          holder._complete(generation, data.buffer.asUint8List());
        }
      } finally {
        image.dispose();
      }
    } catch (error) {
      Log.warning('[MagicStarterScreenCapture] capture failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: _boundaryKey, child: widget.child);
  }
}
