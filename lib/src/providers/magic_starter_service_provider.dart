import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_notifications/magic_notifications.dart';

import '../configuration/magic_starter_config.dart';
import '../facades/magic_starter.dart';
import '../magic_starter_manager.dart';

/// Listener to reload app when auth is restored (e.g., after team switch)
class _ReloadOnAuthRestored extends MagicListener<AuthRestored> {
  @override
  Future<void> handle(AuthRestored event) async {
    // Soft reload the app to refresh all team-scoped data
    Magic.reload();
  }
}

/// Service provider for Magic Starter.
///
/// Register in your app's kernel:
///
/// ```dart
/// (app) => MagicStarterServiceProvider(app),
/// ```
class MagicStarterServiceProvider extends ServiceProvider {
  MagicStarterServiceProvider(super.app);

  @override
  void register() {
    // Register manager singleton.
    app.singleton('magic_starter', () => MagicStarterManager());

    // Register event listener to reload app after team switch
    EventDispatcher.instance.register(AuthRestored, [
      () => _ReloadOnAuthRestored(),
    ]);
  }

  @override
  Future<void> boot() async {
    final teamsEnabled =
        Config.get<bool>('magic_starter.features.teams', false) ?? false;
    if (teamsEnabled && MagicStarter.manager.teamResolver == null) {
      Log.warning(
        '[MagicStarter] Teams feature is enabled but no team resolver '
        'is configured. Call MagicStarter.useTeamResolver() in your AppServiceProvider.',
      );
    }

    // Register Gate abilities for profile section visibility.
    // Each ability returns true for non-guest users, false for guests.
    // Host apps can override by re-defining any ability after this provider boots.
    _registerGateAbilities();

    // 1. Check if primary color is defined in Wind UI theme.
    // 2. If not, register 'indigo' as the fallback primary color.
    // 3. Emit info log to notify about the fallback.
    _bootPrimaryColorFallback();

    _forgetIntendedUrlOnSignOut();
    _declarePushIdentityOnSignIn();
  }

  /// The notifier [_declarePushIdentityOnSignIn] is currently subscribed to.
  ///
  /// Held and identity-compared for the same reasons [_authState] is; see the
  /// note there, including why a one-way latch was wrong.
  static ValueNotifier<int>? _pushAuthState;

  /// The subscription that re-declares once a push driver exists.
  static StreamSubscription<PushDriver>? _pushDriverArrival;

  /// Declares who this device is subscribed as, whenever a session begins.
  ///
  /// This is the half that was missing. [MagicStarterAuthController.logout]
  /// calls `Notify.logoutPush()` (`magic_starter_auth_controller.dart:343`) and
  /// nothing anywhere called `initializePush`, so the package tore down an
  /// identity it never established: an adopter who wired nothing got a device
  /// subscribed under no external id while the Laravel counterpart addressed
  /// `user_<id>`, and the only trace was a zero-recipient report on the server.
  /// Nothing on the client failed, which is why it survived so long.
  ///
  /// Hung off the auth notifier rather than off each authenticating call site,
  /// for the reason [_forgetIntendedUrlOnSignOut] gives at length: there are
  /// six ways into a session here (password, two-factor challenge, social,
  /// guest, phone otp) plus the one no call site can see, `Auth.restore()` on a
  /// cold boot, which is the ORDINARY launch for somebody already signed in.
  /// The notifier is the one funnel all of them pass through.
  ///
  /// Safe to run on every bump, which matters because the notifier bumps for
  /// reasons that are not a new session (a team switch calls `Auth.restore()`).
  /// `want` returns early when the intent is unchanged
  /// (`notification_manager.dart:922`), and the permission prompt it raises
  /// first is claimed once per process (`:1671`), so a repeat costs a vault
  /// read and nothing else.
  void _declarePushIdentityOnSignIn() {
    final ValueNotifier<int> notifier = Auth.stateNotifier;
    if (identical(_pushAuthState, notifier)) return;

    _pushAuthState?.removeListener(_declarePushIdentity);
    _pushAuthState = notifier..addListener(_declarePushIdentity);

    // The ordering the package documents at `notification_manager.dart:846`:
    // auth providers register ahead of the notifications one, so a cold boot
    // that restores a stored session declares an identity while no driver
    // exists to carry it. `want` records the intent either way, but the
    // permission ask is skipped (`:1665`) and nothing re-raises it, so the
    // device sits unasked for the whole launch. This is the package's own
    // signal for coming back once a driver is there.
    unawaited(_pushDriverArrival?.cancel());
    _pushDriverArrival = Notify.manager.onPushDriverAttached.listen(
      (PushDriver _) => _declarePushIdentity(),
    );
  }

