import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';

import '../../models/magic_starter_plan.dart';

/// Pairs the consumer's display copy onto the usage stats the billing wire
/// carries.
///
/// `magic_payments` decodes the numbers and deliberately carries no label,
/// because a resource's display name is product copy and a package that shipped
/// one would render its author's English in every consumer. The pairing is done
/// by [UsageStat.key], the one handle that does not move with the language.
///
/// An implementation is free to leave a stat it has no word for with a null
/// [UsageStat.label]. It must NOT fall back to the wire key: a meter labelled
/// `requests_this_month` is a raw key on a customer's screen.
typedef MagicStarterUsageCopy = List<UsageStat> Function(List<UsageStat> stats);

/// Reads the NAME of another of the caller's teams that a store account already
/// funds, or `null` when none does.
///
/// Consumer-supplied because the question is the consumer's own: it is about
/// teams, which `magic_payments` knows nothing about, and widening its published
/// [BillingService] contract for one adopter is not on offer. See
/// [MagicStarterBillingController.storeCheckRegistered] for why leaving it
/// unregistered is a distinct state from a read that answered nothing.
typedef MagicStarterStoreFundedTeamReader = Future<String?> Function();

/// Reads whether the signed-in user OWNS the team whose billing is on screen,
/// or `null` when that is genuinely unresolved.
///
/// Consumer-supplied because this package cannot answer it: `MagicStarterTeam`
/// carries an id, a name, a photo and whether the team is personal, and no
/// membership ROLE at all, so the caller's own role on the current team exists
/// only in the consumer's model. Adding one here would be a different package
/// surface and a different piece of work.
///
/// Asked as a callback rather than taken as a value, because ownership moves
/// under this controller: it is a singleton, a team switch changes the answer,
/// and a bool captured at construction goes stale on exactly the transition
/// that matters. Every gate asks again.
///
/// Answer `null`, not `false`, for anything unresolved: no signed-in user yet,
/// no current team, a payload that carried no role. The gates read all three
/// states and only a KNOWN `false` refuses anything; see
/// [MagicStarterBillingController.isOwner] for why the two negatives lead
/// somewhere different.
///
/// It is asked during build, so it has to ANSWER rather than throw. An exception
/// out of a gate takes down a screen whose entire design is that no single read
/// can.
typedef MagicStarterTeamOwnershipReader = bool? Function();

