import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';

import 'concerns/completes_sign_in.dart';
import 'concerns/navigates_routes.dart';
import 'magic_starter_auth_controller.dart';
import '../../configuration/magic_starter_config.dart';
import '../../facades/magic_starter.dart';

/// Signs in a visitor another surface (a landing page, a mail) has already
/// authenticated, through a one-time code, and carries a `next` destination.
///
/// The page opens at `/auth/handoff?code=<code>&next=<path>`. The code is
/// traded at `POST auth/handoff/exchange` for the answer a login gives, plus
/// `data.next`, so no bearer token ever travels in a url. The answer is held in
/// memory only, and [confirmingAs] asks "Sign in as ...?" before anything
/// changes: over an open session so a crafted link can neither sign the visitor
/// out nor swap their account silently, and with no session too (unless
/// `handoff.confirm_without_session` is off) so a link carrying the
/// attacker's own code cannot sign a victim in to the attacker's account. On
/// [confirm] the answer concludes through [completeSignIn], the two-factor
/// challenge included. A refused code changes nothing. Without a code only
/// `next` is carried.
///
/// An answer that is dropped ([cancel], [forget], a new session) already
/// minted a token on the server, so it is revoked with `POST auth/logout`
/// presenting that token, best effort and without touching the open session.
///
/// The code, the token and the handed email are never logged, toasted or
/// rendered, except the email (or name) on the confirmation.
///
/// ### The exchange does not ride the `Http` facade
///
/// The facade's driver carries the app's interceptors: magic's
/// `AuthInterceptor` writes the open session's bearer onto the request and
/// answers a 401 by refreshing or logging that session out, and the devtools
/// recorder keeps response bodies, which here carry the new token. So the
/// exchange goes out on a bare [DioNetworkDriver] with the facade driver's
/// origin, timeout and default headers (the `User-Agent` the backend records
/// on the session included) and none of its interceptors.
class MagicStarterHandoffController extends MagicController
    with NavigatesRoutes, CompletesSignIn
    implements SessionScoped {
  /// Creates the controller. [driver] defaults to the bare driver described
  /// above; a test injects a fake to observe the exchange.
  MagicStarterHandoffController({NetworkDriver Function()? driver})
    : _driver = driver ?? _bareDriver;

  static MagicStarterHandoffController get instance =>
      Magic.findOrPut(MagicStarterHandoffController.new);

  /// The exchange endpoint on the `magic-starter-laravel` API.
  static const String exchangePath = '/auth/handoff/exchange';

  /// The endpoint that revokes the token presenting it.
  static const String revokePath = '/auth/logout';

  final NetworkDriver Function() _driver;

  /// The answer waiting for the visitor on the confirmation, or `null`.
  _HandedSignIn? _awaiting;

  /// Moves on every [forget], so an exchange that settles after its screen
  /// left is dropped instead of parking an answer nobody can confirm.
  int _generation = 0;

  /// Steps of a handoff that are mid-air: an exchange that has not answered, a
  /// confirmed sign-out, a sign-in being concluded.
  int _working = 0;

  /// Render the handoff view via registry key.
  Widget handoff() => MagicStarter.view.make('auth.handoff');

  /// Whether the confirmation is showing: a valid answer arrived and waits for
  /// [confirm] or [cancel].
  bool get isConfirming => _awaiting != null;

  /// How the confirmation names the handed account: its email, else its name;
  /// `null` when nothing waits or the answer is a two-factor challenge, which
  /// names nobody.
  String? get confirmingAs => _awaiting?.identity;

  /// Whether a handed code is mid-air: its exchange has not answered, its
  /// answer waits on the confirmation, or the confirmed sign-out and sign-in
  /// have not finished.
  ///
  /// The app must not remount while this is true. A code is single use and the
  /// exchange spends it, so a second run of the screen over the same code (what
  /// `Magic.reload()` causes, the boot sync of an already signed-in visitor
  /// having changed the user) is refused as expired, and the first run's answer
  /// is dropped and revoked with it: the visitor lands on the open session with
  /// an "expired" toast instead of being asked "Sign in as ...?".
  bool get holdsHandoff => _working > 0 || _awaiting != null;

  // -------------------------------------------------------------------------
  // Public actions
  // -------------------------------------------------------------------------

  /// Opens what the link handed over, read once from the route's [code] and
  /// [next] query values.
  ///
  /// A failed exchange (the backend's one 422 shape, a transport failure, an
  /// answer that is neither a session nor a challenge) goes home over a
  /// session and to the sign-in screen without one, with one toast that never
  /// tells which of those it was.
  Future<void> handOff({String? code, String? next}) async {
    final String? queryNext = MagicStarterNextPath.parse(next);
    if (code == null || code.isEmpty) {
      _carry(queryNext);

      return;
    }

    // 1. Trade the code first: nothing about the session moves before the
    //    server has answered for it.
    final int generation = _generation;
    final Map<String, dynamic>? body;
    _working++;
    try {
      body = await _exchange(code);
    } finally {
      _working--;
    }
    if (generation != _generation) {
      if (body != null) _revoke(body);

      return;
    }
    if (body == null) {
      Magic.toast(trans('magic_starter.handoff.expired'));
      navigateTo(
        Auth.check()
            ? MagicStarterConfig.homeRoute()
            : MagicStarterConfig.loginRoute(),
      );

      return;
    }

    final _HandedSignIn signIn = _HandedSignIn(
      body: body,
      // Only the path the code was minted with: a query `next` is not bound to the code, so a
      // crafted link could otherwise choose where a valid code lands.
      next: MagicStarterNextPath.parse(_serverNext(body)),
    );

    // 2. Nobody to replace and the app chose to skip the question: conclude
    //    like any other sign-in.
    if (!Auth.check() && !MagicStarterConfig.handoffConfirmsWithoutSession()) {
      await _signIn(signIn);

      return;
    }

    // 3. Ask before signing anyone in or out.
    _awaiting = signIn;
    refreshUI();
  }

  /// Leaves any open session through the starter's own sign-out, then
  /// concludes the handed sign-in.
  Future<void> confirm() async {
    final _HandedSignIn? signIn = _awaiting;
    if (signIn == null) return;

    // Counted before the answer stops waiting, so the handoff is held without
    // a gap between the question and the sign-in it asked for.
    _working++;
    try {
      _awaiting = null;
      refreshUI();
      if (Auth.check()) await MagicStarterAuthController.instance.logout();
      await _signIn(signIn);
    } finally {
      _working--;
    }
  }

  /// Declines the handed account: an open session stays and home opens, else
  /// the sign-in screen. The handed token is revoked.
  void cancel() {
    final bool signedIn = Auth.check();
    forget();
    navigateTo(
      signedIn
          ? MagicStarterConfig.homeRoute()
          : MagicStarterConfig.loginRoute(),
    );
  }

  /// Drops anything waiting without notifying, revoking its token; the screen
  /// calls it as it leaves, when nobody listens.
  void forget() {
    _generation++;
    final _HandedSignIn? declined = _awaiting;
    _awaiting = null;
    if (declined != null) _revoke(declined.body);
  }

  @override
  Future<void> resetForSession() async {
    forget();
    refreshUI();
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// The exchange's answer when it is a session or a challenge, else `null`.
  ///
  /// Logs only the status: the request body holds the code and the answer
  /// the token and the email.
  Future<Map<String, dynamic>?> _exchange(String code) async {
    final MagicResponse response;
    try {
      response = await _driver().post(exchangePath, data: {'code': code});
    } catch (error) {
      Log.warning(
        '[MagicStarterHandoffController] the exchange failed '
        '(${error.runtimeType}).',
      );

      return null;
    }

    final Object? body = response.data;
    if (!response.successful || body is! Map<String, dynamic>) {
      Log.info(
        '[MagicStarterHandoffController] the exchange was refused '
        '(${response.statusCode}).',
      );

      return null;
    }

    final Object? data = body['data'];
    final bool challenge =
        body['two_factor'] == true ||
        (data is Map<String, dynamic> && data['two_factor'] == true);
    final bool session =
        data is Map<String, dynamic> &&
        data['token'] is String &&
        data['user'] is Map<String, dynamic>;

    return challenge || session ? body : null;
  }

  /// Records where the sign-in lands, then concludes it. Recorded after any
  /// sign-out, whose auth-state listener in the starter drops the intended url.
  Future<void> _signIn(_HandedSignIn signIn) async {
    _working++;
    try {
      final String? next = signIn.next;
      if (next != null) MagicRouter.instance.setIntendedUrl(next);

      await completeSignIn(signIn.body);
    } finally {
      _working--;
    }
  }

  /// Revokes the token a dropped answer [body] carries, without waiting; a
  /// challenge carries none. Best effort: a refusal or a transport failure is
  /// logged by status or type only, and the open session is never involved,
  /// since the request presents the handed token on the bare driver.
  void _revoke(Map<String, dynamic> body) {
    final Object? data = body['data'];
    final Object? token = data is Map<String, dynamic> ? data['token'] : null;
    if (token is! String) return;

    unawaited(_revokeToken(token));
  }

  Future<void> _revokeToken(String token) async {
    final String header = Config.get<String>(
      'auth.token.header',
      'Authorization',
    )!;
    final String prefix = Config.get<String>('auth.token.prefix', 'Bearer')!;

    try {
      final MagicResponse response = await _driver().post(
        revokePath,
        headers: {header: '$prefix $token'},
      );
      if (!response.successful) {
        Log.info(
          '[MagicStarterHandoffController] a declined handoff token was not '
          'revoked (${response.statusCode}).',
        );
      }
    } catch (error) {
      Log.info(
        '[MagicStarterHandoffController] a declined handoff token was not '
        'revoked (${error.runtimeType}).',
      );
    }
  }

  /// Carries [next] without a code: there when signed in, to the configured
  /// signed-out route keeping it when not, else home or the sign-in screen.
  void _carry(String? next) {
    final bool signedIn = Auth.check();

    if (next == null) {
      navigateTo(
        signedIn
            ? MagicStarterConfig.homeRoute()
            : MagicStarterConfig.loginRoute(),
      );

      return;
    }

    if (signedIn) {
      navigateTo(next);

      return;
    }

    navigateTo(
      MagicStarterConfig.handoffSignedOutRoute(),
      query: {'next': next},
    );
  }

  static String? _serverNext(Map<String, dynamic> body) {
    final Object? data = body['data'];
    final Object? next = data is Map<String, dynamic> ? data['next'] : null;

    return next is String ? next : null;
  }

  /// A driver on the facade driver's origin, timeout and default headers,
  /// with none of its interceptors; from `network.drivers.api` when the facade
  /// driver is not a [DioNetworkDriver].
  static NetworkDriver _bareDriver() {
    final NetworkDriver facade = Magic.make<NetworkDriver>('network');
    if (facade is DioNetworkDriver) {
      return DioNetworkDriver(
        baseUrl: facade.baseUrl,
        timeout: facade.timeout,
        defaultHeaders: facade.defaultHeaders,
      );
    }

    final Map<String, dynamic> config =
        Config.get<Map<String, dynamic>>('network.drivers.api') ?? {};

    return DioNetworkDriver(
      baseUrl: config['base_url'] as String? ?? '',
      timeout: config['timeout'] as int? ?? 10000,
      defaultHeaders: Map<String, String>.from(
        config['headers'] as Map? ?? const <String, String>{},
      ),
    );
  }
}

/// An exchange answer held until it concludes; never logged, never rendered.
class _HandedSignIn {
  const _HandedSignIn({required this.body, required this.next});

  /// The exchange's answer, in the shape [CompletesSignIn.completeSignIn]
  /// reads.
  final Map<String, dynamic> body;

  /// Where the sign-in lands, already checked by [MagicStarterNextPath].
  final String? next;

  /// The handed account's email, else its name; `null` for a challenge.
  String? get identity {
    final Object? data = body['data'];
    final Object? user = data is Map<String, dynamic> ? data['user'] : null;
    if (user is! Map<String, dynamic>) return null;

    final String email = '${user['email'] ?? ''}'.trim();
    if (email.isNotEmpty) return email;

    final String name = '${user['name'] ?? ''}'.trim();

    return name.isEmpty ? null : name;
  }
}
