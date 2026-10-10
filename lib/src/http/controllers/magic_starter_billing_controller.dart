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

/// Renders an integer the way the consumer's locale writes one.
///
/// Every count this screen shows goes through it: the used and limit halves of
/// each usage meter. A plan card's price is not a count: the producer formats
/// it, and a store build shows the store's own string.
///
/// Consumer-supplied for the same reason as [MagicStarterUsageCopy], and it is
/// the more dangerous of the two because its wrong answer is legible. A
/// thousands separator is a comma in English and a full stop in Turkish, and
/// this package cannot know which one an adopter writes. Shipping a default
/// would re-ship a defect this ecosystem has already shipped and fixed, where
/// two private copies of a separator helper both hardcoded a comma and a
/// Turkish billing page reported `83,365` for a number Turkish writes as
/// `83.365`. A consumer with no locale-aware formatter passes
/// `(int n) => n.toString()`, which is a visible choice rather than a silent
/// one.
typedef MagicStarterNumberFormat = String Function(int value);

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

/// The four entitlement facts a store purchase can move, read together.
///
/// A purchase is confirmed when the backend's answer DIFFERS from the one taken
/// before the sheet opened, and no single field is enough to see that: an
/// upgrade moves [plan] and [product], a move between two products of one tier
/// moves only [product], and a store subscription replacing a web one moves
/// [provider]. A Play base-plan switch the backend names by its bare
/// subscription id moves none of those (its [product] is null on both sides),
/// so [currentPeriodEnd] is the only field that sees it. The price is that a
/// renewal landing inside the wait confirms it early, which the wait's cap
/// already bounds. A record, so that `==` is the whole comparison.
typedef MagicStarterEntitlementSnapshot = ({
  String? plan,
  String? product,
  BillingProvider provider,
  DateTime? currentPeriodEnd,
});

/// How a store purchase ended, for the screen to report.
///
/// An exception is NOT an outcome: a rail failure is thrown by
/// [MagicStarterBillingController.purchaseInStoreAndWait] and reported by its
/// code, and a store-pending purchase is one of them.
enum MagicStarterStorePurchaseOutcome {
  /// The customer closed the sheet. Nothing was bought and nothing is waiting.
  dismissed,

  /// The backend's entitlement moved, so the purchase is reflected.
  confirmed,

  /// The store applies the change at the end of the current paid period
  /// ([StoreChangeTiming.atRenewal]), so the entitlement is not expected to
  /// move now and nothing was polled.
  deferred,

  /// The store reported the purchase and the backend had not reflected it by
  /// the end of the wait. Not a failure: the webhook may still land.
  processing,