/// Backs the billing screen: six independent reads of what a customer is
/// entitled to, what they have spent, and where they manage it.
///
/// ## Why this controller does NOT use `MagicStateMixin`
///
/// Every sibling controller in this package mixes in `MagicStateMixin`, and
/// this one deliberately does not. That mixin holds ONE `T? _state` slot and one
/// `RxStatus`, and both of its transitions null the state:
/// `setLoading()` calls `setState(null, ...)`
/// (`magic/lib/src/http/magic_controller.dart:177-179`) and so does `setError()`
/// (`:195-197`). This screen runs six independent reads whose answers have
/// nothing to do with each other, so routing them through one slot would mean
/// any single failing read wipes the other five: an invoices timeout would blank
/// the plan the customer is paying for. Each read therefore publishes its own
/// field and this controller notifies through [refreshUI] instead.
///
/// ## Every read degrades, none of them throws
///
/// A read that fails leaves its own field at last-known state and logs. The
/// screen is a set of independent cards, and a card with no data is recoverable
/// where an exception out of a read takes the whole screen with it. The payment
/// method additionally keeps its OWN [pmLoading] and [pmError], because it is
/// the one read that dials a payment rail live, so a slow or broken rail must
/// gate that card and nothing else.
///
/// ## What the consumer has to supply
///
/// [usageCopy] is REQUIRED, and that is a decision rather than an oversight.
/// Both of the defaults an optional parameter could carry are defects: a
/// pass-through would put the raw wire key `requests_this_month` on a customer's
/// screen, and a drop would silently remove the usage surface from every app
/// that forgot to pass one. Neither may be reachable by forgetting.
///
/// The other two collaborators are optional, and leaving one out is answered in
/// OPPOSITE directions, which is a decision rather than an inconsistency. No
/// [MagicStarterTeamOwnershipReader] leaves ownership unresolved and every gate
/// permissive, because hiding a purchase button from a real owner stands between
/// them and paying while the server refuses a non-owner regardless. No
/// [MagicStarterStoreFundedTeamReader] REFUSES the store purchase, because
/// nothing in that build can promise a second purchase will not transfer another
/// team's subscription away, and a customer cannot undo that.
///
/// Because it takes required collaborators, this controller is registered with
/// `Magic.put(...)` rather than resolved through the `Magic.findOrPut` singleton
/// getter the sibling controllers expose; there is no zero-argument constructor
/// for `findOrPut` to call.
///
/// ### Example
/// ```dart
/// Magic.put(
///   MagicStarterBillingController(
///     usageCopy: withUsageCopy,
///     storeFundedTeamReader: readStoreFundedTeam,
///     isOwnerReader: readTeamOwnership,
///   ),
/// );
/// ```
class MagicStarterBillingController extends MagicController {
  /// Creates the billing controller.
  ///
  /// [billingService] overrides [Payments.billing] for tests. A fake that also
  /// implements [WebBillingService] or [StoreBillingService] supplies that rail
  /// as well (see [webRail] and [storeRail]); one that implements neither models
  /// a build with no rail at all, which is exactly the state where no purchase
  /// or portal affordance may render.
  MagicStarterBillingController({
    required this.usageCopy,
    this.storeFundedTeamReader,
    this.isOwnerReader,
    @visibleForTesting BillingService? billingService,
  }) : _injectedBilling = billingService;

  /// Pairs the consumer's display copy onto every [UsageStat] the producer
  /// reported. Required; see the class docblock for why it has no default.
  final MagicStarterUsageCopy usageCopy;

  /// The consumer's cross-team store check, or `null` when the consumer
  /// registered none.
  ///
  /// Held as a field rather than folded into its answer, because the two nulls
  /// are opposite states: see [storeCheckRegistered].
  final MagicStarterStoreFundedTeamReader? storeFundedTeamReader;

  /// The consumer's ownership check, or `null` when the consumer registered
  /// none.
  ///
  /// An unregistered check leaves [isOwner] UNRESOLVED, and unresolved is
  /// permissive here. That is the opposite direction from an unregistered
  /// [storeFundedTeamReader], which refuses, and both are deliberate: see
  /// [canPurchaseViaStore] for the pair of them side by side.
  final MagicStarterTeamOwnershipReader? isOwnerReader;

  /// The injected read contract, held for the rail resolution below as well as
  /// for [billing].
  final BillingService? _injectedBilling;

  /// The five entitlement READS: the injected contract when there is one, else
  /// the rail this build resolved through [Payments.billing].
  ///
  /// A read is honourable on every platform, because the backend is the
  /// authority on an entitlement no matter which rail sold it, so this is never
  /// null. Resolved lazily so constructing the controller does not require a
  /// bound container.
  late final BillingService billing = _injectedBilling ?? Payments.billing;

  /// The WEB rail, or `null` in a build that cannot serve one.
  ///
  /// The purchase-affecting calls ([WebBillingService.checkout] and
  /// [WebBillingService.openPortal]) live here rather than on the read contract,
  /// because a rail is not available everywhere. `null` is the answer every
  /// affordance is gated on: a store build renders no checkout button at all
  /// instead of one that fails when tapped.
  late final WebBillingService? webRail = _resolveWebRail();

