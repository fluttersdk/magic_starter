import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';

import '../facades/magic_starter.dart';

/// What one call to [MagicStarterGuestClaim.claimIfPending] settled.
///
/// Every member but [none] marks the first sign-in to a real account after a
/// guest session on this device, which is why
/// `MagicStarterManager.onGuestClaimed` hears all of them and never [none].
enum GuestClaimOutcome {
  /// Nothing was settled: signed out, still the guest, no record, a session
  /// that ended while the claim was out, a keychain that refused, or an
  /// answer other than a 2xx, 404 or 422. The last two keep the record, so
  /// the next sign-in or restore asks again.
  none,

  /// The server answered the claim, whether or not it found rows to move.
  claimed,

  /// The server refused the claim with a 422, or has no claim route (a 404).
  /// No retry changes either, so the record is forgotten.
  refused,

  /// The signed-in account IS the guest, promoted by registration, so there
  /// was nothing to claim.
  promoted,
}

/// Moves what a guest accumulated onto the account they sign in to next.
///
/// A guest sign-in [record]s the guest's bearer token and user id in [Vault].
/// A later sign-in (or a restore) to a real account runs [claimIfPending],
/// which posts `POST /auth/guest/claim` authenticated as the TARGET account
/// and naming the guest by its token. The claim runs off the record rather
/// than off the token swap, so it survives a process restart between the two.
///
/// The service provider wires both halves, plus [forget] on sign-out, while
/// the guest-auth feature is on. An app that needs its own ordering after the
/// claim calls [claimIfPending] itself: a claim already in flight hands every
/// caller in the same session the same future.
///
/// The answer to the post: a 2xx is claimed and a 404 or 422 is refused, and
/// either forgets the record; anything else keeps it for the next sign-in or
/// restore. A claim is bound to the session that started it: once [forget]
/// runs (every sign-out), its answer is dropped and it settles as
/// [GuestClaimOutcome.none], touching no record.
///
/// ### The claim does not ride the `Http` facade
///
/// Its body is the guest's plain-text bearer token, still live on the server,
/// and the facade's driver is the one `magic_devtools` records request bodies
/// from in debug and profile builds. So it goes out on a bare
/// [DioNetworkDriver] built from `network.drivers.api`, with no interceptors,
/// attaching the target's bearer itself. That driver sends no magic
/// `User-Agent` either: `NetworkServiceProvider` adds that header only to the
/// facade driver.
class MagicStarterGuestClaim {
  /// Creates the claim. [driver] defaults to the bare configured driver; a
  /// test injects a fake to observe the post without a network.
  MagicStarterGuestClaim({NetworkDriver Function()? driver})
    : _driver = driver ?? _configuredDriver;

  /// Where the guest's plain-text Sanctum token waits for a later claim.
  static const String tokenKey = 'guest_claim_token';

  /// Where the guest's own user id waits, which tells a registration (the
  /// guest row promoted in place) apart from a sign-in to another account.
  static const String userKey = 'guest_claim_user';

  /// The claim endpoint on the `magic-starter-laravel` API.
  static const String path = '/auth/guest/claim';

  static MagicStarterGuestClaim? _instance;

  /// The shared claim the service provider's listeners use.
  static MagicStarterGuestClaim get instance =>
      _instance ??= MagicStarterGuestClaim();

  /// Swaps the shared claim; null drops it, so the next read builds a fresh
  /// default with no claim in flight.
  @visibleForTesting
  static set instance(MagicStarterGuestClaim? claim) => _instance = claim;

  final NetworkDriver Function() _driver;

  /// The claim in flight, shared by every caller until it settles.
  ///
  /// A sign-in and a restore can both ask within one claim's round trip, and
  /// the record is cleared only once the server answers, so without this the
  /// second caller would post the same token again.
  Future<GuestClaimOutcome>? _inFlight;

  /// Moves on every [forget]. A claim captures it when it starts and acts on
  /// its answer only while it is unchanged, so a claim that outlived its
  /// session can neither delete the next guest's record nor report.
  int _session = 0;