  /// The wait was cancelled (the screen closed, or the team switched) before it
  /// reached an answer, so there is nothing left to report to.
  abandoned,
}

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
class MagicStarterBillingController extends MagicController
    implements SessionScoped {
  /// Creates the billing controller.
  ///
  /// [billingService] overrides [Payments.billing] for tests. A fake that also
  /// implements [WebBillingService] or [StoreBillingService] supplies that rail
  /// as well (see [webRail] and [storeRail]); one that implements neither models
  /// a build with no rail at all, which is exactly the state where no purchase
  /// or portal affordance may render.
  MagicStarterBillingController({
    required this.usageCopy,
    required this.formatNumber,
    this.storeFundedTeamReader,
    this.isOwnerReader,
    @visibleForTesting BillingService? billingService,
  }) : _injectedBilling = billingService;

  /// Pairs the consumer's display copy onto every [UsageStat] the producer
  /// reported. Required; see the class docblock for why it has no default.
  final MagicStarterUsageCopy usageCopy;

  /// Renders every integer this screen shows, in the consumer's locale.
  ///
  /// Required, and it lives here rather than on the view because the view
  /// registry's builder takes no arguments, so a view parameter would need a
  /// default at the registration site and every default available there is a
  /// wrong answer shipped silently. See [MagicStarterNumberFormat].
  final MagicStarterNumberFormat formatNumber;

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

  /// Bumped ONLY by [resetForSession], never by an individual read.
  ///
  /// Every read (batch or standalone) captures this before its first await
  /// and compares it after every one: a read from a session a switch has
  /// since superseded must never publish, no matter which of the six kinds
  /// it is. Kept apart from [_latestRead] on purpose: a single counter that
  /// every read shared used to conflate "a session changed" with "a newer
  /// read of the same kind started", so a standalone `loadEntitlement()`
  /// bumped the ONE counter a `load()` batch's other five reads were also
  /// reading against and dropped every one of them, including invoices and
  /// the payment-method card, which left [pmLoading] stuck at `true`
  /// forever. This field is the session axis; [_latestRead] below is the
  /// per-kind axis, and the two never interact.
  int _sessionGeneration = 0;

  /// Guards each of the six reads against landing after a NEWER read of the
  /// SAME kind superseded it, keyed by [_entitlementKey] and its five
  /// siblings below.
  ///
  /// Per-kind rather than shared, so a standalone retry of one read (the
  /// store-purchase gate re-asks [loadStoreFundedTeam] before money moves,
  /// say) only ever supersedes an earlier read of THAT kind and leaves the
  /// other five, batch or standalone, untouched. See [_sessionGeneration]
  /// for the other, independent guard every read also carries.
  final LatestRead _latestRead = LatestRead();

  static const String _entitlementKey = 'entitlement';
  static const String _plansKey = 'plans';
  static const String _usageKey = 'usage';
  static const String _invoicesKey = 'invoices';
  static const String _paymentMethodKey = 'paymentMethod';
  static const String _storeFundedTeamKey = 'storeFundedTeam';
  static const String _storeProductsKey = 'storeProducts';

  String? _currentPlanId;
  bool _entitlementLoaded = false;
  ManageVia? _manageVia;
  String? _manageUrl;
  bool? _renews;
  BillingCycle? _cycle;
  PlanStatus _planStatus = PlanStatus.none;
  DateTime? _trialEndsAt;
  List<MagicStarterPlan> _plans = const <MagicStarterPlan>[];
  List<UsageStat> _usage = const <UsageStat>[];
  MagicPaginator<Invoice>? _invoicePages;
  PaymentMethod? _paymentMethod;
  bool _pmLoading = true;
  bool _pmError = false;
  String? _storeFundedTeam;
  String? _awaitingProductKey;

  /// The entitlement as it stood before the sheet opened, set once the store
  /// has REPORTED the purchase (completed or pending), or `null` while the
  /// sheet is still up. Any read that differs from it ends the wait.
  MagicStarterEntitlementSnapshot? _awaitingBaseline;

  /// Ends the wait [_waitWindow] after the store reported, whether or not
  /// anything is still polling.
  Timer? _awaitingWindow;
  Map<String, StoreProductOffer> _storeOffers =
      const <String, StoreProductOffer>{};
  MagicStarterEntitlementSnapshot _entitlementSnapshot = _emptySnapshot;

  /// Bumped by [cancelWait], so a poll that was inside a read when it was
  /// cancelled can tell on resuming that it no longer has anyone to answer to.
  int _waitEpoch = 0;
  Timer? _waitTimer;
  Completer<bool>? _waitSleep;

  /// The empty snapshot every session starts from, and the one a reset returns
  /// to: a customer no rail has been asked about.
  static const MagicStarterEntitlementSnapshot _emptySnapshot = (
    plan: null,
    product: null,
    provider: BillingProvider.none,
    currentPeriodEnd: null,
  );

  /// How long a reported store purchase may hold the store gate shut.
  ///
  /// The sum of [_pollBackoff]. A purchase the backend has not reflected by
  /// then may still be pending for days (parental approval, a deferred
  /// payment), and a gate shut that long hides the store from a customer who
  /// was already told the purchase is on its way.
  static const Duration _waitWindow = Duration(seconds: 60);

  /// The gaps between the entitlement reads that follow a store purchase, which
  /// sum to [_waitWindow].
  ///
  /// Geometric at first because the webhook usually lands within seconds, and
  /// flat at the end because a late one is worth waiting for and not worth a
  /// request every second.
  static const List<Duration> _pollBackoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

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

  /// Whether the subscription will renew at the end of its paid period, or
  /// `null` while no entitlement read has answered.
  ///
  /// `false` is a CANCELLED subscription that is still granting: on this rail a
  /// cancellation is normally end-of-period, so the customer keeps their tier
  /// and the date attached to it stops being a renewal and becomes an expiry.
  /// The renewal line is the one place that distinction is visible, and without
  /// this field it told somebody who had just cancelled that their plan renews.
  ///
  /// `null` is read as renewing, which keeps the sentence unchanged for the
  /// window before the entitlement resolves. That window shows no date either,
  /// so the line is already saying it does not know.
  bool? get renews => _renews;

  /// How often the customer is charged, or `null` when nothing has said.
  ///
  /// What they BOUGHT, resolved by the producer from the price their
  /// subscription sits on. Not the cycle a catalogue toggle is displaying: the
  /// two are easy to conflate and conflating them is how a screen came to tell
  /// every paying customer they were billed annually.
  ///
  /// Null is a real answer and has to render as one. It covers a customer on no
  /// rail, a price whose cycle the vendor's config never declared, and a STORE
  /// subscription, whose product id the producer's Stripe catalogue cannot name.
  BillingCycle? get cycle => _cycle;

  /// Where the paid plan stands in its lifecycle, or [PlanStatus.none] before
  /// any entitlement read has answered.
  ///
  /// Published for ONE question the other fields cannot answer: whether a
  /// payment has failed. Both dunning statuses still grant, so `subscribed` is
  /// true and the renewal line reads normally for a customer whose card just
  /// bounced. Nothing on the screen contradicted that until this arrived.
  ///
  /// Not a gate. Whether a status entitles is the producer's answer and comes
  /// through `subscribed`; a second definition here could disagree with the one
  /// that actually decides access.
  PlanStatus get planStatus => _planStatus;

  /// When the free trial ends, or `null` when the customer is not on one.
  ///
  /// Non-null only while [planStatus] is [PlanStatus.trialing], so a date the
  /// producer left on an entitlement that has since converted is never shown as
  /// a trial. A web trial reads `trial_ends_at`; a store trial carries no such
  /// field and ends at the current period end, which is why the entitlement's
  /// period end is the fallback (see `BillingEntitlement.trialEndsAt`).
  ///
  /// `null` while trialing is a real answer too: the producer named no date, and
  /// the screen must say nothing about one rather than invent it.
  DateTime? get trialEnd {
    if (_planStatus != PlanStatus.trialing) return null;

    return _trialEndsAt ?? _entitlementSnapshot.currentPeriodEnd;
  }

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
  ///
  /// The pages fetched so far, not the whole history: see [invoicePages].
  List<Invoice> get invoices => _invoicePages?.items ?? const <Invoice>[];

  /// The paginator behind [invoices], or null before the first load.
  ///
  /// Exposed so a view can render the history lazily and ask for older invoices
  /// as the reader scrolls. It exists because the producer has always paged this
  /// endpoint and this client used to throw the cursor away: `getInvoices()`
  /// returns a `BillingInvoicesPage` carrying `nextCursor`, and reading only
  /// `page.invoices` meant a customer with more than one page could never see
  /// past the first.
  ///
  /// A FETCHER paginator, not a url one, because the invoices arrive through
  /// [BillingService] rather than from an endpoint this class should know about:
  /// a store build's implementation throws rather than answering, and a test
  /// installs a fake. Pointing a url paginator at `/billing/invoices` would walk
  /// around both.
  MagicPaginator<Invoice>? get invoicePages => _invoicePages;

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

  /// The catalogue key of a store purchase the backend has not confirmed yet,
  /// or `null` when nothing is waiting.
  ///
  /// Set when the sheet opens and kept when the store reports a completed
  /// transaction or a pending one (parental approval, a deferred payment). The
  /// store's `true` is the store's word and the rail's webhook is the
  /// authority, so between the two a second tap would be a second charge;
  /// [canPurchaseViaStore] refuses for as long as this is set.
  ///
  /// Bounded, so it can never hold the gate shut for the session. It clears on
  /// the first entitlement read that names the product OR differs from the
  /// pre-sheet snapshot (a Play purchase the producer names only by its bare
  /// store id decodes with no product key at all), when [_waitWindow] runs out
  /// after the store reported, and on a session reset.
  String? get awaitingProductKey => _awaitingProductKey;

  /// What the store charges for each catalogue product, keyed by catalogue key.
  ///
  /// Empty on a build with no store rail, until [loadStoreProducts] resolves,
  /// and after a failed read. A key the store has no product for is absent, and
  /// the screen renders that card without a price rather than with a guessed
  /// one.
  Map<String, StoreProductOffer> get storeOffers => _storeOffers;

  /// The entitlement as the last read answered it. See
  /// [MagicStarterEntitlementSnapshot] for why it is read as a whole.
  MagicStarterEntitlementSnapshot get entitlementSnapshot =>
      _entitlementSnapshot;

  /// The catalogue facts a store purchase needs to tell an upgrade from a
  /// downgrade: the tiers in the catalogue's own order (cheapest first), the
  /// tier of every product key the rows list, and the tier of every store
  /// product id they name.
  ///
  /// Grandfathered products are IN both maps, deliberately: the customer may
  /// hold one, and the rail can only rank the subscription it is replacing if
  /// something names its tier. A store id is the only handle on a held product
  /// no current offering carries, which is why both stores' ids map too.
  ///
  /// Built from [plans] on every read rather than cached, so it can never
  /// describe a catalogue other than the one on screen.
  PurchaseContext get purchaseContext {
    return PurchaseContext(
      tierOrder: <String>[for (final MagicStarterPlan plan in _plans) plan.id],
      tierOfProduct: <String, String>{
        for (final MagicStarterProduct product in _catalogueProducts)
          product.key: product.tier,
      },
      tierOfStoreProduct: <String, String>{
        for (final MagicStarterProduct product in _catalogueProducts)
          for (final String? id in <String?>[
            product.storeIds.appStore,
            product.storeIds.play,
          ])
            ?id: product.tier,
      },
    );
  }

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
  /// Seven refusals. Six of them are the rail's own: no store rail in this
  /// build; a member who is not the owner; the web rail already charging this
  /// customer, which is the mirror image of the refusal above (whichever rail is
  /// second must not open a parallel subscription, and unlike an upgrade WITHIN
  /// the store's own subscription group that would be a second charge); the
  /// OTHER store already charging this customer, for the same reason, because an
  /// App Store subscription cannot be replaced from Google Play or the reverse;
  /// a purchase still waiting for the backend to confirm it (see
  /// [awaitingProductKey]); and another of the caller's teams already funded by
  /// a store account, which a second purchase would transfer rather than
  /// duplicate.
  ///
  /// The store that sold the subscription is read off the rail's own
  /// [StoreBillingService.store] against [manageVia], never off the running
  /// platform. That store's own [ManageVia] value is deliberately NOT a refusal:
  /// the tiers share one subscription group, so buying the other tier there IS
  /// the upgrade path, and the store replaces rather than adds.
  ///
  /// The seventh refusal is this package's own and it is the one place a gate here
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
  bool get canPurchaseViaStore {
    final StoreBillingService? store = storeRail;
    if (store == null) return false;

    return isOwner != false &&
        _manageVia != ManageVia.portal &&
        !(storeManaged && _manageVia != store.store) &&
        _awaitingProductKey == null &&
        storeCheckRegistered &&
        _storeFundedTeam == null;
  }

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

  /// Drops every field the six reads populate, publishes the cleared state,
  /// then refetches for the identity that is now authenticated.
  ///
  /// Called on login and on team switch (see [SessionScoped]),
  /// never from [onInit]: this controller is a `Magic.findOrPut` singleton
  /// and `onInit` runs once per instance lifetime, so without this reset a
  /// team switch would leave the previous team's plan, invoices, usage and
  /// card on screen until the app restarts.
  ///
  /// Clears BEFORE refetching. The six `load*` methods are deliberately
  /// non-destructive (a transport failure keeps last-known-good state so a
  /// blip does not blank a card), and that is the wrong behaviour across an
  /// identity change: a failed refetch must leave the screen empty, never
  /// populated with the previous team's rows.
  ///
  /// Every field resets to the same initializer its declaration carries.
  /// [pmLoading] is worth calling out explicitly: it resets to `true`, the
  /// same value its field declaration starts at, and NOT to `false`. A card
  /// that reset to `pmLoading: false` with a null [paymentMethod] would
  /// render "no card on file" for the new team before anything had been
  /// read, a confident wrong answer rather than a loading state.
  ///
  /// Three fields are deliberately left untouched because they are not
  /// session state: [usageCopy], [storeFundedTeamReader] and [isOwnerReader]
  /// are consumer collaborators supplied at construction, and [billing],
  /// [webRail] and [storeRail] are `late final` rail resolutions that a
  /// reassignment would not even compile against.
  @override
  Future<void> resetForSession() async {
    // Drop whatever a load in flight from the PREVIOUS session answers with.
    // Without this, a read a switch interrupted mid-flight can land AFTER
    // this method's own fresh load has already published team B's rows,
    // overwriting them with team A's. The session axis alone is enough here:
    // every per-kind key below also gets a fresh token from the fresh
    // [load] this method calls, but bumping the generation is what catches a
    // read of a kind that fresh load has not reached its first `await` for
    // yet.
    _sessionGeneration++;

    _currentPlanId = null;
    _entitlementLoaded = false;
    _manageVia = null;
    _manageUrl = null;
    _renews = null;
    _cycle = null;
    _planStatus = PlanStatus.none;
    _trialEndsAt = null;
    _plans = const <MagicStarterPlan>[];
    _usage = const <UsageStat>[];
    _invoicePages?.dispose();
    _invoicePages = null;
    _paymentMethod = null;
    _pmLoading = true;
    _pmError = false;
    _storeFundedTeam = null;
    _endAwaiting();
    _storeOffers = const <String, StoreProductOffer>{};
    _entitlementSnapshot = _emptySnapshot;
    cancelWait();
    refreshUI();

    await load();
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
  /// [manageVia], [manageUrl] and [renews].
  ///
  /// [manageVia], [manageUrl] and [renews] are republished whether or not the
  /// payload names a plan, because each is a separate fact from the tier: a
  /// customer whose `plan` is absent can still be billed through a store, and
  /// gating the rail behind a non-null plan would leave it unresolved for
  /// exactly the customers whose management surface is hardest to guess.
  /// [renews] rides on that same reasoning, and it is the field this read exists
  /// to publish: a screen that cannot see it tells a customer who has already
  /// cancelled that their plan renews.
  ///
  /// Deliberate degradation on failure: [currentPlanId] keeps whatever it held
  /// (for a first read, `null`) instead of throwing, and no plan id is ever
  /// fabricated.
  Future<void> loadEntitlement() async {
    final int session = _sessionGeneration;
    final int readToken = _latestRead.begin(_entitlementKey);
    try {
      final BillingEntitlement entitlement = await billing.currentEntitlement();
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _entitlementKey)) return;

      final String? plan = entitlement.plan;
      _manageVia = entitlement.manageVia;
      _manageUrl = entitlement.manageUrl;
      _renews = entitlement.renews;
      _cycle = entitlement.cycle;
      _planStatus = entitlement.planStatus;
      _trialEndsAt = entitlement.trialEndsAt;
      _entitlementSnapshot = (
        plan: plan,
        product: entitlement.productKey,
        provider: entitlement.provider,
        currentPeriodEnd: entitlement.currentPeriodEnd,
      );
      if (_awaitingProductKey != null &&
          (entitlement.productKey == _awaitingProductKey ||
              (_awaitingBaseline != null &&
                  _entitlementSnapshot != _awaitingBaseline))) {
        _endAwaiting();
      }
      if (plan != null) {
        _currentPlanId = plan;
        _entitlementLoaded = true;
      }
      refreshUI();
    } catch (error) {
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _entitlementKey)) return;
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
  ///
  /// On a store build it then prices that catalogue through
  /// [loadStoreProducts], because the keys to ask the store about are the
  /// catalogue's own.
  Future<void> loadPlans() async {
    final int session = _sessionGeneration;
    final int readToken = _latestRead.begin(_plansKey);
    try {
      final List<Map<String, dynamic>> rows = await billing.getPlans();
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _plansKey)) return;

      _plans = rows.map(MagicStarterPlan.fromMap).toList();
      refreshUI();
      await loadStoreProducts();
    } catch (error) {
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _plansKey)) return;
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
    final int session = _sessionGeneration;
    final int readToken = _latestRead.begin(_usageKey);
    try {
      final List<UsageStat> stats = await billing.getUsage();
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _usageKey)) return;

      _usage = usageCopy(stats);
      refreshUI();
    } catch (error) {
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _usageKey)) return;
      _reportDegradation('getUsage', error);
    }
  }

  /// Reads the first page of the customer's billing history and republishes
  /// [invoices].
  ///
  /// Deliberate degradation on failure: [invoices] stays empty, so the history
  /// card renders no rows instead of crashing.
  ///
  /// Two failure paths, one report. The paginator parks an `Exception` on
  /// [MagicPaginator.error] and returns normally, but it catches `on Exception`
  /// and deliberately lets an `Error` through. [BillingService] is the
  /// consumer's own class, so a bad cast in its `getInvoices` raises a
  /// `TypeError` that would escape this read, fail the `Future.wait` in [load],
  /// and reach `onInit`'s unawaited call as an unhandled zone error. The other
  /// five reads degrade rather than throw, and [load] documents that none of
  /// them throws; this one has to hold up its end.
  Future<void> loadInvoices() async {
    final int session = _sessionGeneration;
    final int readToken = _latestRead.begin(_invoicesKey);
    final MagicPaginator<Invoice> pages = _invoicePages ?? _buildInvoicePages();
    _invoicePages = pages;

    Object? failure;
    try {
      await pages.refresh();
      failure = pages.error;
    } catch (error) {
      failure = error;
    }

    if (session != _sessionGeneration) return;
    if (!_latestRead.isCurrent(readToken, _invoicesKey)) return;

    if (failure != null) {
      _reportDegradation('getInvoices', failure);
    }
    refreshUI();
  }

  /// Builds the invoice paginator over [BillingService.getInvoices].
  ///
  /// `isFirst` is what the fetcher branches on rather than the cursor being
  /// null, because a refresh has to start over: the producer's first page is
  /// addressed by passing no cursor at all, so a reset and a continuation would
  /// otherwise be indistinguishable.
  MagicPaginator<Invoice> _buildInvoicePages() {
    return MagicPaginator<Invoice>.fetcher(
      fetch: (MagicPageRequest request) async {
        final BillingInvoicesPage page = await billing.getInvoices(
          cursor: request.isFirst ? null : request.cursor,
        );

        return MagicPage<Invoice>(
          items: page.invoices,
          nextCursor: page.nextCursor,
        );
      },
    );
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
    final int session = _sessionGeneration;
    final int readToken = _latestRead.begin(_paymentMethodKey);
    try {
      final PaymentMethod method = await billing.getPaymentMethod();
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _paymentMethodKey)) return;

      _paymentMethod = method;
      _pmLoading = false;
      refreshUI();
    } catch (error) {
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _paymentMethodKey)) return;

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
    final int session = _sessionGeneration;
    final int readToken = _latestRead.begin(_storeFundedTeamKey);
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
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _storeFundedTeamKey)) return;
      if (name == null || name.isEmpty) return;

      _storeFundedTeam = name;
      refreshUI();
    } catch (error) {
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _storeFundedTeamKey)) return;
      _reportDegradation('storeFundedTeamReader', error);
    }
  }

  /// Asks the store what it charges for every SELLABLE product in [plans] that
  /// has an id in THIS store and republishes [storeOffers]. A grandfathered
  /// product is never offered, and neither is one this store carries no id for,
  /// so neither price is asked for.
  ///
  /// A store build shows the store's own localised price and not the
  /// catalogue's figure: the store decides currency, tax and rounding, and App
  /// Review rejects a screen whose price disagrees with the purchase sheet. One
  /// request for every key rather than one per card, because the answer is
  /// needed by the whole grid at once.
  ///
  /// Skipped on a build with no store rail, and when the catalogue names no
  /// product. Deliberate degradation on failure, and not a silent one:
  /// [storeOffers] keeps what it held, the card falls back to saying the price
  /// is shown in the store, and the reason goes to the log.
  Future<void> loadStoreProducts() async {
    final int session = _sessionGeneration;
    final int readToken = _latestRead.begin(_storeProductsKey);

    try {
      // Inside the try for the reason [loadStoreFundedTeam] gives: resolving a
      // rail can itself throw.
      final StoreBillingService? store = storeRail;
      if (store == null) return;

      final ManageVia thisStore = store.store;
      final List<String> keys = <String>[
        for (final MagicStarterPlan plan in _plans)
          for (final MagicStarterProduct product in plan.storeProducts(
            thisStore,
          ))
            product.key,
      ];
      if (keys.isEmpty) return;

      final Map<String, StoreProductOffer> offers = await store.products(keys);
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _storeProductsKey)) return;

      _storeOffers = offers;
      refreshUI();
    } catch (error) {
      if (session != _sessionGeneration) return;
      if (!_latestRead.isCurrent(readToken, _storeProductsKey)) return;
      _reportDegradation('storeProducts', error);
    }
  }

  /// Buys [product] through the STORE rail with this catalogue's
  /// [purchaseContext], and answers whether the store reported a completed
  /// transaction.
  ///
  /// The caller gates on [canPurchaseViaStore] and re-asks
  /// [loadStoreFundedTeam] before calling; this method owns the one refusal
  /// the gate cannot see at render time, a purchase already waiting, which a
  /// second tap can race. It throws [BillingException] with
  /// [BillingErrorCode.pending] for that, and lets every rail failure
  /// propagate for the screen to report.
  ///
  /// A completed or pending purchase is held in [awaitingProductKey] until the
  /// entitlement moves or [_waitWindow] runs out (see [awaitingProductKey]). A
  /// dismissed sheet (`false`) or a failure leaves nothing to wait for. The
  /// entitlement is NOT re-read here: the caller does that after telling the
  /// customer, so the toast is not held up by a read.
  ///
  /// Throws [UnsupportedPlatformException] in a build with no store rail.
  Future<bool> purchaseInStore(MagicStarterProduct product) async {
    final StoreBillingService? store = storeRail;
    if (store == null) {
      throw const UnsupportedPlatformException(
        'This build has no store rail to purchase through.',
      );
    }
    if (_awaitingProductKey != null) {
      throw const BillingException(
        'A store purchase is already waiting for confirmation.',
        code: BillingErrorCode.pending,
      );
    }

    // 1. Hold the gate shut BEFORE the sheet opens, so a tap racing this one
    //    cannot start a second purchase while the first is still in flight.
    //    The baseline is taken now, while the answer cannot have moved yet.
    final MagicStarterEntitlementSnapshot before = _entitlementSnapshot;
    _awaitingProductKey = product.key;
    refreshUI();

    try {
      final bool bought = await store.purchase(
        product.key,
        context: purchaseContext,
      );

      // 2. A dismissed sheet bought nothing, so there is nothing to wait for;
      //    a reported one waits, but only for so long.
      if (bought) {
        _startWaitWindow(before);
      } else {
        _clearAwaiting();
      }

      return bought;
    } catch (error) {
      // 3. A pending purchase may still settle into a charge, so it waits on
      //    the same bounded terms; every other failure released the money path.
      if (_isPending(error)) {
        _startWaitWindow(before);
      } else {
        _clearAwaiting();
      }
      rethrow;
    }
  }

  /// Buys [product] and then waits for the backend to reflect it, which is the
  /// whole of what a customer needs from a purchase: a sheet that closed on
  /// `true` is the STORE's word, and the plan they see is the backend's.
  ///
  /// 1. The entitlement is snapshotted BEFORE the sheet opens: afterwards the
  ///    answer may already have moved.
  /// 2. A dismissed sheet ends it. A thrown [BillingException] propagates
  ///    exactly as [purchaseInStore] throws it, and a PENDING one still polls
  ///    in the background, so the gate reopens the moment the backend reflects
  ///    the purchase rather than only when the window runs out.
  /// 3. When the rail says the change applies at renewal
  ///    ([StoreBillingService.lastChangeTiming]), the entitlement is NOT
  ///    expected to move and polling would only run out the clock. The wait
  ///    flag is released and the screen reports the pre-sheet period end. The
  ///    rail's answer is the only one asked: it knows what the store will do,
  ///    and a guess from the catalogue's tier order told a customer their plan
  ///    changed later when the store changed it now.
  /// 4. Anything else, an unknown timing included, polls on [_pollBackoff]
  ///    (60 s in all) until the snapshot differs.
  Future<MagicStarterStorePurchaseOutcome> purchaseInStoreAndWait(
    MagicStarterProduct product,
  ) async {
    // 1. What the backend said BEFORE the sheet. A purchase already waiting is
    //    refused by [purchaseInStore] with the same pending code a store
    //    reports, and that refusal must not start a second poll.
    final MagicStarterEntitlementSnapshot before = _entitlementSnapshot;
    final bool alreadyWaiting = _awaitingProductKey != null;

    // 2. The sheet.
    final bool bought;
    try {
      bought = await purchaseInStore(product);
    } catch (error) {
      if (!alreadyWaiting && _isPending(error)) {
        unawaited(_awaitEntitlementChange(before));
      }
      rethrow;
    }
    if (!bought) return MagicStarterStorePurchaseOutcome.dismissed;

    // 3. Nothing to poll for.
    if (storeRail?.lastChangeTiming == StoreChangeTiming.atRenewal) {
      _clearAwaiting();

      return MagicStarterStorePurchaseOutcome.deferred;
    }

    // 4. Poll.
    return _awaitEntitlementChange(before);
  }

  /// Stops a running wait and releases whoever is awaiting it with
  /// [MagicStarterStorePurchaseOutcome.abandoned].
  ///
  /// Called when the screen closes and on a session switch, so that no poll
  /// outlives the thing it would report to. It does NOT release
  /// [awaitingProductKey]: a screen closing says nothing about whether the
  /// store charged, so the gate stays shut on the terms [awaitingProductKey]
  /// describes, the [_waitWindow] included.
  void cancelWait() {
    _waitEpoch++;
    _waitTimer?.cancel();
    _waitTimer = null;

    final Completer<bool>? sleeping = _waitSleep;
    _waitSleep = null;
    if (sleeping != null && !sleeping.isCompleted) sleeping.complete(false);
  }

  @override
  void dispose() {
    cancelWait();
    _awaitingWindow?.cancel();
    super.dispose();
  }

  /// Re-reads the entitlement on [_pollBackoff] until it differs from [before].
  Future<MagicStarterStorePurchaseOutcome> _awaitEntitlementChange(
    MagicStarterEntitlementSnapshot before,
  ) async {
    final int epoch = _waitEpoch;

    for (final Duration delay in _pollBackoff) {
      final bool elapsed = await _sleep(delay);
      if (!elapsed) return MagicStarterStorePurchaseOutcome.abandoned;

      await loadEntitlement();
      if (epoch != _waitEpoch) {
        return MagicStarterStorePurchaseOutcome.abandoned;
      }

      if (_entitlementSnapshot != before) {
        if (_awaitingProductKey != null) _clearAwaiting();

        return MagicStarterStorePurchaseOutcome.confirmed;
      }
    }

    _clearAwaiting();

    return MagicStarterStorePurchaseOutcome.processing;
  }

  /// Waits [delay] on a timer [cancelWait] can stop, answering `true` when it
  /// elapsed and `false` when it was cancelled.
  ///
  /// A `Future.delayed` would leave its timer behind when the screen closed.
  Future<bool> _sleep(Duration delay) {
    final Completer<bool> sleeping = Completer<bool>();
    _waitSleep = sleeping;
    _waitTimer = Timer(delay, () {
      if (!sleeping.isCompleted) sleeping.complete(true);
    });

    return sleeping.future;
  }

  /// Drops the purchase wait and repaints the gates that read it.
  void _clearAwaiting() {
    _endAwaiting();
    refreshUI();
  }

  /// Drops the purchase wait without repainting, for a caller that repaints
  /// once itself: a read, or a session reset.
  void _endAwaiting() {
    _awaitingProductKey = null;
    _awaitingBaseline = null;
    _awaitingWindow?.cancel();
    _awaitingWindow = null;
  }

  /// Starts the bounded part of a wait, once the store has reported: from here
  /// a read that differs from [before] ends it, and so does [_waitWindow].
  void _startWaitWindow(MagicStarterEntitlementSnapshot before) {
    _awaitingBaseline = before;
    _awaitingWindow?.cancel();
    _awaitingWindow = Timer(_waitWindow, _clearAwaiting);
  }

  /// Whether [error] is the store reporting a purchase that is still pending.
  bool _isPending(Object error) {
    return error is BillingException && error.code == BillingErrorCode.pending;
  }

  /// Every product the catalogue rows list, grandfathered ones included, in
  /// the producer's order.
  Iterable<MagicStarterProduct> get _catalogueProducts {
    return _plans.expand((MagicStarterPlan plan) => plan.products);
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