  /// The STORE rail, or `null` in a build that cannot serve one.
  ///
  /// The mobile purchase path: `magic_payments` answers this only on iOS and
  /// Android, so it is `null` on the web and on desktop. In practice the two
  /// rails are mutually exclusive, which is what keeps a store build from
  /// offering web checkout and a web build from offering a purchase the device
  /// cannot make.
  late final StoreBillingService? storeRail = _resolveStoreRail();

  String? _currentPlanId;
  bool _entitlementLoaded = false;
  ManageVia? _manageVia;
  String? _manageUrl;
  List<MagicStarterPlan> _plans = const <MagicStarterPlan>[];
  List<UsageStat> _usage = const <UsageStat>[];
  List<Invoice> _invoices = const <Invoice>[];
  PaymentMethod? _paymentMethod;
  bool _pmLoading = true;
  bool _pmError = false;
  String? _storeFundedTeam;

  /// The active plan id, or `null` while it is genuinely unknown: before
  /// [loadEntitlement] resolves, and permanently after a failed read.
  ///
  /// Never a guess. There is no fixture to fall back to, so an unresolved
  /// current plan reads as unresolved and the current-plan card stays in its
  /// loading state until a retry succeeds.
  String? get currentPlanId => _currentPlanId;

  /// Whether the live entitlement read has resolved a plan, so [currentPlanId]
  /// is the customer's real tier rather than an unanswered read.
  bool get entitlementLoaded => _entitlementLoaded;

  /// The management surface the server computed from the rail, or `null` while
  /// no entitlement read has resolved one.
  ///
  /// `null` is not [ManageVia.none]: one means "no rail has answered yet" and
  /// the other means "the rail answered, and there is nowhere to send you". The
  /// gates treat the unresolved state permissively, because a screen that hid
  /// its own management affordances for the duration of one fetch would flicker
  /// them in, and a slow or failed read would leave a paying customer with no
  /// way to reach their card.
  ManageVia? get manageVia => _manageVia;

  /// The store-management destination the server passed through from the rail,
  /// or `null` when the rail reported none (which is always, on Stripe).
  String? get manageUrl => _manageUrl;

  /// The plan catalogue, in the order the backend served it (cheapest first).
  ///
  /// Empty until [loadPlans] resolves, and stays empty (last-known state) on a
  /// failed read.
  List<MagicStarterPlan> get plans => _plans;

  /// The current cycle's usage stats, with the consumer's copy already paired
  /// on by [usageCopy].
  ///
  /// Every resource the producer reported survives, in the order it sent them,
  /// including one the consumer's copy table cannot name: a gate looks a
  /// resource up by [UsageStat.key] and does not need a word for it. Such a stat
  /// keeps a null [UsageStat.label], and NAMING it is the renderer's problem,
  /// which is why the meter grid skips it rather than falling back to the wire
  /// key.
  List<UsageStat> get usage => _usage;

  /// The customer's billing history, most recent first. Empty until
  /// [loadInvoices] resolves; stays empty on a failed read.
  List<Invoice> get invoices => _invoices;

  /// The card on file and the next renewal date, or `null` until
  /// [loadPaymentMethod] resolves.
  ///
  /// A resolved value does not imply a card: the producer soft-fails a rail
  /// outage to an all-null [PaymentMethod] with a 200, and
  /// [PaymentMethod.available] is its own answer to which of the two it was.
  PaymentMethod? get paymentMethod => _paymentMethod;

  /// Whether [loadPaymentMethod] is still in flight.
  ///
  /// Gates the payment-method card and nothing else: it is the lazy
  /// rail-backed read, and a slow Stripe must not hold up the plan grid.
  bool get pmLoading => _pmLoading;

  /// Whether [loadPaymentMethod] failed at the transport level (a network
  /// error, a non-2xx, or a payload this build cannot read).
  ///
  /// Distinct from [PaymentMethod.available], which is the producer's own
  /// answer: this one covers a client-side failure no server flag can express,
  /// because the response never arrived.
  bool get pmError => _pmError;

