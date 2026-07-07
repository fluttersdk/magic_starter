import 'package:magic/magic.dart';

import '../magic_starter_manager.dart';

/// Binds a [MagicStarterManager] into the Magic IoC container for tests.
///
/// Wraps the idiom repeated across the test suite —
/// `Magic.singleton('magic_starter', () => MagicStarterManager())` — into a
/// single call so widget/unit tests no longer need to hand-roll it.
///
/// Pass [manager] to bind a pre-configured instance (e.g. one with custom
/// theme overrides); omit it to bind a default-constructed manager.
///
/// ### Example Usage
/// ```dart
/// setUp(() {
///   MagicApp.reset();
///   Magic.flush();
///   setUpMagicStarterForTests();
/// });
/// ```
void setUpMagicStarterForTests({MagicStarterManager? manager}) {
  Magic.singleton('magic_starter', () => manager ?? MagicStarterManager());
}
