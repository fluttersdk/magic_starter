import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';

import '../facades/magic_starter.dart';
import '../models/magic_starter_team.dart';
import 'session_scoped_controller.dart';

/// Keeps every registered [SessionScopedController] pointed at the session that
/// is authenticated right now.
///
/// magic caches controllers as Type-keyed singletons and runs `onInit` once per
/// instance lifetime, so a logout followed by a login, or a team switch, leaves
/// the previous session's rows on screen. On a team-scoped product that shows
/// one tenant's data to another, so this is a correctness and privacy guard, not
/// a freshness nicety.
///
/// ### Example Usage
/// ```dart
/// class AppServiceProvider extends ServiceProvider {
///   AppServiceProvider(super.app);
///
///   @override
///   Future<void> boot() async {
///     // Register last: polling, realtime and locale should already point at
///     // the new session before its data is refetched.
///     SessionScopeSync.attach();
///   }
/// }
/// ```
///
/// ## Why static state instead of an instance
///
/// Everything this coordinates is already process-wide: `Auth.stateNotifier` is
/// one notifier per guard, and `Magic.controllers` is one static registry. Two
/// instances would both listen to that single notifier and reset every
/// controller twice per identity change, doubling every refetch, so there is
/// nothing for a second instance to scope. Static members make the "exactly
/// one" rule structural, and [attach] is idempotent so a provider that boots
/// twice (hot restart) cannot double-subscribe.
class SessionScopeSync {
  SessionScopeSync._();

  /// The authenticated identity the registered controllers currently hold data
  /// for, as `<userId>:<teamId>`, or null while nobody is signed in.
  static String? _identity;

  /// The notifier [attach] subscribed to, held so [detach] can unsubscribe from
  /// that exact instance.
  ///
  /// `Auth.stateNotifier` resolves through the IoC container, so re-binding the
  /// guard (which every test `setUp` does) hands back a DIFFERENT notifier;
  /// unsubscribing through the facade would silently leave this listener
  /// attached to the old one. Doubles as the attached flag.
  static ValueNotifier<int>? _notifier;

  /// Whether a subscription to auth state changes is currently active.
  static bool get isAttached => _notifier != null;

  /// Records the identity the app boots with, then clears and refetches every
  /// registered [SessionScopedController] on each later login or team switch.
  ///
  /// Call once from the app's service provider `boot()`. Idempotent: while
  /// already attached this is a no-op, because a second subscription would
  /// reset every controller twice per identity change.
  static void attach() {
    if (_notifier != null) return;

    // Record the identity a restored session boots with. Nothing is reset in
    // practice: no view has resolved a controller yet at boot, so the loop is
    // empty and the first REAL change is the first one that resets.
    _sync();

    _notifier = Auth.stateNotifier..addListener(_sync);
  }

  /// Unsubscribes from auth state changes and forgets the recorded identity.
  ///
  /// Production code rarely needs this (the subscription lives as long as the
  /// app does), tests always do: without it the listener outlives the guard it
  /// was registered against and the recorded identity leaks into the next test,
  /// which would make the "unchanged identity is a no-op" rule fire for the
  /// wrong reason.
  static void detach() {
    _notifier?.removeListener(_sync);
    _notifier = null;
    _identity = null;
  }

  /// Reads the identity that owns the data now in scope: the authenticated user
  /// together with their active team, since a team-scoped product scopes every
  /// endpoint to the current team, not just to the user.
  ///
  /// `Auth.check()` is the sole null discriminator, so the id is read straight
  /// from the guard and never null-checked: null means unauthenticated and
  /// nothing else. The team comes from the starter's own resolver rather than a
  /// user model, because a package cannot know the consumer's `User` class; it
  /// is null when the teams feature is off or no resolver was registered, and
  /// the user leg of the key still does its job.
  static String? _readIdentity() {
    if (!Auth.check()) return null;

    final MagicStarterTeam? team = MagicStarter.teamResolver?.currentTeam();

    return '${Auth.id()}:${team?.id}';
  }

  /// Clears and refetches every registered [SessionScopedController] whenever
  /// the authenticated identity changes.
  ///
  /// An unchanged identity is a no-op: `Auth.stateNotifier` also bumps on a
  /// plain session restore, and a stampede of refetches on every incidental
  /// bump would be both wasteful and visible as flicker.
  ///
  /// Only a change to a NON-NULL identity resets. On logout there is no identity
  /// to refetch for, and a reset would fire a wave of requests that can only
  /// 401 from the login screen. The stale rows stay unreachable in memory and
  /// the next login resets them before any authenticated view renders, because
  /// `Auth.login` bumps `Auth.stateNotifier` before the post-login navigation.
  /// The identity is recorded either way, so signing back in as the same user
  /// still counts as a change and still refetches.
  static void _sync() {
    final String? identity = _readIdentity();
    if (identity == _identity) return;

    _identity = identity;
    if (identity == null) return;

    // Snapshot first: a reset may resolve another controller and register it,
    // which would otherwise mutate the registry mid-iteration.
    final List<SessionScopedController> scoped = Magic.controllers
        .whereType<SessionScopedController>()
        .toList();

    for (final SessionScopedController controller in scoped) {
      // Isolated per controller: `Auth.stateNotifier` listeners are synchronous
      // while a reset is not, so `unawaited` fires it without blocking the
      // notifier, and the `catchError` guard keeps one controller's failure from
      // aborting the others (and from escaping as an unhandled async error).
      unawaited(
        controller.resetForSession().catchError((Object error) {
          Log.error('[SessionScopeSync] session reset failed: $error');
        }),
      );
    }
  }
}
