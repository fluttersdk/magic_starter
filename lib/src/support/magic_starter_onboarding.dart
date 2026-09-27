import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:magic/magic.dart';

/// **A generic one-time gate for a first-run onboarding step.**
///
/// A host app never blocks the user with a mandatory onboarding screen; a
/// step (locale confirmation, a feature tour, a welcome banner) is shown once
/// per device and then never again. [MagicStarterOnboarding] tracks that in
/// [Vault] (secure storage) and mirrors every loaded step into an in-memory
/// map so a widget's synchronous `build` can read [isCompleted] without
/// awaiting [Vault].
///
/// A step is loaded once at boot ([load]) with the full set of step names the
/// host app cares about, then flipped by whichever screen resolves it
/// ([markCompleted]). Each step persists under its own Vault key
/// (`onboarding_<step>_done`), so steps are independent and a host app can
/// add a new one without touching the others.
class MagicStarterOnboarding {
  MagicStarterOnboarding._();

  /// The in-memory mirror of every step loaded or marked this session.
  static final Map<String, bool> _completed = {};

  /// The [Vault] key a [step] persists its "seen" flag under.
  static String vaultKeyFor(String step) => 'onboarding_${step}_done';

  /// Whether [step] has already been resolved on this device.
  ///
  /// Reflects the value loaded by [load] plus any in-session [markCompleted]
  /// call. A step that was never loaded nor marked reads as not completed.
  static bool isCompleted(String step) => _completed[step] ?? false;

  /// Loads the persisted flag for every name in [steps] from [Vault] into
  /// memory.
  ///
  /// Called once at boot after `Magic.init` (so the `vault` binding exists)
  /// and before the screens that gate on a step first render. A missing key
  /// resolves to not-completed; so does a [Vault] read failure, logged as a
  /// warning rather than crashing boot (every sibling boot hook is
  /// non-throwing).
  static Future<void> load(Iterable<String> steps) async {
    for (final String step in steps) {
      try {
        _completed[step] = (await Vault.get(vaultKeyFor(step))) != null;
      } catch (error) {
        _completed[step] = false;
        if (Magic.bound('log')) {
          Log.warning(
            '[MagicStarterOnboarding] vault read failed for "$step": $error',
          );
        }
      }
    }
  }

  /// Marks [step] as resolved for this device.
  ///
  /// Flips the in-memory flag immediately (so a gated screen hides at once)
  /// and persists it to [Vault] so it survives restarts and re-logins.
  static Future<void> markCompleted(String step) async {
    _completed[step] = true;
    await Vault.put(vaultKeyFor(step), '1');
  }

  /// Resets the in-memory flags between tests.
  @visibleForTesting
  static void resetForTesting() {
    _completed.clear();
  }
}