  /// The NAME of another of the caller's teams that a store account already
  /// funds, or `null` when none does and while the read has not resolved.
  ///
  /// One field rather than a `bool` beside a name, because the two could
  /// disagree: a refusal this screen cannot name is a refusal it cannot explain,
  /// and every team has a name, so "blocked" and "named" are the same state.
  String? get storeFundedTeam => _storeFundedTeam;

  /// Whether the consumer registered a [storeFundedTeamReader] at all.
  ///
  /// This exists because [storeFundedTeam] has TWO null sources with opposite
  /// meanings, and the store-purchase gate has to tell them apart:
  ///
  /// 1. NOT registered. The question was never asked and never can be, so
  ///    nothing here can promise a second purchase will not transfer another
  ///    team's subscription away. That has to refuse.
  /// 2. Registered, and the answer was `null`. Either no other team is funded,
  ///    or the read failed and degraded permissively, which is the deliberate
  ///    fail-open documented on [loadStoreFundedTeam]. That stays permissive.
  ///
  /// A resolved name is the third state and lives in [storeFundedTeam] itself.
  bool get storeCheckRegistered => storeFundedTeamReader != null;

  // ---------------------------------------------------------------------------
  // The six gates: what this screen may offer, and to whom
  // ---------------------------------------------------------------------------
  //
  // Every one of them is PERMISSIVE while the read behind it is unresolved, and
  // that is the property to preserve rather than an accident of the ordering.
  // These are plain nullable fields that nothing in `MagicController` resets, so
  // a gate reads "not answered yet" as "do not stand in the way": a screen that
  // hid its own management affordances for the duration of one fetch would
  // flicker them in, and a slow or failed read would leave a paying customer
  // with no way to reach their card. The server still refuses what it must.
  //
  // The one exception is the store-purchase gate, and it is an exception on
  // purpose: see [canPurchaseViaStore].

  /// Whether a store owns this subscription, so the store owns its management
  /// too and nothing here may offer a competing purchase or a web billing
  /// surface.
  bool get storeManaged =>
      _manageVia == ManageVia.appStore || _manageVia == ManageVia.playStore;

  /// Whether the signed-in user owns the team, or `null` when that is genuinely
  /// unresolved.
  ///
  /// Tri-state rather than a bool, because the two negative answers lead
  /// somewhere different: a KNOWN non-owner is told the owner handles billing,
  /// while an UNRESOLVED membership must not stand between an owner and paying.
  /// A consumer that registered no [isOwnerReader], or one that has no signed-in
  /// user to ask about yet, is unresolved rather than "not the owner"; the gates
  /// below refuse only on a known `false`.
  ///
  /// Resolved on every read rather than cached, so a team switch answers as the
  /// team now on screen. The reader is the only source: this package has no
  /// membership role of its own to fall back on, so an absent reader cannot be
  /// improved on by guessing.
  bool? get isOwner => isOwnerReader?.call();

  /// Whether the web billing portal is a surface this caller can reach.
  ///
  /// True while [manageVia] is unresolved (see its docblock), false on
  /// [ManageVia.none] because the portal endpoint refuses a customer with no
  /// billing account, and false on both store rails, whose management belongs to
  /// the store.
  ///
  /// A known non-owner loses it too: the portal endpoint resolves its team
  /// through the same owner check as the write routes, so a member's "Update"
  /// and "Receipt" buttons are 403s waiting to happen rather than actions. The
  /// rail decides WHERE management lives; the membership decides WHETHER this
  /// caller may go there.
  ///
  /// A build with no [webRail] loses it as well, and that is a separate fact
  /// from the entitlement's: the portal is a call this build has no
  /// implementation for, so the button would have nothing to invoke.
  bool get portalAvailable =>
      webRail != null &&
      (_manageVia == null || _manageVia == ManageVia.portal) &&
      isOwner != false;

