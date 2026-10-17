import 'dart:math' show max;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Where a layout's bottom nav learns which pages want it gone.
///
/// A layout places this at its own root, so it is an ancestor of both the bar
/// (rendered through a [MagicStarterBottomNavSlot]) and the routed child, and
/// a [MagicStarterHideBottomNav] page anywhere under that child can reach it.
///
/// It lives inside each layout rather than around it: magic tells two shells
/// apart by the layout widget's runtime type, and a shared outer wrapper would
/// make every layout look alike.
///
/// ```dart
/// return MagicStarterBottomNavScope(
///   child: Column(
///     children: [
///       Expanded(child: child),
///       MagicStarterBottomNavSlot(child: BottomNav()),
///     ],
///   ),
/// );
/// ```
class MagicStarterBottomNavScope extends StatefulWidget {
  /// Creates the scope for one layout.
  const MagicStarterBottomNavScope({super.key, required this.child});

  /// The layout: its bottom bar and its routed child.
  final Widget child;

  /// How much of the bottom nav is showing, from `0` (gone) to `1` (whole).
  ///
  /// `1` with no scope above [context]. Rebuilds [context] on every frame of a
  /// transition that moves the bar, which is what a layout needs to hand the
  /// collapsed bar's share of the bottom inset back to its content.
  static double visibilityOf(BuildContext context) {
    final _BottomNavScopeMarker? marker = context
        .dependOnInheritedWidgetOfExactType<_BottomNavScopeMarker>();

    return marker?.notifier?.visibility ?? 1;
  }

  @override
  State<MagicStarterBottomNavScope> createState() =>
      _MagicStarterBottomNavScopeState();
}

class _MagicStarterBottomNavScopeState
    extends State<MagicStarterBottomNavScope> {
  final _HidingRoutes _routes = _HidingRoutes();

  @override
  void dispose() {
    _routes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BottomNavScopeMarker(routes: _routes, child: widget.child);
  }
}

/// Hides the phone bottom nav while the page it wraps is on screen, in step
/// with that page's route transition.
///
/// Wrap the PAGE, not the layout: the page registers its own `ModalRoute`
/// with the nearest [MagicStarterBottomNavScope], and the bar collapses as
/// that route animates in and returns as it animates out, an iOS back swipe
/// included. A route pushed over it brings the bar back the same way. With no
/// scope above it, it does nothing.
///
/// ```dart
/// MagicRoute.page(
///   '/chat/:id',
///   () => MagicStarterHideBottomNav(child: ChatView()),
/// ).stacked();
/// ```
///
/// A route-based flag cannot do this, because go_router reports the new route
/// at the START of a pop and the bar would jump back before the page has left.
class MagicStarterHideBottomNav extends StatefulWidget {
  /// Creates a [MagicStarterHideBottomNav] around one page.
  const MagicStarterHideBottomNav({super.key, required this.child});

  /// The page.
  final Widget child;

  @override
  State<MagicStarterHideBottomNav> createState() =>
      _MagicStarterHideBottomNavState();
}

class _MagicStarterHideBottomNavState extends State<MagicStarterHideBottomNav> {
  _HidingRoutes? _routes;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // The scope is looked up without a dependency, since depending on it
    // would rebuild the page on every frame the bar moves. `ModalRoute.of` is
    // the dependency that brings this method back after a reparent.
    final _HidingRoutes? routes = context
        .getInheritedWidgetOfExactType<_BottomNavScopeMarker>()
        ?.notifier;
    final ModalRoute<Object?>? route = ModalRoute.of(context);

    if (identical(routes, _routes) && identical(route, _route)) return;

    _unregister();

    if (routes == null || route == null) return;

    routes.add(route);
    _routes = routes;
    _route = route;
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  void _unregister() {
    _routes?.remove(_route!);
    _routes = null;
    _route = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The layout's bottom nav, collapsed by the pages that hide it.
///
/// Its height is the child's times [MagicStarterBottomNavScope.visibilityOf],
/// so in a Column, or as a Scaffold's `bottomNavigationBar`, the content
/// above grows continuously into the room it gives up. Fully collapsed, the
/// bar keeps its state but takes no focus, taps or semantics. With no scope
/// above it, the child shows whole.
class MagicStarterBottomNavSlot extends StatelessWidget {
  /// Creates the slot around the bottom nav [child].
  const MagicStarterBottomNavSlot({super.key, required this.child});

  /// The bottom nav.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double visibility = MagicStarterBottomNavScope.visibilityOf(context);

    return Visibility(
      visible: visibility > 0,
      maintainState: true,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: visibility,
          child: child,
        ),
      ),
    );
  }
}

/// Hands [_HidingRoutes] to the slot (as a dependency) and to the pages
/// (without one).
class _BottomNavScopeMarker extends InheritedNotifier<_HidingRoutes> {
  const _BottomNavScopeMarker({
    required _HidingRoutes routes,
    required super.child,
  }) : super(notifier: routes);
}

/// The routes whose pages hide the bar, and the visibility they add up to.
///
/// Notifies on every tick of their animations, and on every change to the set.
class _HidingRoutes extends ChangeNotifier {
  final Set<ModalRoute<Object?>> _routes = {};

  bool _notifyScheduled = false;
  bool _disposed = false;

  /// `1 - max(animation * (1 - secondaryAnimation))` over the routes.
  ///
  /// A hiding page arriving drives `animation`; a page pushed over it drives
  /// `secondaryAnimation`, which is how that page brings the bar back.
  double get visibility {
    double hidden = 0;

    for (final ModalRoute<Object?> route in _routes) {
      hidden = max(
        hidden,
        route.animation!.value * (1 - route.secondaryAnimation!.value),
      );
    }

    return 1 - hidden;
  }

  void add(ModalRoute<Object?> route) {
    if (!_routes.add(route)) return;

    route.animation!.addListener(_changed);
    route.secondaryAnimation!.addListener(_changed);
    _changed();
  }

  void remove(ModalRoute<Object?> route) {
    if (!_routes.remove(route)) return;

    route.animation!.removeListener(_changed);
    route.secondaryAnimation!.removeListener(_changed);
    _changed();
  }

  /// Notifies now, or after the frame when called from inside one.
  ///
  /// A page registers while it builds and unregisters while the tree is
  /// finalised, and the Navigator re-parents a route's secondary animation
  /// while it builds; the slot is an ancestor of all of them and cannot be
  /// marked dirty then. Waiting for the end of the frame shows nothing late on
  /// a push or a pop: a page registers on the frame its animation is still at
  /// 0 and leaves once it is back at 0, so its share is 0 on the frame
  /// skipped. Animation ticks arrive before the build and notify at once.
  void _changed() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();

      return;
    }

    if (_notifyScheduled) return;
    _notifyScheduled = true;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;

      // The scope can leave in the same frame as the last page.
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;

    for (final ModalRoute<Object?> route in _routes) {
      route.animation!.removeListener(_changed);
      route.secondaryAnimation!.removeListener(_changed);
    }

    super.dispose();
  }
}