  /// The listener itself, a named static so it can be removed by identity.
  static void _declarePushIdentity() {
    if (!MagicStarterConfig.hasNotificationFeatures()) return;

    // Sign-out is the auth controller's, and it is not merely the opposite of
    // this: it also drops the rows held for the session that ended. Answering
    // a sign-out here too would race it.
    if (!Auth.check()) return;

    final String? id = Auth.id()?.toString();
    if (id == null || id.isEmpty) return;

    unawaited(
      Notify.initializePush(
        '${MagicStarterConfig.pushExternalIdPrefix()}$id',
      ).catchError((Object error, StackTrace stackTrace) {
        // Logged rather than rethrown: this runs off a ValueNotifier
        // callback, where a throw becomes an unhandled async error, and a
        // push identity the device could not declare is not a reason to
        // fail the sign-in that triggered it. The manager keeps the intent
        // and reports itself un-converged, so the next reconcile retries.
        Log.error(
          '[MagicStarter] push identity declaration failed: '
          '$error\n$stackTrace',
        );
      }),
    );
  }

  /// The notifier [_forgetIntendedUrlOnSignOut] is currently subscribed to.
  ///
  /// Held rather than resolved again at removal time for the same reason
  /// `SessionScopeSync` holds its own: `Auth.stateNotifier` resolves through
  /// the container, so re-binding the guard hands back a DIFFERENT notifier and
  /// unsubscribing through the facade would leave this listener on the old one.
  ///
  /// Compared by identity rather than treated as a one-way latch, which is what
  /// it was first written as and what a review caught. A latch never cleared,
  /// so a second boot after a re-bind returned early and left the subscription
  /// on a notifier nobody bumps any more: no clear at all, and a test suite
  /// where the assertion holds only because an earlier test happened to attach
  /// first. It failed under `--test-randomize-ordering-seed=1` and passed in
  /// declaration order, which is the worst way for it to be wrong.
  static ValueNotifier<int>? _authState;

  /// Discards the intended url when the session that recorded it ends.
  ///
  /// [EnsureAuthenticated] records a protected route before bouncing to login,
  /// so `navigateHome()` can send the visitor back to it afterwards. Signing
  /// out flips the auth state, which re-runs go_router's redirects while the
  /// app is STILL on that route, so the sign-out records it too. Nobody asked
  /// for that: it would send the next person who signs in on this device to the
  /// previous one's page, and on the account-deletion path to a deleted
  /// account's settings.
  ///
  /// Hung off the auth notifier rather than off each `Auth.logout()` call site,
  /// which is where this first landed and covers only the logouts a user asks
  /// for. The one that matters most is the one the app performs on its own:
  /// magic's `AuthInterceptor` calls `Auth.logout()` when a token refresh fails
  /// (`auth_interceptor.dart:77`) and `AuthServiceProvider` installs it
  /// unconditionally, so a session that simply EXPIRES on a protected route
  /// took that path. The notifier is the one funnel all three pass through.
  ///
  /// Here rather than in `SessionScopeSync`, which listens to the same notifier
  /// and was the second thing tried: that class is OPT-IN and nothing in this
  /// package calls `attach()`, so an app that never adopted
  /// `SessionScopedController` would have had no clear at all. This provider
  /// boots in every starter app.
  ///
  /// Deferred by a microtask because the whole record path (`stateNotifier` ->
  /// `GoRouteInformationProvider.notifyListeners` -> parse -> redirect) is
  /// synchronous: clearing inline would run before the redirect that writes the
  /// value. Known limit: a host route with an ASYNC `redirect` records after
  /// the microtask and is not covered. Read-and-discard because
  /// `pullIntendedUrl` is the one-time read and `MagicRouter` exposes no
  /// separate clear.
  void _forgetIntendedUrlOnSignOut() {
    final ValueNotifier<int> notifier = Auth.stateNotifier;
    if (identical(_authState, notifier)) return;

    // Moves rather than adds. Booting twice against the same notifier is the
    // no-op above; booting against a NEW one has to take the subscription with
    // it, or the listener sits on a notifier nothing bumps.
    _authState?.removeListener(_forgetIntendedUrl);
    _authState = notifier..addListener(_forgetIntendedUrl);
  }