  /// Whether this screen may offer to start or change a paid plan through the
  /// WEB rail.
  ///
  /// Three independent refusals: no web rail in this build (there is nothing to
  /// call), a store already charging this customer (a second rail must not open
  /// a parallel subscription, which the checkout endpoint also refuses with a
  /// 409), and a member who is not the owner (which the write routes refuse with
  /// a 403). The last two are affordances rather than enforcement; the server
  /// still decides.
  bool get canPurchaseViaWeb =>
      webRail != null && !storeManaged && isOwner != false;

  /// Whether this screen may offer to buy through the STORE rail.
  ///
  /// Five refusals. Four of them are the rail's own: no store rail in this build;
  /// a member who is not the owner; the web rail already charging this customer,
  /// which is the mirror image of the refusal above (whichever rail is second
  /// must not open a parallel subscription, and unlike an upgrade WITHIN the
  /// store's own subscription group that would be a second charge); and another
  /// of the caller's teams already funded by a store account, which a second
  /// purchase would transfer rather than duplicate.
  ///
  /// The two store [ManageVia] values are deliberately NOT refusals: the tiers
  /// share one subscription group, so buying the other tier there IS the upgrade
  /// path, and the store replaces rather than adds.
  ///
  /// The fifth refusal is this package's own and it is the one place a gate here
  /// is STRICT while unresolved. [storeFundedTeam] has two null sources with
  /// opposite meanings (see [storeCheckRegistered]), and reading them as one
  /// would make the transfer refusal unreachable in every app that registered no
  /// check: the notice above the plan grid would never render, "Restore
  /// purchases" would be offered, and the re-ask at the moment money moves would
  /// ask nothing. A registered check that FAILED keeps the deliberate fail-open,
  /// because the producer's transfer handling keeps the entitlement itself
  /// honest either way and what this gate prevents is a surprised customer. An
  /// unregistered check promises nothing at all, and nothing is not a promise
  /// this screen may spend a customer's subscription on.
  ///
  /// That is the opposite direction from [isOwner], where an absent answer is
  /// permissive, and both are right: an unresolved membership hides a button
  /// from a real owner who wants to pay, and the server would have refused a
  /// non-owner anyway, while an unasked transfer check hides nothing and permits
  /// a move the customer cannot undo.
  bool get canPurchaseViaStore =>
      storeRail != null &&
      isOwner != false &&
      _manageVia != ManageVia.portal &&
      storeCheckRegistered &&
      _storeFundedTeam == null;

  /// Whether this screen may offer to start or change a paid plan on ANY rail.
  ///
  /// The plan grid's CTA gate. No build serves both rails, so this is a union of
  /// two mutually exclusive answers rather than a choice between them; which one
  /// is live decides what a tap does.
  bool get canPurchase => canPurchaseViaWeb || canPurchaseViaStore;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  /// Dispatches all six reads AT ONCE and resolves when the last one settles.
  ///
  /// Parallel rather than sequential, and that is load-bearing rather than an
  /// optimisation: the six answers are independent, so awaiting them in turn
  /// would make the plan grid wait on an invoices page it does not need, and one
  /// slow rail would hold up the entire screen. Each call below starts its
  /// request before the next line runs, and the returned future never completes
  /// with an error because no read throws.
  Future<void> load() {
    return Future.wait<void>(<Future<void>>[
      loadEntitlement(),
      loadPlans(),
      loadUsage(),
      loadInvoices(),
      loadPaymentMethod(),
      loadStoreFundedTeam(),
    ]);
  }