  /// The claim [claimInBackground] last handed to the host hook.
  ///
  /// A sign-in and a restore within one claim's round trip both receive the
  /// same in-flight future, and the hook must hear that claim once.
  Future<GuestClaimOutcome>? _reported;

  /// Writes a guest's token and id down for a later claim.
  ///
  /// A non-guest [user] is ignored. A keychain refusal is logged, not thrown:
  /// the guest session itself is open and working, and a throw here would
  /// fail the sign-in that triggered it. What is lost is only the ability to
  /// move the guest's rows later.
  Future<void> record(Authenticatable user) async {
    if (user.get<bool>('is_guest') != true) return;

    try {
      final String? token = await Auth.getToken();
      final String? id = _identifierOf(user.authIdentifier);

      if (token == null || id == null) return;

      await Vault.put(tokenKey, token);
      await Vault.put(userKey, id);
    } on MagicVaultException catch (error) {
      Log.warning(
        '[MagicStarter] could not record the guest session; a later sign-in '
        'will not claim its rows: $error',
      );
    }
  }

  /// Claims the recorded guest session for whoever is signed in now.
  ///
  /// Idempotent within a session: while one claim runs, every caller
  /// receives that same future, until [forget] ends the session. Never
  /// throws: the configured driver turns a transport failure into a
  /// [MagicResponse] (see the class doc), and any exception the driver still
  /// raises is logged and answers [GuestClaimOutcome.none], with the record
  /// kept for the next sign-in or restore.
  Future<GuestClaimOutcome> claimIfPending() {
    final Future<GuestClaimOutcome>? running = _inFlight;
    if (running != null) return running;

    late final Future<GuestClaimOutcome> claim;
    claim = _claimOnce().whenComplete(() {
      // Only its own slot: after a [forget] the slot may hold the next
      // session's claim, which this one must not clear.
      if (identical(_inFlight, claim)) _inFlight = null;
    });

    return _inFlight = claim;
  }

  /// Runs [claimIfPending] without waiting on it, and hands a settled outcome
  /// other than [GuestClaimOutcome.none] to `MagicStarter.manager
  /// .onGuestClaimed`, once per claim however many callers shared it.
  ///
  /// For listeners that must not hold the sign-in or restore that dispatched
  /// them. A throw from the claim or the hook is logged.
  void claimInBackground() {
    final Future<GuestClaimOutcome> claim = claimIfPending();
    if (identical(claim, _reported)) return;
    _reported = claim;

    // Unawaited and logged rather than rethrown: a throw after the calling
    // listener returns would be an unhandled async error, and a failing claim
    // or host hook must not fail the sign-in that triggered it.
    unawaited(
      _report(claim).catchError((Object error, StackTrace stackTrace) {
        Log.error('[MagicStarter] guest claim failed: $error\n$stackTrace');
      }),
    );
  }

  /// Drops the record and ends the session any claim in flight belongs to.
  ///
  /// Called on every sign-out, so the next person on the device cannot claim
  /// the record and a claim still out for the previous one settles as
  /// [GuestClaimOutcome.none] without touching whatever is recorded next.
  ///
  /// A keychain refusal is logged at error level, not thrown: the sign-out
  /// that called this has already happened. It is not harmless, though. The
  /// surviving record is an unclaimed guest's live token, and the next account
  /// to sign in on this device would claim that guest's rows.
  static Future<void> forget() async {
    final MagicStarterGuestClaim? claim = _instance;
    if (claim != null) {
      claim._session++;
      claim._inFlight = null;
    }

    try {
      await Vault.delete(tokenKey);
      await Vault.delete(userKey);
    } on MagicVaultException catch (error) {
      Log.error(
        '[MagicStarter] could not forget the guest record; the next account '
        'to sign in on this device may claim its rows: $error',
      );
    }
  }

