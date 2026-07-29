/// Contract for a controller whose cached state belongs to exactly ONE
/// authenticated session: a user together with their currently active team.
///
/// magic resolves controllers as Type-keyed singletons and runs `onInit` once
/// per instance lifetime (`MagicStatefulViewState.initState` only calls it while
/// `!controller.initialized`, see `magic/lib/src/ui/magic_view.dart:133`). A
/// logout followed by a login, or a team switch, therefore never re-runs the
/// initial fetch: the previous session's rows stay on screen until the app is
/// restarted. On a team-scoped product that is not just staleness, it shows one
/// tenant's data to another.
///
/// Every controller that caches session-scoped data implements this, and
/// `SessionScopeSync` calls [resetForSession] on all of the ones that are
/// currently registered whenever the authenticated identity changes.
///
/// [resetForSession] must CLEAR before it refetches. The ordinary `reload()`
/// paths are deliberately non-destructive (a transport failure keeps the
/// last-known-good rows so a blip does not blank a dashboard), and that is the
/// wrong behaviour across an identity change: a failed refetch must leave the
/// screen empty, never populated with the previous session's data.
///
/// ### Example Usage
/// ```dart
/// class ProjectController extends MagicController
///     with MagicStateMixin<List<Project>>
///     implements SessionScopedController {
///   final List<Project> projects = [];
///
///   @override
///   Future<void> resetForSession() async {
///     // 1. Publish the cleared state BEFORE the refetch, so a failing
///     //    refetch leaves an empty screen rather than the previous
///     //    session's rows.
///     projects.clear();
///     setLoading();
///
///     // 2. Refetch for whoever is authenticated now.
///     await loadProjects();
///   }
/// }
/// ```
abstract interface class SessionScopedController {
  /// Drops every cached row for the previous session, publishes the cleared
  /// state, then refetches for the identity that is now authenticated.
  ///
  /// Called on login and on team switch, never on logout: from the login screen
  /// a refetch can only produce 401s (see `SessionScopeSync.attach`).
  ///
  /// Implementations should not throw. The refetch leg logs and degrades like
  /// any other reload; a throw is isolated per controller by the caller, but it
  /// leaves this controller's own state cleared and unrefetched.
  Future<void> resetForSession();
}
