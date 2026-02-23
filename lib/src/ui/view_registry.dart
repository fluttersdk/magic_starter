import 'package:flutter/widgets.dart';

typedef MagicStarterViewBuilder = Widget Function();
typedef MagicStarterLayoutBuilder = Widget Function(Widget child);

/// Registry for starter view builders.
///
/// Allows overriding default screens (login/register/team/profile) by string key.
class MagicStarterViewRegistry {
  final Map<String, MagicStarterViewBuilder> _builders =
      <String, MagicStarterViewBuilder>{};
  final Map<String, MagicStarterLayoutBuilder> _layouts =
      <String, MagicStarterLayoutBuilder>{};

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

  /// Remove all builders (useful for tests).
  void clear() {
    _builders.clear();
    _layouts.clear();
  }
}