  /// One claim, from the gates to the answer.
  ///
  /// 1. Signed out, or still the guest: nothing to claim yet. The target's
  ///    bearer is read here too, before any record read, so the post can only
  ///    carry the session that started it.
  /// 2. No record: this device never had a guest session, or its claim was
  ///    already answered.
  /// 3. The target IS the guest, promoted by registration: nothing to move,
  ///    and the server would refuse a self-claim with a 422.
  /// 4. The post. A 2xx, a 404 and a 422 are final answers, so the record is
  ///    spent; anything else keeps it for the next attempt. Every step after
  ///    an await first checks the session is still the one that started.
  Future<GuestClaimOutcome> _claimOnce() async {
    final int session = _session;
    final Authenticatable? user = Auth.user<Authenticatable>();

    if (user == null || user.get<bool>('is_guest') == true) {
      return GuestClaimOutcome.none;
    }

    try {
      final String? targetToken = await Auth.getToken();

      if (targetToken == null || session != _session) {
        return GuestClaimOutcome.none;
      }

      final String? guestToken = await Vault.get(tokenKey);
      final String? guestId = await Vault.get(userKey);

      if (guestToken == null || session != _session) {
        return GuestClaimOutcome.none;
      }

      if (guestId == _identifierOf(user.authIdentifier)) {
        await _spend(guestToken, session);

        return GuestClaimOutcome.promoted;
      }

      final MagicResponse response;

      try {
        response = await _driver().post(
          path,
          data: <String, dynamic>{'guest_token': guestToken},
          headers: <String, String>{'Authorization': 'Bearer $targetToken'},
        );
      } catch (error, stackTrace) {
        // Logged rather than rethrown: the configured `DioNetworkDriver`
        // already turns a transport failure into a response (see the class
        // doc), so this only fires for an injected driver that throws. The
        // record is kept so the next sign-in or restore retries, and a host
        // awaiting the claim after a successful sign-in must not see a throw.
        Log.error(
          '[MagicStarter] guest claim driver threw: $error\n$stackTrace',
        );

        return GuestClaimOutcome.none;
      }

      if (session != _session) return GuestClaimOutcome.none;

      final bool refused =
          response.statusCode == 404 || response.statusCode == 422;

      if (!response.successful && !refused) return GuestClaimOutcome.none;

      await _spend(guestToken, session);

      return refused ? GuestClaimOutcome.refused : GuestClaimOutcome.claimed;
    } on MagicVaultException catch (error) {
      // Logged rather than thrown: the provider runs this unawaited after a
      // sign-in that already succeeded, and the record stays for the next
      // sign-in or restore to ask again.
      Log.warning(
        '[MagicStarter] could not read the guest record; the claim waits for '
        'the next sign-in: $error',
      );

      return GuestClaimOutcome.none;
    }
  }

  /// Forgets the record a claim just settled, but only while it is still the
  /// one [guestToken] names and [session] is still current: a guest recorded
  /// since is somebody else's claim.
  ///
  /// A keychain refusal is logged, not thrown: the server has already
  /// answered, and a surviving record costs one more claim it refuses.
  Future<void> _spend(String guestToken, int session) async {
    try {
      final String? recorded = await Vault.get(tokenKey);

      if (recorded != guestToken || session != _session) return;

      await Vault.delete(tokenKey);
      await Vault.delete(userKey);
    } on MagicVaultException catch (error) {
      Log.warning(
        '[MagicStarter] could not clear the claimed guest record: $error',
      );
    }
  }

  Future<void> _report(Future<GuestClaimOutcome> claim) async {
    final GuestClaimOutcome outcome = await claim;
    if (outcome == GuestClaimOutcome.none) return;

    await MagicStarter.manager.onGuestClaimed?.call(outcome);
  }

  /// The id in the two shapes a server sends one: a UUID string or an int.
  static String? _identifierOf(Object? id) {
    if (id is String && id.isNotEmpty) return id;
    if (id is int) return id.toString();

    return null;
  }

  /// A bare driver on the configured API, without the facade driver's
  /// interceptors (see the class doc for why).
  static NetworkDriver _configuredDriver() {
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