  /// Reads the customer's current entitlement and republishes [currentPlanId],
  /// [manageVia] and [manageUrl].
  ///
  /// [manageVia] and [manageUrl] are republished whether or not the payload
  /// names a plan, because the rail is a separate fact from the tier: a customer
  /// whose `plan` is absent can still be billed through a store, and gating the
  /// rail behind a non-null plan would leave it unresolved for exactly the
  /// customers whose management surface is hardest to guess.
  ///
  /// Deliberate degradation on failure: [currentPlanId] keeps whatever it held
  /// (for a first read, `null`) instead of throwing, and no plan id is ever
  /// fabricated.
  Future<void> loadEntitlement() async {
    try {
      final BillingEntitlement entitlement = await billing.currentEntitlement();
      final String? plan = entitlement.plan;
      _manageVia = entitlement.manageVia;
      _manageUrl = entitlement.manageUrl;
      if (plan != null) {
        _currentPlanId = plan;
        _entitlementLoaded = true;
      }
      refreshUI();
    } catch (error) {
      _reportDegradation('currentEntitlement', error);
    }
  }

  /// Reads the plan catalogue, decodes each row into a [MagicStarterPlan] and
  /// republishes [plans].
  ///
  /// The contract answers rows verbatim, because a tier's prices, feature
  /// bullets and in-product caps are what the vendor sells rather than anything
  /// a payment rail understands, so the decode happens here.
  ///
  /// Deliberate degradation on failure: [plans] stays empty, so the plan grid
  /// renders its loading or empty state instead of crashing.
  Future<void> loadPlans() async {
    try {
      final List<Map<String, dynamic>> rows = await billing.getPlans();
      _plans = rows.map(MagicStarterPlan.fromMap).toList();
      refreshUI();
    } catch (error) {
      _reportDegradation('getPlans', error);
    }
  }

  /// Reads the current cycle's usage, pairs the consumer's copy onto it through
  /// [usageCopy] and republishes [usage].
  ///
  /// The pairing happens here rather than in the renderer so that a stat the
  /// copy table cannot name is carried with a null label all the way to the
  /// grid, which skips it. The alternative, dropping it here, would hide from a
  /// consumer that its catalogue is missing a resource the producer meters.
  ///
  /// Deliberate degradation on failure: [usage] stays empty, so the meter grid
  /// renders no rows instead of crashing.
  Future<void> loadUsage() async {
    try {
      _usage = usageCopy(await billing.getUsage());
      refreshUI();
    } catch (error) {
      _reportDegradation('getUsage', error);
    }
  }

  /// Reads the first page of the customer's billing history and republishes
  /// [invoices].
  ///
  /// Deliberate degradation on failure: [invoices] stays empty, so the history
  /// card renders no rows instead of crashing.
  Future<void> loadInvoices() async {
    try {
      final BillingInvoicesPage page = await billing.getInvoices();
      _invoices = page.invoices;
      refreshUI();
    } catch (error) {
      _reportDegradation('getInvoices', error);
    }
  }

  /// Reads the card on file and republishes [paymentMethod].
  ///
  /// This is the only read that dials a payment rail live, so it carries its own
  /// [pmLoading] and [pmError] instead of gating the rest of the screen. A
  /// transport-level failure sets [pmError]; the producer's own soft-fail (an
  /// all-null 200 on a rail outage) decodes cleanly into an all-null
  /// [PaymentMethod] instead, which the card renders as its empty state.
  ///
  /// [pmLoading] clears on BOTH arms, because a card stuck in its skeleton is
  /// indistinguishable from a rail that is still thinking.
  Future<void> loadPaymentMethod() async {
    try {
      _paymentMethod = await billing.getPaymentMethod();
      _pmLoading = false;
      refreshUI();
    } catch (error) {
      _pmLoading = false;
      _pmError = true;
      refreshUI();
      _reportDegradation('getPaymentMethod', error);
    }
  }

