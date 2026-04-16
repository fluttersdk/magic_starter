import 'package:flutter/widgets.dart';

typedef MagicStarterViewBuilder = Widget Function();
typedef MagicStarterLayoutBuilder = Widget Function(Widget child);
typedef MagicStarterModalBuilder = Widget Function();

/// Slot builder receives the current [BuildContext] and returns a widget.
typedef MagicStarterSlotBuilder = Widget Function(BuildContext context);

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
  /// Throws [StateError] when the key is not registered.
  Widget makeLayout(String key, {required Widget child}) {
    final builder = _layouts[key];

    if (builder == null) {
      throw StateError('No layout builder registered for key "$key".');
    }

    return builder(child);
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
  void slot(
    String viewKey,
    String slotName,
    MagicStarterSlotBuilder builder,
  ) {
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
