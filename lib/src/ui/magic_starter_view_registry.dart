import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart' show GoRouterState;

typedef MagicStarterViewBuilder = Widget Function();
typedef MagicStarterLayoutBuilder = Widget Function(Widget child);
typedef MagicStarterModalBuilder = Widget Function();

/// Slot builder receives the current [BuildContext] and returns a widget.
typedef MagicStarterSlotBuilder = Widget Function(BuildContext context);

/// Wraps a routed page in a [KeyedSubtree] keyed on the current route path.
///
/// A widget rather than an inline [Builder] so the reason has somewhere to
/// live, and so [MagicStarterViewRegistry.makeLayout] reads as one call. The
/// [Builder] is what supplies a [BuildContext] under the route: `makeLayout`
/// is reached through `layout: (child) => ...`, which has none.
class _RouteScope extends StatelessWidget {
  const _RouteScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext inner) =>
          KeyedSubtree(key: ValueKey<String>(_path(inner)), child: child),
    );
  }

  /// `GoRouterState.of` throws rather than answering null and ships no
  /// `maybeOf`, and a widget test that pumps a layout with no router above it
  /// is ordinary. The path is a cache key and nothing else, so an empty one is
  /// the right answer there.
  ///
  /// The assert exists because the key is computed wherever the HOST chose to
  /// render the child, not at the layout's own build context. A host that
  /// places it somewhere go_router's inherited state does not reach, an
  /// `Overlay` entry or a nested `Navigator`, would otherwise get a constant
  /// `ValueKey('')` for every route and no remount at all: the exact failure
  /// this wrapper exists to remove, arriving silently. Release behaviour is
  /// unchanged.
  ///
  /// It cannot tell those two cases apart, so it names both. A widget test that
  /// pumps a layout with no router is the common reader of this line and it is
  /// doing nothing wrong: distinguishing a harness from a live app would mean
  /// importing `flutter_test` into `lib/`, and a diagnostic that reads as a
  /// defect report in the ordinary case is a diagnostic that stops being read.
  String _path(BuildContext context) {
    try {
      return GoRouterState.of(context).uri.path;
    } on Object {
      assert(() {
        debugPrint(
          'magic_starter: a layout rendered its child where GoRouterState is '
          'not reachable, so every route shares one subtree key and no route '
          'change remounts the page. Expected in a widget test that pumps a '
          'layout with no router above it. In a running app it means the child '
          'was rendered outside the routed subtree, in an Overlay entry or a '
          'nested Navigator; move it inside.',
        );

        return true;
      }());

      return '';
    }
  }
}

/// Registry for starter view builders.
///
/// Allows overriding default screens (login/register/team/profile) by string key.
class MagicStarterViewRegistry {
  final Map<String, MagicStarterViewBuilder> _builders =
      <String, MagicStarterViewBuilder>{};
  final Map<String, MagicStarterLayoutBuilder> _layouts =
      <String, MagicStarterLayoutBuilder>{};
  final Map<String, MagicStarterModalBuilder> _modals =
      <String, MagicStarterModalBuilder>{};

  /// Slot builders keyed by `'view.slot'` (e.g. `'auth.login.header'`).
  final Map<String, MagicStarterSlotBuilder> _slots =
      <String, MagicStarterSlotBuilder>{};

  /// Register a builder under the given key.
  void register(String key, MagicStarterViewBuilder builder) {
    _builders[key] = builder;
  }

  /// Register a layout builder under the given key.
  void registerLayout(String key, MagicStarterLayoutBuilder builder) {
    _layouts[key] = builder;
  }

  /// Returns true when a builder exists for [key].
  bool has(String key) => _builders.containsKey(key);

  /// Returns true when a layout builder exists for [key].
  bool hasLayout(String key) => _layouts.containsKey(key);

  /// Build a widget by [key].
  ///
  /// Throws [StateError] when the key is not registered.
  Widget make(String key) {
    final builder = _builders[key];

    if (builder == null) {
      throw StateError('No view builder registered for key "$key".');
    }

    return builder();
  }