  /// Asks the consumer's [storeFundedTeamReader] whether a store account already
  /// funds another of the caller's teams, and republishes [storeFundedTeam] with
  /// its name when one does.
  ///
  /// Asked only on a build with a store rail, because it exists to gate a store
  /// purchase and a web build has none to gate: a screen with no store
  /// affordance would be spending a request on an answer it cannot use. Skipped
  /// entirely when no reader is registered, which [storeCheckRegistered] reports
  /// separately so the gate can refuse rather than guess.
  ///
  /// Deliberate degradation on failure: [storeFundedTeam] keeps whatever it
  /// held, which for a first read means `null` and therefore permissive. The
  /// producer's TRANSFER handling is what keeps the entitlement itself honest
  /// either way, so this check exists to stop a customer being surprised, not to
  /// stop the data being wrong.
  ///
  /// The degradation stays deliberate but it does NOT stay silent. This read is
  /// the only thing standing between a store purchase and transferring another
  /// team's subscription away, it fails permissive, and the purchase path asks
  /// it again at the moment money moves. Swallowing it silently let a real 500
  /// on this endpoint pass the transfer through with nothing in any log to
  /// explain it afterwards.
  ///
  /// It only ever SETS a name and never clears one, which is a consequence
  /// rather than an oversight: it runs at mount and again before a purchase, and
  /// the second call is only reachable while the answer was already `null` (a
  /// named refusal renders no CTA to tap), so a name-to-null transition has no
  /// trigger here. A future caller that could produce one has to publish the
  /// empty answer too.
  Future<void> loadStoreFundedTeam() async {
    final MagicStarterStoreFundedTeamReader? reader = storeFundedTeamReader;
    if (reader == null) return;

    try {
      // Inside the try, because resolving a rail is itself a call that can
      // fail: `PaymentsManager._optional` returns null for an unfilled role but
      // THROWS a BillingException when the role holds something that cannot
      // serve the contract, which is what a consumer's mistyped `extend` call
      // produces. Reading it above the try would let that escape `load()`,
      // where `onInit` fires it unawaited and nothing is left to catch it.
      if (storeRail == null) return;

      final String? name = await reader();
      if (name == null || name.isEmpty) return;

      _storeFundedTeam = name;
      refreshUI();
    } catch (error) {
      _reportDegradation('storeFundedTeamReader', error);
    }
  }

  /// Records a read that failed and left its own field at last-known state.
  ///
  /// Deliberate degradation is not the same as a swallowed error: every arm
  /// above keeps the screen alive, and this is what keeps the reason visible
  /// afterwards. A billing surface that renders no invoices with nothing in any
  /// log is indistinguishable from a customer who has none.
  void _reportDegradation(String read, Object error) {
    Log.error(
      '[MagicStarterBillingController] $read failed, so its section keeps '
      'last-known state for this session: $error',
    );
  }

  /// Resolves the web rail for this controller.
  ///
  /// With nothing injected it is the build's own rail. With a fake injected it
  /// is that fake WHEN the fake serves the contract, and `null` otherwise:
  /// reaching for [Payments.web] behind an injected read fake would hand a test
  /// the real driver for half its calls.
  WebBillingService? _resolveWebRail() {
    // Typed `Object?` rather than `BillingService?`, and that is load-bearing
    // rather than loose: the two contracts are unrelated (neither extends the
    // other, so one object may serve both), and Dart only promotes a variable to
    // a SUBTYPE of its declared type. A `BillingService?` local therefore never
    // promotes to `WebBillingService` and the test below would need a cast to
    // compile.
    final Object? injected = _injectedBilling;
    if (injected == null) return Payments.web;

    return injected is WebBillingService ? injected : null;
  }

  /// Resolves the store rail for this controller, on the same terms as
  /// [_resolveWebRail]: the build's own rail with nothing injected, and an
  /// injected fake only when that fake serves the contract.
  ///
  /// Typed `Object?` for the same reason as there: [BillingService] and
  /// [StoreBillingService] are unrelated contracts, so a `BillingService?` local
  /// would never promote to the subtype and the test below would need a cast.
  StoreBillingService? _resolveStoreRail() {
    final Object? injected = _injectedBilling;
    if (injected == null) return Payments.store;

    return injected is StoreBillingService ? injected : null;
  }
}