  /// The listener itself, a named static so [_forgetIntendedUrlOnSignOut] can
  /// remove it: `removeListener` matches by identity and a fresh closure never
  /// equals the one that was added.
  static void _forgetIntendedUrl() {
    if (Auth.check()) return;

    scheduleMicrotask(() {
      // Re-checked inside the microtask: by the time it runs the state may
      // have moved again, and clearing after a login would eat the deep link
      // the intent exists to serve.
      if (Auth.check()) return;

      MagicRouter.instance.pullIntendedUrl();
    });
  }

  /// Registers Gate abilities that control profile section visibility.
  ///
  /// All abilities follow the pattern: grant access when the user is NOT a
  /// guest (i.e. `is_guest != true`). Host apps can override individual
  /// abilities by calling [Gate.define] with the same key after this
  /// provider boots.
  ///
  /// ### Defined Abilities
  ///
  /// | Ability | Controls |
  /// |---|---|
  /// | `starter.update-profile-photo` | Profile photo upload/remove section |
  /// | `starter.update-email` | Email field in profile information |
  /// | `starter.update-phone` | Phone and country code in extended profile |
  /// | `starter.update-password` | Password change section |
  /// | `starter.verify-email` | Email verification banner |
  /// | `starter.manage-two-factor` | Two-factor authentication section |
  /// | `starter.manage-newsletter` | Newsletter preferences section |
  /// | `starter.logout-sessions` | Logout/revoke buttons in browser sessions |
  /// | `starter.delete-account` | Account deletion section |
  void _registerGateAbilities() {
    bool isNotGuest(Model user, [dynamic _]) {
      return user.get<bool>('is_guest') != true;
    }

    Gate.define('starter.update-profile-photo', isNotGuest);
    Gate.define('starter.update-email', isNotGuest);
    Gate.define('starter.update-phone', isNotGuest);
    Gate.define('starter.update-password', isNotGuest);
    Gate.define('starter.verify-email', isNotGuest);
    Gate.define('starter.manage-two-factor', isNotGuest);
    Gate.define('starter.manage-newsletter', isNotGuest);
    Gate.define('starter.logout-sessions', isNotGuest);
    Gate.define('starter.delete-account', isNotGuest);
  }

  /// Boots the primary color fallback mechanism.
  ///
  /// If the host app has NOT defined a `primary` color in the Wind UI theme,
  /// this will automatically register `indigo` as the fallback primary color.
  ///
  /// Because `boot()` runs during `Magic.init()` — before `runApp()` builds
  /// the widget tree — the navigator context is not yet available. We defer
  /// the check to the first post-frame callback, when [WindTheme] is mounted
  /// and the context is guaranteed to exist.
  void _bootPrimaryColorFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = MagicRouter.instance.navigatorKey.currentContext;
      if (context == null) {
        return;
      }

      final windTheme = WindTheme.of(context);
      if (!windTheme.data.isValidColor('primary')) {
        Log.info(
          '[MagicStarter] No primary color defined — using indigo as fallback.',
        );
        windTheme.updateTheme(
          colors: {'primary': windTheme.data.colors['indigo']!},
        );
      }
    });
  }
}