  /// Build a layout by [key] wrapping [child].
  ///
  /// [child] reaches the builder already wrapped in a route-keyed
  /// [KeyedSubtree], so a host app that replaces a layout through
  /// [registerLayout] keeps the remount behaviour the default layouts carry
  /// without having to know it exists.
  ///
  /// The keying is correctness rather than appearance, and both default
  /// layouts used to carry their own copy:
  ///
  /// - `MagicStarterAppLayout`: a persistent shell reuses the same child slot
  ///   across routes, so swapping one scrollable view for another tears down
  ///   render objects in a confused order under accumulated navigation
  ///   (`markNeedsLayout` on an already-dirty relayout boundary, a double
  ///   detach).
  /// - `MagicStarterGuestLayout`: under `RouteTransition.none` the outgoing
  ///   and incoming routes are briefly mounted together, so a guest to guest
  ///   move reparents the previous page's element tree instead of unmounting
  ///   it, and it tears down mid-build.
  ///
  /// Neither mechanism lives in the router, so before this it survived only
  /// for as long as a host used the default layout. A consumer app shipped a
  /// replacement without the key and found out by reading the layout it had
  /// replaced.
  ///
  /// The wrap goes around [child] rather than around the builder's result on
  /// purpose: keying the shell itself would tear the navigation chrome down on
  /// every route change, which is the opposite of what a persistent shell is
  /// for.
  ///
  /// Throws [StateError] when the key is not registered.
  Widget makeLayout(String key, {required Widget child}) {
    final builder = _layouts[key];

    if (builder == null) {
      throw StateError('No layout builder registered for key "$key".');
    }

    return builder(_RouteScope(child: child));
  }

  /// Register a modal builder under the given key.
  void registerModal(String key, MagicStarterModalBuilder builder) {
    _modals[key] = builder;
  }

  /// Returns true when a modal builder exists for [key].
  bool hasModal(String key) => _modals.containsKey(key);

  /// Build a modal widget by [key].
  ///
  /// Throws [StateError] when the key is not registered.
  Widget makeModal(String key) {
    final builder = _modals[key];

    if (builder == null) {
      throw StateError('No modal builder registered for key "$key".');
    }

    return builder();
  }

  // -------------------------------------------------------------------------
  // Slot API
  // -------------------------------------------------------------------------

  /// Register a slot builder for a named slot within a view.
  ///
  /// [viewKey] is the view identifier (e.g. `'auth.login'`).
  /// [slot] is the slot name (e.g. `'header'`, `'footer'`).
  /// [builder] receives [BuildContext] and returns the injected widget.
  ///
  /// ```dart
  /// MagicStarter.view.slot('auth.login', 'header', (context) {
  ///   return WText('Welcome back!', className: 'text-2xl font-bold text-center');
  /// });
  /// ```
  void slot(String viewKey, String slotName, MagicStarterSlotBuilder builder) {
    _slots['$viewKey.$slotName'] = builder;
  }

  /// Returns true when a slot builder is registered for [viewKey] + [slot].
  bool hasSlot(String viewKey, String slot) =>
      _slots.containsKey('$viewKey.$slot');

  /// Build the slot widget for [viewKey] + [slot], or `null` when not registered.
  ///
  /// ```dart
  /// final headerSlot = MagicStarter.view.buildSlot('auth.login', 'header', context);
  /// if (headerSlot != null) ...[headerSlot, const WSpacer(className: 'h-4')],
  /// ```
  Widget? buildSlot(String viewKey, String slot, BuildContext context) {
    final builder = _slots['$viewKey.$slot'];
    return builder?.call(context);
  }

  // -------------------------------------------------------------------------
  // Cleanup
  // -------------------------------------------------------------------------

  /// Remove all builders (useful for tests).
  void clear() {
    _builders.clear();
    _layouts.clear();
    _modals.clear();
    _slots.clear();
  }
}
