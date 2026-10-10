import 'dart:async' show unawaited;
import 'dart:math' show max;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';

import '../../../configuration/magic_starter_config.dart';
import '../../../facades/magic_starter.dart';
import '../../../http/controllers/magic_starter_billing_controller.dart';
import '../../../models/magic_starter_plan.dart';
import '../../../support/plan_upgrade.dart';
import '../../components/badge/index.dart';
import '../../components/button/index.dart';
import '../../components/card/index.dart';
import '../../components/page_scaffold/page_scaffold.dart';
import '../../components/segmented_control/index.dart';
import '../../components/skeleton/index.dart';
import '../../components/usage_meter/index.dart';

/// Publishes the catalogue row a plan card was built from, so the
/// `plan_card_highlight` slot can render the fields this package never names.
///
/// A slot builder is a `Widget Function(BuildContext)`, so a context is the
/// only channel a slot has. This scope wraps the slot subtree on every plan
/// card and hands the whole [MagicStarterPlan] over, [MagicStarterPlan.raw]
/// included. That map is the point: the package types the fields every
/// billing screen needs and leaves the vendor's own product fields (an
/// `ai_line` sales pitch, a `responder_add_on` surcharge, a `limits` map)
/// untouched inside it, and a consumer usually has to render MORE than one of
/// them. Dropping a surcharge line omits a recurring CHARGE from a purchase
/// decision, which is a different class of harm from omitting a value claim,
/// so the slot carries everything rather than a field this package picked.
///
/// ### Example
/// ```dart
/// MagicStarter.view.slot('teams.billing', 'plan_card_highlight', (context) {
///   final plan = MagicStarterPlanCardScope.of(context);
///   final aiLine = plan.raw['ai_line'] as String?;
///   final addOn = plan.raw['responder_add_on'] as String?;
///
///   return WDiv(
///     className: 'flex flex-col gap-1',
///     children: [
///       if (aiLine != null) WText(aiLine, className: 'text-xs'),
///       if (addOn != null) WText(addOn, className: 'text-xs'),
///     ],
///   );
/// });
/// ```
class MagicStarterPlanCardScope extends InheritedWidget {
  /// Creates the scope around one plan card's slot subtree.
  const MagicStarterPlanCardScope({
    super.key,
    required this.plan,
    required super.child,
  });

  /// The catalogue row the surrounding card was built from.
  final MagicStarterPlan plan;

  /// The plan the nearest enclosing card was built from.
  ///
  /// Throws a [StateError] outside a plan card, deliberately: the only caller
  /// is a `plan_card_highlight` slot builder, which is always invoked inside
  /// one, so an absent scope is a wiring mistake and a `null` would turn it
  /// into a card that silently renders nothing.
  static MagicStarterPlan of(BuildContext context) {
    final MagicStarterPlanCardScope? scope = context
        .dependOnInheritedWidgetOfExactType<MagicStarterPlanCardScope>();

    if (scope == null) {
      throw StateError(
        'MagicStarterPlanCardScope.of() was called outside a plan card. It is '
        'available to the "plan_card_highlight" slot of the "teams.billing" '
        'view only.',
      );
    }

    return scope.plan;
  }

  @override
  bool updateShouldNotify(MagicStarterPlanCardScope oldWidget) =>
      oldWidget.plan != plan;
}

/// **The plan and billing screen.**
///
/// One page over the six independent reads
/// [MagicStarterBillingController] publishes: the tier the team holds, the
/// catalogue it can move to, what it has spent this cycle, its billing history,
/// the card on file, and where the subscription is managed.
///
/// ## It resolves its controller, it does not construct one
///
/// [MagicStatefulViewState] resolves the controller through `Magic.find`, and
/// the registry builder below is zero-argument, so nothing on the render path
/// can supply a collaborator. The consumer therefore registers the controller
/// itself before this route is reached:
///
/// ```dart
/// Magic.put(
///   MagicStarterBillingController(
///     usageCopy: withUsageCopy,
///     formatNumber: formatCount,
///     storeFundedTeamReader: readStoreFundedTeam,
///     isOwnerReader: readTeamOwnership,
///   ),
/// );
/// ```
///
/// That is also why every consumer-supplied thing this screen renders through
/// (the usage copy, the number format) is a REQUIRED parameter on the
/// controller rather than on this widget: a view parameter would need a default
/// at the registration site, and both of the defaults available there are the
/// wrong answer shipped silently.
///
/// ## Page chrome comes from [MSPageScaffold]
///
/// Never hand-rolled. The scaffold routes the page through the host's one
/// `MSPageContainer` geometry, so this screen lines up with every other page in
/// the app rather than centring at its own width.
///
/// ## The four axes that gate every affordance
///
/// **The rail, never the running platform.** Which management surface this
/// screen offers comes from [MagicStarterBillingController.manageVia], which
/// the producer computes from the rail that sold the subscription. The two are
/// independent: a subscription bought on an iPhone is still managed in the App
/// Store when its owner opens the web app, so a branch on the RUNNING platform
/// (a `kIsWeb` check, a `dart:io` host test, the framework's target-platform
/// value) would offer the wrong surface to a real customer.
///
/// **The owner, for anything that spends money.** The billing write routes are
/// the account owner's server-side, so a member sees the plan grid read-only
/// with an owner-only notice instead of a call to action it would take a 403 to
/// discover. The gate is tri-state (see
/// [MagicStarterBillingController.isOwner]): only a KNOWN non-owner loses the
/// call to action, since an unresolved membership must not stand between an
/// owner and paying.
///
/// **The rail this BUILD can serve, for anything it has to call.** The
/// purchase-affecting calls live on `WebBillingService` and
/// `StoreBillingService`, each of which resolves to `null` where the build
/// cannot serve it, and no build serves both. That absence gates the checkout
/// call to action, all three portal affordances and the whole store purchase
/// surface, and it is a different question from `manage_via`: one asks where
/// the customer's subscription is managed, the other whether this binary has an
/// implementation to invoke.
///
/// **A configured web origin, for the checkout redirects.** A hosted checkout
/// session needs ABSOLUTE success and cancel urls, and
/// [MagicStarterConfig.billingWebOrigin] deliberately carries no default. An
/// unset origin therefore hides the checkout call to action rather than
/// building a relative url the rail refuses, because that refusal arrives as a
/// `BillingException` whose message goes to the log (see
/// [_MagicStarterBillingViewState._reportBillingFailure]) and the adopter would
/// never learn which config key they forgot.
///
/// ## One store account funds exactly one team
///
/// Store tiers share a subscription group so that upgrade and downgrade work,
/// and a store account holds at most one active subscription per group. So a
/// second purchase from the same account does not open a second subscription:
/// it TRANSFERS the one that exists and silently stops funding the team that
/// had it. Before offering to buy, this screen asks the consumer's
/// cross-team check and refuses by NAME when another team is already funded,
/// then asks AGAIN at the tap (see
/// [_MagicStarterBillingViewState._purchaseInStore]).
class MagicStarterBillingView
    extends MagicStatefulView<MagicStarterBillingController> {
  /// Creates the billing view.
  const MagicStarterBillingView({super.key});

  @override
  State<MagicStarterBillingView> createState() =>
      _MagicStarterBillingViewState();
}

class _MagicStarterBillingViewState
    extends
        MagicStatefulViewState<
          MagicStarterBillingController,
          MagicStarterBillingView
        > {
  /// The registry key this screen is registered under, and the prefix its slots
  /// hang from.
  static const String _viewKey = 'teams.billing';

  /// The one slot a plan card carries. See [MagicStarterPlanCardScope].
  static const String _planHighlightSlot = 'plan_card_highlight';

  /// An ISO 8601 duration made of ONE whole unit: `P14D`, `P2W`, `P1M`, `P1Y`.
  ///
  /// That is the whole shape a store reports an introductory period in. A
  /// compound duration (`P1Y2M`) or a time part (`PT36H`) does not match, and
  /// [_isoPeriodLabel] then answers `null` rather than a length it had to guess.
  static final RegExp _isoPeriod = RegExp(r'^P(\d+)([DWMY])$');

  /// The `billing.period_<unit>_one` / `_other` key stem of each unit
  /// [_isoPeriod] accepts.
  static const Map<String, String> _isoPeriodUnits = <String, String>{
    'D': 'day',
    'W': 'week',
    'M': 'month',
    'Y': 'year',
  };

  /// The cycle-toggle options, in [BillingCycle] order.
  static const List<BillingCycle> _cycles = <BillingCycle>[
    BillingCycle.monthly,
    BillingCycle.annual,
  ];

  /// Row count at which the billing history switches to a bounded lazy list.
  ///
  /// Below it the card renders every invoice and keeps its own height. A fixed
  /// body around three rows would be mostly empty space, and the cost the lazy
  /// path avoids does not exist yet.
  static const int _invoiceLazyThreshold = 8;

  /// Height of that bounded body, in logical pixels.
  ///
  /// Roughly eight rows at this row's padding: enough that the list reads as a
  /// list, short enough that the page around it stays reachable.
  static const int _invoiceBodyHeight = 420;

  /// The check glyph rendered before each plan feature.
  static const IconData _checkIcon = Icons.check;

  /// The glyph rendered on the store-managed and owner-only statements.
  static const IconData _infoIcon = Icons.info_outline;

  /// The short month names [_formatDate] indexes by `DateTime.month`.
  ///
  /// This table and the day-then-year order it feeds are DISPLAY COPY, and they
  /// are the one piece of it this package does freeze: `magic_payments` hands
  /// both dates over as instants precisely so a published package does not pick
  /// a date convention for every consumer, and a screen that has to render one
  /// has to pick anyway. A consumer that needs another order overrides the view.
  static const List<String> _monthAbbreviations = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// The upgrade-intent token already acted on, shared across mounts.
  ///
  /// Static because one arrival can mount this screen more than once (see
  /// [_startRequestedUpgrade]); a per-instance flag cannot dedupe across them.
  static String? _consumedUpgradeIntent;

  /// The cycle the CUSTOMER picked on the toggle, or null while they have not
  /// touched it.
  ///
  /// Separate from [_cycle] so the toggle can default to the cycle a customer is
  /// already on without that default becoming indistinguishable from a choice.
  ///
  /// A [ValueNotifier] rather than a plain field, so a press repaints the prices
  /// instead of the screen. It used to be a field written through `setState`,
  /// which rebuilt this whole State: the scaffold, the scrollable, the header,
  /// the usage meters, every plan card in full, the payment method and the
  /// billing history, to change four price labels and four billing notes.
  /// Measured on Chrome, one press rebuilt about 80 `WDiv` and 58 `WText`; the
  /// two [ValueListenableBuilder]s this feeds rebuild the toggle and the four
  /// price blocks and nothing else.
  final ValueNotifier<BillingCycle?> _cycleOverride =
      ValueNotifier<BillingCycle?>(null);

  /// The billing cycle every price on this screen is shown for, and the one a
  /// purchase is made on.
  ///
  /// It is NOT display-only, and the comment here used to say it was: "never
  /// encoded into a checkout payload: a catalogue row carries one price per
  /// cycle for DISPLAY, and which price a rail charges belongs to the rail's own
  /// product." That reasoning is what shipped a screen offering an annual
  /// discount over a monthly charge. A tier is not a price, so the cycle travels
  /// with the purchase.
  ///
  /// It opens on the cycle the customer is ALREADY billed on rather than on a
  /// fixed segment, and that is not a nicety either. A customer on monthly whose
  /// screen opened on annual, then tapping a plan card, would have been moved to
  /// that tier ANNUALLY without ever choosing annual. Falling back to annual only
  /// when no cycle is known keeps the discounted column in front of somebody who
  /// is not paying yet.
  BillingCycle get _cycle =>
      _cycleOverride.value ?? controller.cycle ?? BillingCycle.annual;

  /// The cycle [plan] is actually SOLD on, which is [_cycle] except where that
  /// tier has no product for it.
  ///
  /// A tier sold monthly only is ordinary (it is what a vendor has the day they
  /// add a tier and have not priced its annual product yet), and [_cycle] is a
  /// screen-wide value that knows nothing about the row it is being applied
  /// to. Left unqualified, such a tier stayed purchasable while the toggle sat
  /// on Annual and handed the checkout a (tier, annual) pair the producer has
  /// no product for: the customer offered one thing and sold another.
  ///
  /// Deliberately per CARD rather than a refusal in [_selectPlan]. That row is
  /// sellable, monthly, and refusing it would hide a tier the vendor is selling
  /// because of a toggle position; naming its real cycle sells it at the
  /// figure its card shows.
  ///
  /// The product this build would sell decides first ([_saleProduct]), because
  /// that product is what a purchase names: the card has to show the cycle the
  /// key will charge. A tier this build does not sell falls back to the cycle
  /// of the product the tier sells anywhere, and a tier selling nothing (the
  /// floor, a custom tier) to the toggle.
  BillingCycle _cycleFor(MagicStarterPlan plan) =>
      (_saleProduct(plan) ?? plan.productFor(_cycle))?.cycle ?? _cycle;

  /// The product a tap on [plan]'s card buys on THIS build, or `null` when this
  /// build sells the tier nothing.
  ///
  /// A store build offers only a sellable product with an id in ITS store and
  /// prices it from that store; a web build offers only a sellable product on
  /// one of the row's [MagicStarterPlan.cycles]. Either would otherwise be
  /// refused after the customer committed to buy: a product with no id in the
  /// store is `productUnavailable` at the sheet, and one with no card-rail
  /// price is refused by checkout. A grandfathered product is never the answer
  /// on either rail.
  MagicStarterProduct? _saleProduct(MagicStarterPlan plan) {
    final StoreBillingService? store = controller.storeRail;

    return store != null
        ? plan.storeProductFor(_cycle, store.store)
        : plan.webProductFor(_cycle);
  }

  /// The cycles the toggle can choose between on THIS build.
  ///
  /// A web build offers both, since the row's own `cycles` decide per card what
  /// is sold. A store build offers a cycle only when at least one tier has a
  /// product on it that the store carries: a toggle position nothing can be
  /// bought on is a choice with no outcome.
  List<BillingCycle> get _offeredCycles {
    final StoreBillingService? store = controller.storeRail;
    if (store == null) return _cycles;

    return <BillingCycle>[
      for (final BillingCycle cycle in _cycles)
        if (controller.plans.any(
          (MagicStarterPlan plan) => plan
              .storeProducts(store.store)
              .any((MagicStarterProduct product) => product.cycle == cycle),
        ))
          cycle,
    ];
  }

  /// Whether [plan] is the catalogue's floor: the FIRST row, which the
  /// backend serves cheapest-first, so it is the free tier.
  ///
  /// Decided by position because a tier carries no price of its own any more:
  /// a price belongs to a product, and the floor sells none. Both, not position
  /// alone: a catalogue with no free tier starts at a paid one, and reading
  /// that row as the floor labelled it "Free" with nothing to buy. The
  /// producer refuses a floor with a sellable product, so on its rows the two
  /// tests agree; this one holds for any app's catalogue.
  bool _isFloor(MagicStarterPlan plan) {
    final List<MagicStarterPlan> plans = controller.plans;

    return plans.isNotEmpty &&
        plans.first.id == plan.id &&
        plan.sellableProducts.isEmpty;
  }

  /// Whether [plan] is a custom tier: above the floor and selling no product,
  /// so the only way onto it is talking to sales.
  ///
  /// A tier whose only products are grandfathered counts too, since nothing
  /// left on it can be bought.
  bool _isCustom(MagicStarterPlan plan) =>
      !_isFloor(plan) && plan.sellableProducts.isEmpty;

  /// What a tap on the floor's call to action does, or `null` when this screen
  /// has nowhere to send the customer, in which case the floor renders no
  /// button at all (not a disabled one).
  ///
  /// Moving onto the floor is not a purchase. The floor sells no product, so
  /// sending the tap down the purchase path found nothing to buy and reported
  /// `productUnavailable`: the grid's only way down was a button that always
  /// failed. Leaving a paid plan means ending its subscription, and that
  /// happens where the subscription is managed, so the tap opens that surface
  /// and nothing here charges, swaps or cancels:
  ///
  /// - the hosted portal, behind [MagicStarterBillingController
  ///   .portalAvailable], for a subscription the web rail sold;
  /// - the store's own subscriptions page, for one a store sold, when the rail
  ///   reported where that is, the caller is not a known non-owner, and this
  ///   build is not the OTHER store's (an Android device cannot cancel an App
  ///   Store subscription, which is the refusal the profile screen makes too).
  ///
  /// The portal arm is closed on every store build, because no build serves
  /// both rails and `portalAvailable` needs a web rail. That is deliberate: a
  /// web-billed customer on an iOS build gets no button rather than a web page,
  /// which is the steering App Store rule 3.1.3 forbids.
  ///
  /// Never while the held tier is unresolved, since "Downgrade" is a claim
  /// about a position nobody knows yet, and never on the held floor itself,
  /// which carries the marker. Never once the subscription has stopped
  /// renewing either: the move to the floor is already booked, and the surface
  /// would offer nothing left to cancel. The floor is never the grid's filled
  /// button: [_featuredUpgradeId] only picks a tier this build sells a product
  /// of.
  VoidCallback? _floorExit(MagicStarterPlan plan) {
    final String? currentPlanId = controller.currentPlanId;
    if (currentPlanId == null || currentPlanId == plan.id) return null;
    if (controller.renews == false) return null;

    if (controller.portalAvailable) return _openBillingPortal;

    final String? manageUrl = controller.manageUrl;
    final ManageVia? buildStore = controller.storeRail?.store;
    if (controller.storeManaged &&
        manageUrl != null &&
        manageUrl.isNotEmpty &&
        controller.isOwner != false &&
        (buildStore == null || buildStore == controller.manageVia)) {
      return () => _openStoreManagement(manageUrl);
    }

    return null;
  }

  /// Whether this mount has already acted on an upgrade deep link, so a second
  /// resolving read cannot reopen checkout.
  bool _upgradeRequestHandled = false;

  @override
  void onInit() {
    // A second listener beside the one [MagicStatefulViewState] installs for
    // rebuilds. The deep-link handoff has to fire when a READ resolves rather
    // than when a frame is built: it needs both the catalogue and the
    // entitlement, and running it from `build` would open a checkout session
    // from inside a paint.
    controller.addListener(_startRequestedUpgrade);

    // The controller's own `onInit` ran once, for the lifetime of the session
    // singleton, so a screen opened again after closing mid-wait would never
    // read the entitlement the store purchase is waiting on and would keep the
    // purchase buttons hidden. The read clears the wait when the entitlement
    // now names the product.
    if (controller.awaitingProductKey != null) {
      unawaited(controller.loadEntitlement());
    }
  }

  @override
  void onClose() {
    controller.removeListener(_startRequestedUpgrade);
    // The controller is a session singleton and outlives this screen, so a
    // purchase wait it is polling for would keep reading the entitlement, and
    // keep its timer, after nobody is left to be told the answer.
    controller.cancelWait();
    _cycleOverride.dispose();
  }

  // ---------------------------------------------------------------------------
  // The gates this view adds to the controller's six
  // ---------------------------------------------------------------------------

  /// Whether this screen may offer to buy through the WEB rail.
  ///
  /// The controller's own gate PLUS a configured origin. The controller answers
  /// exactly as the rail does and knows nothing about redirects, so the origin
  /// belongs here: with none configured, a checkout call to action would build a
  /// relative url, fail session creation at the rail, and report a sentence that
  /// names a config key to the log and nothing to the customer. Hiding the
  /// affordance is the honest answer to "this app cannot sell on the web yet".
  bool get _canPurchaseViaWeb =>
      controller.canPurchaseViaWeb &&
      MagicStarterConfig.billingWebOrigin() != null;

  /// Whether this screen may offer to start or change a paid plan on ANY rail.
  ///
  /// No build serves both rails, so this is a union of two mutually exclusive
  /// answers rather than a choice between them; which one is live decides what a
  /// tap does (see [_selectPlan]).
  bool get _canPurchase => _canPurchaseViaWeb || controller.canPurchaseViaStore;

  /// The active plan, or `null` while the catalogue or the entitlement has not
  /// resolved, and permanently when the held tier is one the catalogue no longer
  /// serves.
  MagicStarterPlan? get _current {
    final String? planId = controller.currentPlanId;
    if (controller.plans.isEmpty || planId == null) return null;

    return _findPlan(planId);
  }

  @override
  Widget build(BuildContext context) {
    return MSPageScaffold(
      title: trans('magic_starter.billing.title'),
      subtitle: trans('magic_starter.billing.description'),
      children: <Widget>[
        _buildCurrentPlanCard(),
        _buildPlansSection(),
        _buildPaymentMethodSection(),
        _buildInvoicesSection(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Current plan + usage
  // ---------------------------------------------------------------------------

  /// Builds the current-plan card: the tier name beside a "Current" badge, the
  /// renewal line, and a responsive grid of usage meters.
  ///
  /// A skeleton stands in for the name/badge/renewal block while the catalogue
  /// or the entitlement is still unresolved, so no plan name and no "Current"
  /// claim is ever shown before it is confirmed. Once resolved, a
  /// [MagicStarterBillingController.currentPlanId] the catalogue no longer
  /// serves gets [_buildHeldPlanUnavailableNotice] instead of a real plan's
  /// name: the defect that replaces showed a grandfathered customer another
  /// tier's name, price and features as their own.
  ///
  /// The dunning notice and the usage grid are SIBLINGS of that three-way
  /// branch rather than children of any arm, because neither depends on the
  /// catalogue: usage is not plan-scoped, and a failed payment is a fact about
  /// the subscription whatever the catalogue can say about the tier. The notice
  /// began inside the resolved arm and so missed the grandfathered customer
  /// above, who is exactly the one a retired tier makes hardest to reason about.
  ///
  /// While the customer is on a free trial the name row gains a "Trial" badge
  /// beside the "Current" one, and the trial line takes the renewal line's
  /// place ([_trialLine]): a trial is not yet a renewal, so the renewal
  /// sentence would claim a charge and a date that are not the next event.
  Widget _buildCurrentPlanCard() {
    final String? planId = controller.currentPlanId;
    final bool resolving = controller.plans.isEmpty || planId == null;
    final MagicStarterPlan? current = _current;
    final DateTime? trialEnd = controller.trialEnd;

    return MSCard(
      child: WDiv(
        className: 'flex flex-col gap-5',
        children: <Widget>[
          if (resolving)
            const WDiv(
              className: 'flex flex-col gap-1',
              children: <Widget>[
                MSSkeleton(shape: SkeletonShape.text, width: 160, height: 20),
                MSSkeleton(height: 16, width: 220),
              ],
            )
          else if (current == null)
            _buildHeldPlanUnavailableNotice(planId)
          else
            WDiv(
              className: 'flex flex-col gap-1',
              children: <Widget>[
                WDiv(
                  className: 'flex flex-row items-center gap-2',
                  children: <Widget>[
                    WText(
                      current.name,
                      className: 'text-sm font-semibold text-fg',
                    ),
                    MSBadge(
                      trans('magic_starter.billing.plan_current_badge'),
                      tone: BadgeTone.primary,
                    ),
                    if (trialEnd != null)
                      MSBadge(
                        trans('magic_starter.billing.trial_badge'),
                        tone: BadgeTone.accent,
                      ),
                  ],
                ),
                WText(
                  trialEnd == null
                      ? _renewalLine(current)
                      : _trialLine(current, trialEnd),
                  className: 'text-sm text-fg-muted',
                ),
              ],
            ),
          // The dunning line, and it is the only thing on this card that
          // contradicts the rest of it.
          //
          // A failed payment does NOT take the tier away: both dunning statuses
          // still grant while the rail retries, deliberately, so every other
          // word here keeps saying the customer is on Pro and renews next
          // month. Without this the page a customer opens after their card
          // bounced is indistinguishable from a healthy one, and the first they
          // hear of it is losing access when the retries run out. Measured on a
          // live Stripe test clock: a failed renewal left `past_due` on the wire
          // and the screen read "renews Nov 24, 2026".
          //
          // A SIBLING of the three-way branch above, not a child of one of its
          // arms. It first sat inside the resolved-tier arm, which left the
          // grandfathered customer (a held tier the catalogue no longer serves,
          // the `current == null` arm) on exactly the silent healthy page this
          // exists to fix. The status is a separate read from the catalogue and
          // does not depend on it: `isDunning` is only true once the entitlement
          // says so, so the skeleton arm cannot render it early either.
          if (controller.planStatus.isDunning)
            WText(
              trans('magic_starter.billing.payment_failed_notice'),
              className: 'text-sm text-destructive',
            ),
          WDiv(
            className: 'grid grid-cols-1 gap-x-8 gap-y-5 sm:grid-cols-2',
            children: <Widget>[
              // A stat the consumer's copy could not name gets NO meter, rather
              // than one labelled with its raw wire key. The producer reports
              // every resource it meters and an app names the ones it sells, so
              // a new resource arriving early would otherwise put
              // `checks_this_month` on a customer's screen. A gate still reads
              // it by key either way, which is why the controller carries it all
              // the way here instead of dropping it.
              for (final UsageStat stat in controller.usage)
                if (stat.label != null)
                  MSUsageMeter(
                    label: stat.label!,
                    used: stat.used,
                    limit: stat.limit,
                    unit: stat.unit.isEmpty ? null : stat.unit,
                    formatNumber: controller.formatNumber,
                  ),
            ],
          ),
        ],
      ),
    );
  }

  /// The current-plan row for a tier the catalogue no longer serves: names the
  /// held tier id and says its details are unavailable, rather than falling back
  /// to the catalogue's cheapest entry.
  ///
  /// A [Wrap] rather than a flex row. The sibling branch above puts a plan NAME
  /// beside the badge and gets away with a row because a name is one word; this
  /// branch interpolates a tier id of any length, straight from the consumer's
  /// catalogue, so at phone width the sentence and the badge cannot always share
  /// a line. A flex row leaves its main-axis size ambiguous and overflows there;
  /// the [Wrap] drops the badge to its own run.
  ///
  /// No `truncate` on the sentence, deliberately. Wind maps that token to
  /// `maxLines: 1` with `softWrap: false`, which is unconditional rather than a
  /// last resort, and a [Wrap] already hands its child a bounded width, so the
  /// sentence soft-wraps to a second line on its own. Clipping it instead would
  /// cut a translation such as the Turkish `:id planı, ayrıntılar kullanılamıyor`
  /// before its verb, which is a failure this ecosystem has recorded before: a
  /// localised sentence is not a label and cannot be shortened from the right.
  Widget _buildHeldPlanUnavailableNotice(String heldPlanId) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        WText(
          trans(
            'magic_starter.billing.plan_unavailable_text',
            <String, dynamic>{'id': heldPlanId},
          ),
          className: 'text-sm text-fg-muted',
        ),
        MSBadge(
          trans('magic_starter.billing.plan_current_badge'),
          tone: BadgeTone.primary,
        ),
      ],
    );
  }

  /// The one line under the current plan's name, in its five states.
  ///
  /// A FREE plan never renews and carries no payment method, so it reads "free
  /// forever" rather than a renewal line whose date is a neutral placeholder.
  ///
  /// A STORE-BILLED plan gets its own sentence, for the same reason a store
  /// build shows no catalogue price: the amount here comes from the catalogue in
  /// its own currency on this screen's own cadence, while the store charged a
  /// storefront-localised price on its SKU's cadence, and the renewal date
  /// behind it is a web-rail read that answers nothing for a store subscription.
  /// Every number in the sentence would be wrong at once, which is worse than
  /// not showing it.
  ///
  /// A paid tier that NO rail is billing gets its own sentence too, and it is
  /// the state this used to get wrong: it fell through to the live sentence and
  /// rendered "renews Unknown", which reads as a renewal whose date was mislaid
  /// rather than as no renewal at all.
  ///
  /// TWO conditions guard that arm, and the second was missing on the first
  /// attempt. A resolved-but-empty payment method is NOT sufficient, because the
  /// payment-method read soft-fails: the producer catches every failure from the
  /// live rail read and answers 200 with every field null, byte-identical to the
  /// body a genuinely unbilled team gets. So a paying customer whose rail read
  /// timed out was told they had no subscription, which is worse than the
  /// "renews Unknown" it replaced, because Unknown was at least neutral.
  /// `manage_via` is the discriminator the producer can always express: `portal`
  /// implies a billing customer exists, so requiring `none` keeps this sentence
  /// to customers who really have no rail, and requiring it EXPLICITLY rather
  /// than "not portal" keeps the unresolved state out, matching how every other
  /// gate here treats it.
  ///
  /// A CANCELLED subscription still grants until its period ends, so it gets the
  /// live sentence with the verb changed: the date it carries is an expiry, and
  /// "renews" over it contradicts the action the customer just took.
  ///
  /// Otherwise the live sentence, whose date comes from the payment-method read
  /// and falls back to a neutral label while that read is pending or after its
  /// soft-fail, never to a fabricated date. That neutral label survives on
  /// purpose: "pending" and "there is none" are different answers, and only the
  /// second one is settled.
  String _renewalLine(MagicStarterPlan current) {
    if (_isFloor(current)) {
      return trans('magic_starter.billing.renewal_free');
    }

    if (controller.storeManaged) {
      return trans('magic_starter.billing.renewal_store');
    }

    final PaymentMethod? resolved = controller.paymentMethod;
    if (controller.manageVia == ManageVia.none &&
        resolved != null &&
        resolved.renewalDate == null) {
      return trans('magic_starter.billing.renewal_unbilled');
    }

    // A CANCELLED subscription keeps its tier to the end of the paid period, so
    // the date is still shown, but it is an expiry rather than a renewal and
    // saying "renews" over it is a confident wrong sentence aimed at the one
    // customer who has just cancelled and is checking that it took.
    //
    // `renews == null` takes the renewing sentence, which leaves the window
    // before the entitlement resolves reading exactly as it did. Nothing is
    // claimed in that window that is not already hedged: the date comes from a
    // separate read and renders as unknown until it lands.
    //
    // Held as ONE boolean rather than resolved twice: there are four keys below,
    // two per cycle branch, and the rule that picks between them is this
    // comparison. Written out at each branch it is the same rule in two places,
    // and the first version of this code did exactly that, with the second copy
    // returning before the first was ever read.
    final bool ends = controller.renews == false;

    // The cycle the customer BOUGHT, from the entitlement, never the toggle and
    // never a literal. Both of those shipped: the cycle was hardcoded to annual
    // here, so every paying customer read "billed annually" whatever they were
    // charged, and reading `_cycle` instead would only move the lie onto a
    // segmented control the customer can press.
    //
    // A null cycle takes the sentence WITHOUT one rather than a guessed word.
    // The producer answers null for a store subscription and for a price whose
    // cycle its config never declared, and naming either one is the claim this
    // whole change exists to stop making. A held product with no web price
    // takes it too: a cycle word beside no figure says nothing a date does not.
    final BillingCycle? cycle = controller.cycle;
    final MagicStarterWebPrice? price = cycle == null
        ? null
        : _heldWebPrice(current, cycle);

    if (cycle == null || price == null) {
      return trans(
        ends
            ? 'magic_starter.billing.renewal_ends_cycleless'
            : 'magic_starter.billing.renewal_text_cycleless',
        <String, dynamic>{
          'date':
              _formatDate(controller.paymentMethod?.renewalDate) ??
              trans('common.unknown'),
        },
      );
    }

    return trans(
      ends
          ? 'magic_starter.billing.renewal_ends'
          : 'magic_starter.billing.renewal_text',
      <String, dynamic>{
        'price': price.display,
        'cycle': _cycleLabel(cycle),
        'date':
            _formatDate(controller.paymentMethod?.renewalDate) ??
            trans('common.unknown'),
      },
    );
  }

  /// The one line under the current plan's name while the customer is on a free
  /// trial, in its four states. It REPLACES [_renewalLine] for the length of the
  /// trial.
  ///
  /// The date is [MagicStarterBillingController.trialEnd], which is the trial's
  /// own end on either rail (a store trial ends at the period end, and the
  /// controller already resolves that), never the payment-method read's renewal
  /// date: that one is a web-rail read and answers nothing for a store trial.
  ///
  /// A trial that has been CANCELLED comes first, and on both rails: it keeps
  /// its tier to the end date and then simply stops, so naming a price it will
  /// not be charged, or the store sentence that says it bills, is the confident
  /// wrong sentence [_renewalLine] was rewritten to stop saying. It carries no
  /// days-left figure either, because there is nothing left to count down to
  /// except an end.
  ///
  /// Otherwise a store trial gets the store sentence and the end date, for the
  /// reason [_renewalLine] gives: a catalogue price in its own currency on this
  /// screen's own cadence is not what the store will charge.
  ///
  /// A web trial names the held product's price and cycle when both are known,
  /// and takes the sentence WITHOUT them otherwise, never a guessed word, for
  /// the reason [_renewalLine] gives too.
  String _trialLine(MagicStarterPlan current, DateTime trialEnd) {
    final String date = _formatDate(trialEnd) ?? trans('common.unknown');

    // 1. A cancelled trial ends rather than converts, on any rail.
    if (controller.renews == false) {
      return trans('magic_starter.billing.trial_line_ends', <String, dynamic>{
        'date': date,
      });
    }

    final String left = _trialDaysLeft(trialEnd);

    // 2. A store trial: the store bills it, and says how.
    if (controller.storeManaged) {
      return trans('magic_starter.billing.trial_line_store', <String, dynamic>{
        'date': date,
        'left': left,
      });
    }

    // 3. A web trial, with what it converts to when that is known.
    final BillingCycle? cycle = controller.cycle;
    final MagicStarterWebPrice? price = cycle == null
        ? null
        : _heldWebPrice(current, cycle);

    if (cycle == null || price == null) {
      return trans(
        'magic_starter.billing.trial_line_cycleless',
        <String, dynamic>{'date': date, 'left': left},
      );
    }

    return trans('magic_starter.billing.trial_line_renews', <String, dynamic>{
      'date': date,
      'left': left,
      'price': price.display,
      'cycle': _periodWord(cycle),
    });
  }

  /// The whole days until [trialEnd], as the "N days left" phrase.
  ///
  /// Rounded UP, so a trial with twelve hours left reads "1 day left" and not
  /// "0 days left" while it still grants, and clamped at zero so a date that has
  /// already passed (the read has not caught up with the conversion yet) never
  /// prints a negative count. Zero takes the plural, as the form for any count
  /// other than one.
  String _trialDaysLeft(DateTime trialEnd) {
    final int days = max(
      0,
      (trialEnd.difference(DateTime.now()).inMicroseconds /
              Duration.microsecondsPerDay)
          .ceil(),
    );

    return _counted('magic_starter.billing.trial_days_left', days);
  }

  // ---------------------------------------------------------------------------
  // Plans section
  // ---------------------------------------------------------------------------

  /// Builds the tier-comparison section: a centred heading and cycle toggle,
  /// then a grid of one card per catalogue row (a skeleton grid while the
  /// catalogue is still empty).
  ///
  /// A known non-owner gets one notice here rather than the same sentence
  /// repeated on every card: the grid stays fully readable (comparing tiers is
  /// not a write), it just stops offering to buy. A store account already
  /// funding another team gets its own notice beside it, naming that team.
  ///
  /// The monthly/annual toggle renders on every rail: both purchase by the
  /// catalogue product key for the selected tier and cycle, so the store sheet
  /// charges the cycle the customer picked, exactly as web checkout does. A
  /// store build hides it when the store can sell only one cycle (see
  /// [_offeredCycles]), since pressing it would change nothing.
  Widget _buildPlansSection() {
    final String? fundedTeam = controller.storeFundedTeam;
    final bool offersCycleChoice = _offeredCycles.length > 1;

    return WDiv(
      className: 'flex flex-col gap-5',
      children: <Widget>[
        if (controller.isOwner == false)
          _buildStatementTile(trans('magic_starter.billing.owner_only_notice')),
        if (fundedTeam != null)
          _buildStatementTile(
            trans('magic_starter.billing.store_bound_text', <String, dynamic>{
              'team': fundedTeam,
            }),
          ),
        WDiv(
          className: 'flex flex-col items-center gap-2 text-center',
          children: <Widget>[
            WText(
              trans('magic_starter.billing.plans_heading'),
              className: 'text-lg font-semibold text-fg',
            ),
            if (offersCycleChoice)
              ValueListenableBuilder<BillingCycle?>(
                valueListenable: _cycleOverride,
                builder: (_, _, _) => MSSegmentedControl<BillingCycle>(
                  size: SegmentedControlSize.sm,
                  options: <String>[
                    trans('magic_starter.billing.plans_monthly'),
                    trans('magic_starter.billing.plans_annual'),
                  ],
                  selectedIndex: _cycles.indexOf(_cycle),
                  // Into the OVERRIDE, not into `_cycle`, which is derived. A
                  // press is the customer's own choice and has to outrank the
                  // entitlement default for the rest of the visit.
                  onChanged: (int index) =>
                      _cycleOverride.value = _cycles[index],
                ),
              ),
          ],
        ),
        if (controller.plans.isEmpty)
          const WDiv(
            className: 'grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4',
            children: <Widget>[
              MSSkeleton(height: 280),
              MSSkeleton(height: 280),
              MSSkeleton(height: 280),
              MSSkeleton(height: 280),
            ],
          )
        else
          WDiv(
            className: 'grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4',
            children: <Widget>[
              for (final MagicStarterPlan plan in controller.plans)
                _buildPlanCard(plan),
            ],
          ),
        // Restore sits behind the same gate as the purchase, not behind the
        // store rail alone. Restoring hands a subscription this store account
        // owns to whichever team the rail is currently identified as, so on a
        // team the account must not fund it would be the transfer the refusal
        // above exists to prevent, arriving through a different button.
        if (controller.canPurchaseViaStore)
          WDiv(
            className: 'flex flex-col items-center',
            children: <Widget>[
              MSButton(
                intent: ButtonIntent.ghost,
                size: ButtonSize.sm,
                onPressed: _restoreStorePurchases,
                child: WText(
                  trans('magic_starter.billing.store_restore_button'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Builds one plan card: name and tagline, the price for the selected cycle,
  /// the consumer's own highlight slot, the feature list, an optional
  /// "Recommended" badge, and the call to action.
  Widget _buildPlanCard(MagicStarterPlan plan) {
    final bool isCurrent =
        controller.currentPlanId != null && plan.id == controller.currentPlanId;
    final bool isFloor = _isFloor(plan);
    final bool isCustom = _isCustom(plan);
    // The web price is a figure in the vendor's own currency, and a store
    // charges a storefront-localised amount in the customer's, so on a store
    // build that figure is not the price of anything. The store's own
    // localised string ([MagicStarterBillingController.storeOffers]) is the
    // right source, and a card the store priced shows it. A card it did not
    // price (the read failed, or the store has no product for the key) states
    // where the price comes from instead: the sheet shows the real one before
    // anybody is charged, and showing a wrong price is worse than showing none.
    // The floor and the custom tier sell no product, so they keep their words.
    final bool storePriced =
        controller.storeRail != null && !isCustom && !isFloor;
    // A tier this store carries no product of states no price at all: "shown in
    // the store" would promise a sheet that cannot open, and the web figure is
    // not for sale here. One muted sentence takes the price block's place, so
    // the card does not end at a name and a feature list with no word on why
    // nothing can be done with it. It names no other place to buy the tier,
    // since pointing a store customer at one is what App Store guidelines 3.1.1
    // and 3.1.3 forbid.
    final bool storeUnsold = storePriced && _saleProduct(plan) == null;
    // The disclosure belongs to a store PURCHASE button and to nothing else: not
    // to the held tier's marker, to the sales handoff, or to a tier with no
    // product to buy. It follows the same gate the button renders behind.
    final bool showsStoreDisclosure =
        !isCurrent &&
        !isCustom &&
        controller.canPurchaseViaStore &&
        _saleProduct(plan) != null;
    // A priced tier this build sells nothing on (a tier priced in a store only,
    // seen on the web) gets no button: checkout would refuse it after the tap.
    // The floor sells nothing anywhere, so it is never a purchase; its button
    // leads to where the paid plan is cancelled, or does not render.
    final bool offersPurchase = _canPurchase && _saleProduct(plan) != null;
    final VoidCallback? floorExit = isFloor ? _floorExit(plan) : null;
    final Widget? highlight = _buildPlanHighlight(plan);

    return WDiv(
      // No `relative` on either arm: it was here for the `absolute -top-2.5
      // left-5` badge that now sits in flow, and nothing else in this subtree
      // is absolutely positioned, so it was a positioning context with nothing
      // to position.
      className: plan.recommended
          ? 'flex flex-col gap-4 rounded-lg border '
                'border-primary bg-surface p-5'
          : 'flex flex-col gap-4 rounded-lg border '
                'border-color-border bg-surface p-5',
      children: <Widget>[
        // 1. Name, the badge beside it, and the tagline.
        //
        //    The badge sits IN FLOW on the name's row rather than absolutely
        //    positioned over the card's top border. That pattern is a CSS
        //    idiom and it did not survive the port: the badge landed on top of
        //    the plan name, so "Recommended" and "Pro" were drawn over each
        //    other. In flow it cannot collide at any width, and it needs no
        //    negative offset to sit where it belongs.
        //
        //    `flex-1` on the name and `shrink-0` on the badge is the whole
        //    responsive story: a long plan name gives way, the badge never
        //    wraps or clips, and at mobile width the row still fits because the
        //    badge is two words at most.
        WDiv(
          className: 'flex flex-col gap-0.5',
          children: <Widget>[
            WDiv(
              className: 'flex flex-row items-center gap-2',
              children: <Widget>[
                WText(
                  plan.name,
                  className: 'flex-1 text-base font-semibold text-fg',
                ),
                if (plan.recommended)
                  WDiv(
                    className: 'shrink-0',
                    child: MSBadge(
                      trans('magic_starter.billing.plan_recommended_badge'),
                      tone: BadgeTone.primary,
                    ),
                  ),
              ],
            ),
            WText(plan.tagline, className: 'text-xs text-fg-muted'),
          ],
        ),
        // 2. Price and billing note for the selected cycle.
        //
        //    The ONLY part of this card the cycle toggle changes, which is why
        //    it is the only part subscribed to it. Everything around it (the
        //    name, the badge, the tagline, the highlight, the feature list, the
        //    call to action) reads the catalogue row, not the cycle, so a press
        //    that rebuilt them was rebuilding them into an identical tree.
        //
        //    The held tier's own card keeps the bare omission instead: "Not
        //    available in this app" above the "Current plan" marker reads as
        //    though the plan a customer pays for does not work here.
        if (storeUnsold && !isCurrent)
          WText(
            trans('magic_starter.billing.plan_store_unsold'),
            className: 'text-sm text-fg-muted',
          )
        else if (!storeUnsold)
          ValueListenableBuilder<BillingCycle?>(
            valueListenable: _cycleOverride,
            builder: (_, _, _) {
              final StoreProductOffer? offer = storePriced
                  ? _storeOffer(plan)
                  : null;
              final ({String text, bool sentence}) label = storePriced
                  ? (
                      text: trans('magic_starter.billing.plan_price_store'),
                      sentence: true,
                    )
                  : _webPrice(plan, isFloor: isFloor, isCustom: isCustom);

              return WDiv(
                className: 'flex flex-col gap-0.5',
                children: <Widget>[
                  if (offer != null)
                    WText(
                      offer.priceString,
                      className: 'text-3xl font-semibold tabular-nums text-fg',
                    )
                  else
                    WText(
                      label.text,
                      className: label.sentence
                          ? 'text-base font-medium text-fg'
                          : 'text-3xl font-semibold tabular-nums text-fg',
                    ),
                  WText(_billingNote(plan), className: 'text-xs text-fg-muted'),
                ],
              );
            },
          ),
        // 3. The consumer's highlight, where one is registered. The null-aware
        //    element OMITS it rather than rendering a placeholder, which matters
        //    because a placeholder child still consumes a slot in this card's
        //    `gap-4` column and leaves a visible hole.
        ?highlight,
        // 4. Feature list.
        WDiv(
          className: 'flex flex-col gap-2',
          children: <Widget>[
            for (final String feature in plan.features)
              WDiv(
                className: 'flex flex-row items-start gap-2',
                children: <Widget>[
                  WIcon(_checkIcon, className: 'text-[16px] text-primary'),
                  WText(feature, className: 'flex-1 text-sm text-fg'),
                ],
              ),
          ],
        ),
        // 5. The bottom slot, stretched by the button's own `fullWidth` rather
        //    than by a flex row.
        //
        //    THE CURRENT TIER GETS NO BUTTON, it gets a MARKER: a bordered row
        //    with a check, in the card's own accent. It used to get a disabled
        //    button, and a disabled button beside live ones is a fourth grey
        //    rectangle, so nothing on the grid said which was pressable, which
        //    was the customer's own plan, or where to look. A marker is not a
        //    control, so it stops pretending to be one.
        //
        //    The button below therefore renders for three reasons, all of them
        //    live: a custom tier's sales handoff (driven by the GRID rather
        //    than by the entitlement, so it survives both gates and spends
        //    nothing), an actual purchase, which needs a rail and the
        //    membership to allow it, and the floor's way out of the paid plan
        //    ([_floorExit]). Which of the four emphases it takes is
        //    [_ctaIntent]'s decision, not this slot's.
        if (isCurrent)
          WDiv(
            className:
                'flex flex-row items-center justify-center gap-2 '
                'rounded-md border border-primary bg-primary-container '
                'px-4 py-2.5',
            children: <Widget>[
              WIcon(_checkIcon, className: 'text-[16px] text-primary'),
              WText(_ctaLabel(plan), className: 'text-sm font-medium text-fg'),
            ],
          )
        else ...<Widget>[
          if (showsStoreDisclosure) _buildStoreDisclosure(plan),
          if (isCustom || offersPurchase || floorExit != null)
            _buildPlanAction(plan, floorExit: floorExit),
        ],
      ],
    );
  }

  /// The card's call to action, with the web trial line above it when the
  /// product a tap buys carries one.
  ///
  /// Subscribed to the cycle toggle, because a trial belongs to a PRODUCT and
  /// the toggle picks the product: `business_monthly` can offer seven days where
  /// `business_annual` offers fourteen, or none. The line and the label are the
  /// only parts a press changes here, and they sit in the one builder so that a
  /// cycle with no trial takes the line away without leaving the card's `gap-4`
  /// column a hole where it was.
  ///
  /// What the button DOES is unchanged: [_selectPlan] buys the same product the
  /// card was priced from, and only the words on it move.
  Widget _buildPlanAction(MagicStarterPlan plan, {VoidCallback? floorExit}) {
    return ValueListenableBuilder<BillingCycle?>(
      valueListenable: _cycleOverride,
      builder: (_, _, _) {
        final ({String period, String price, String cycle})? trial = _webTrial(
          plan,
        );

        return WDiv(
          className: 'flex flex-col gap-2',
          children: <Widget>[
            // Small and muted on purpose: Apple's rule is that the billed
            // amount stays the most prominent pricing element, and that is the
            // figure in the price block. This line says how long the trial is
            // and what follows it, and nothing more.
            if (trial != null)
              WText(
                trans(
                  'magic_starter.billing.trial_card_required',
                  <String, dynamic>{
                    'period': trial.period,
                    'price': trial.price,
                    'cycle': trial.cycle,
                  },
                ),
                className: 'text-xs text-fg-muted',
              ),
            MSButton(
              intent: _ctaIntent(plan),
              fullWidth: true,
              onPressed: floorExit ?? () => _selectPlan(plan),
              child: WText(
                trial == null
                    ? _ctaLabel(plan)
                    : trans('magic_starter.billing.trial_cta'),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The free trial a tap on [plan]'s card starts on the WEB rail, as the three
  /// words its line is made of, or `null` when the card advertises none.
  ///
  /// Decided the way [_selectPlan] decides a web checkout: this build has no
  /// store rail, and [_canPurchaseViaWeb] holds (a web rail, a configured
  /// origin, an owner, a subscription not managed in a store). Never on a store
  /// build, where the store's own intro offer is the only trial there is and
  /// [_buildStoreDisclosure] states it.
  ///
  /// The product is the one [_saleProduct] names, so the days are those of the
  /// product the button will buy on the selected cycle. A positive
  /// [MagicStarterProduct.trialDays] is already this caller's own answer (the
  /// producer sends `0` for a trial they have used), which is what makes it safe
  /// to advertise.
  ///
  /// A product with no displayable web price states no trial line at all: the
  /// line's whole job is to say what is billed after the trial, and "Price shown
  /// at checkout" has no place in a sentence that has to name it.
  ({String period, String price, String cycle})? _webTrial(
    MagicStarterPlan plan,
  ) {
    if (controller.storeRail != null || !_canPurchaseViaWeb) return null;

    final MagicStarterProduct? product = _saleProduct(plan);
    if (product == null || product.trialDays < 1) return null;

    final MagicStarterWebPrice? price = product.webPrices.values.firstOrNull;
    if (price == null) return null;

    return (
      period: _periodLabel(product.trialDays, 'day'),
      price: price.display,
      cycle: _periodWord(_cycleFor(plan)),
    );
  }

  /// The store's own price for the product [plan] sells on the selected cycle,
  /// or `null` when the store priced none of it.
  StoreProductOffer? _storeOffer(MagicStarterPlan plan) {
    final MagicStarterProduct? product = _saleProduct(plan);

    return product == null ? null : controller.storeOffers[product.key];
  }

  /// The terms a store subscription is sold on, rendered beside its purchase
  /// button as App Store guideline 3.1.2 requires: what it costs per period,
  /// that it renews until cancelled and where to cancel it, and the Terms and
  /// Privacy links.
  ///
  /// The price line is the STORE's string for the cycle the button will buy, so
  /// it can never disagree with the sheet, and it is omitted when the store
  /// priced nothing rather than filled from the catalogue's other currency. The
  /// renewal and cancellation lines do not depend on a price, so they stay. A
  /// link whose url is not configured is left out, not rendered dead.
  ///
  /// Subscribed to the cycle toggle for the same reason the price block is: the
  /// period and the figure are the only parts a press changes.
  Widget _buildStoreDisclosure(MagicStarterPlan plan) {
    return ValueListenableBuilder<BillingCycle?>(
      valueListenable: _cycleOverride,
      builder: (_, _, _) {
        final StoreProductOffer? offer = _storeOffer(plan);
        final String? termsUrl = MagicStarterConfig.termsUrl();
        final String? privacyUrl = MagicStarterConfig.privacyUrl();
        final String period = _periodWord(_cycleFor(plan));

        return WDiv(
          className: 'flex flex-col gap-1',
          children: <Widget>[
            if (offer != null)
              WText(
                _storePriceLine(offer, period),
                className: 'text-xs font-medium text-fg',
              ),
            WText(
              trans('magic_starter.billing.store_disclosure_auto_renew'),
              className: 'text-xs text-fg-muted',
            ),
            WText(
              trans('magic_starter.billing.store_disclosure_cancel'),
              className: 'text-xs text-fg-muted',
            ),
            if (termsUrl != null || privacyUrl != null)
              WDiv(
                className: 'flex flex-row gap-3 wrap',
                children: <Widget>[
                  if (termsUrl != null)
                    _buildLegalLink(
                      trans('magic_starter.billing.store_disclosure_terms'),
                      termsUrl,
                    ),
                  if (privacyUrl != null)
                    _buildLegalLink(
                      trans('magic_starter.billing.store_disclosure_privacy'),
                      privacyUrl,
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// The price line of [_buildStoreDisclosure] for [offer], with [period] as the
  /// word the recurring price is stated per (`month`, `year`).
  ///
  /// The introductory offer is stated ONLY when the store confirmed that this
  /// customer may take it ([StoreProductOffer.introEligible]): a product HAVING
  /// an offer says nothing about this customer, and an unknown answer, a failed
  /// read and an ineligible customer all arrive as `false`, so promising the
  /// trial there would advertise something the sheet will not give.
  ///
  /// - A free intro (price `0`) reads "Free for :intro_period, then :price per
  ///   :period".
  /// - A paid intro reads "First :intro_period at :intro_price, then :price per
  ///   :period", and only when the store supplied the intro price's own string,
  ///   since a figure built from the number would disagree with the sheet.
  /// - Everything else, including an eligible offer whose period is not one
  ///   whole ISO unit ([_isoPeriodLabel]), keeps the plain "per period" line: a
  ///   promise with no length is worse than no promise.
  ///
  /// The billed [StoreProductOffer.priceString] is the figure of every arm and
  /// stays the card's large price in the block above, which is where Apple's
  /// rule wants the most prominent pricing element to be.
  String _storePriceLine(StoreProductOffer offer, String period) {
    final String? introPeriod = offer.introEligible
        ? _isoPeriodLabel(offer.introPeriod)
        : null;
    final double? introPrice = offer.introPrice;
    final String? introPriceString = offer.introPriceString;

    if (introPeriod != null && introPrice != null) {
      if (introPrice == 0) {
        return trans(
          'magic_starter.billing.store_disclosure_intro_free',
          <String, dynamic>{
            'intro_period': introPeriod,
            'price': offer.priceString,
            'period': period,
          },
        );
      }

      if (introPrice > 0 && introPriceString != null) {
        return trans(
          'magic_starter.billing.store_disclosure_intro_paid',
          <String, dynamic>{
            'intro_period': introPeriod,
            'intro_price': introPriceString,
            'price': offer.priceString,
            'period': period,
          },
        );
      }
    }

    return trans(
      'magic_starter.billing.store_disclosure_price',
      <String, dynamic>{'price': offer.priceString, 'period': period},
    );
  }

  /// One legal link of [_buildStoreDisclosure], styled as the register screen's
  /// own are.
  Widget _buildLegalLink(String label, String url) {
    return WAnchor(
      onTap: () => Launch.url(url),
      child: WText(
        label,
        className: 'text-xs font-semibold text-primary dark:text-primary/80',
      ),
    );
  }

  /// The consumer's `plan_card_highlight` slot for [plan], or `null` when none
  /// is registered.
  ///
  /// Gated on `hasSlot` rather than on the built widget being null, so an app
  /// that registered nothing renders no child at all: a placeholder child would
  /// still consume a slot in the card's `gap-4` column and leave a visible hole
  /// between the price and the features.
  Widget? _buildPlanHighlight(MagicStarterPlan plan) {
    if (!MagicStarter.view.hasSlot(_viewKey, _planHighlightSlot)) return null;

    // Through a Builder, because a slot builder receives the context it is
    // called with: the scope has to be an ANCESTOR of that context for
    // [MagicStarterPlanCardScope.of] to find it.
    return MagicStarterPlanCardScope(
      plan: plan,
      child: Builder(
        builder: (BuildContext slotContext) {
          return MagicStarter.view.buildSlot(
                _viewKey,
                _planHighlightSlot,
                slotContext,
              ) ??
              const SizedBox.shrink();
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Payment method
  // ---------------------------------------------------------------------------

  /// Builds the payment-method section: the brand tile, the masked number, the
  /// expiry, and an "Update" button that opens the hosted billing portal.
  ///
  /// This card owns its own loading and error state, since reading the card is
  /// the one billing call that dials a rail live: it never blocks the rest of
  /// the screen, and a soft-failed read renders as a named state instead of
  /// crashing.
  ///
  /// On a store rail the section is replaced wholesale by
  /// [_buildStoreManagedSection]: there is no card behind a store subscription,
  /// so a "Payment method" card would be describing an object that does not
  /// exist.
  Widget _buildPaymentMethodSection() {
    if (controller.storeManaged) return _buildStoreManagedSection();

    return MSCard(
      title: trans('magic_starter.billing.payment_header'),
      child: _buildPaymentMethodContent(),
    );
  }

  /// Builds the store-managed section: the statement naming the store that sold
  /// this subscription, and either a link to the destination the rail passed
  /// through or, when it reported none, the sentence telling the customer where
  /// to look instead.
  ///
  /// A null destination deliberately renders NO button, not a disabled one: a
  /// disabled button invites a tap and explains nothing, while the sentence
  /// answers the question the tap would have asked. The url itself comes from
  /// the rail rather than from a hardcoded vendor address, so a store moving its
  /// subscriptions page does not need an app release.
  Widget _buildStoreManagedSection() {
    final String? manageUrl = controller.manageUrl;

    return MSCard(
      title: trans('magic_starter.billing.manage_header'),
      child: WDiv(
        className: 'flex flex-col gap-3',
        children: <Widget>[
          _buildStatementTile(_storeStatement()),
          if (manageUrl != null && manageUrl.isNotEmpty)
            WDiv(
              className: 'flex flex-col',
              children: <Widget>[
                MSButton(
                  intent: ButtonIntent.secondary,
                  size: ButtonSize.sm,
                  onPressed: () => _openStoreManagement(manageUrl),
                  child: WText(
                    trans('magic_starter.billing.manage_store_button'),
                  ),
                ),
              ],
            )
          else
            WText(
              trans('magic_starter.billing.manage_store_no_url'),
              className: 'text-xs text-fg-muted',
            ),
        ],
      ),
    );
  }

  /// The statement naming the store that sold the active subscription.
  ///
  /// Exhaustive over [ManageVia] with no `default`, so a fifth rail is a compile
  /// error here rather than a screen that silently names the wrong store. The
  /// two non-store cases are unreachable (this is only called from
  /// [_buildStoreManagedSection], behind [MagicStarterBillingController
  /// .storeManaged]) and fall back to the generic "look in your store account"
  /// sentence rather than inventing a vendor.
  String _storeStatement() {
    return switch (controller.manageVia) {
      ManageVia.appStore => trans(
        'magic_starter.billing.manage_app_store_text',
      ),
      ManageVia.playStore => trans(
        'magic_starter.billing.manage_play_store_text',
      ),
      ManageVia.portal ||
      ManageVia.none ||
      null => trans('magic_starter.billing.manage_store_no_url'),
    };
  }

  /// Builds the tinted informational tile the store statement, the owner-only
  /// notice and the cross-team refusal share.
  ///
  /// Tokens from the 17-role alias contract, not an `info` family: the contract
  /// names no informational role, and a shared component that reached for a
  /// consumer's token would render nothing at all in every app that has not
  /// hand-authored one, because Wind drops an unknown token silently. There is
  /// no registry component for a one-line notice either: `MSEmptyState` and
  /// `MSErrorState` both want a title, a glyph and an action, and `MSUpgradeNudge`
  /// names a tier and offers an upgrade, which is a different sentence.
  Widget _buildStatementTile(String statement) {
    return WDiv(
      className:
          'flex flex-row items-start gap-2 rounded-md '
          'bg-surface-container-high p-2.5',
      children: <Widget>[
        WIcon(_infoIcon, className: 'text-sm text-fg-muted'),
        WText(statement, className: 'flex-1 text-xs leading-relaxed text-fg'),
      ],
    );
  }

  /// Opens the store's own subscription-management page.
  ///
  /// `Launch.url` answers false rather than throwing when nothing can handle the
  /// url, so a failure surfaces the same sentence the null-url branch renders:
  /// the customer still learns where to go. A discarded boolean there would be a
  /// discarded failure.
  Future<void> _openStoreManagement(String manageUrl) async {
    final bool opened = await Launch.url(manageUrl);
    if (opened) return;

    MagicFeedback.info(
      trans('magic_starter.billing.manage_header'),
      trans('magic_starter.billing.manage_store_no_url'),
    );
  }

  /// The "Update" affordance, which every branch of the payment card offers on a
  /// build whose rail can serve the portal.
  ///
  /// Extracted at the fourth copy. Three identical blocks read as a pattern; a
  /// fourth is a place for them to drift, and the thing they would drift on is
  /// which callback the button carries, on the one control that lets a customer
  /// replace a card. The `if (portalAvailable)` stays at each site because the
  /// branches differ in what they surround it with, and a method returning
  /// `Widget?` would hide that decision inside a nullable.
  MSButton _updateCardButton() {
    return MSButton(
      intent: ButtonIntent.secondary,
      size: ButtonSize.sm,
      onPressed: _openBillingPortal,
      child: WText(trans('magic_starter.billing.payment_update_button')),
    );
  }

  /// Builds the payment card's body for its states: a loading skeleton, a card,
  /// or one of the three answers an EMPTY read can carry.
  ///
  /// The empty read used to fall through to the card, and it rendered as one:
  /// the brand tile said "Unknown" and the number row, having no last four
  /// digits, fell back to the SECTION HEADING, so a customer with no card saw
  /// "Payment method" twice beside a tile implying a real card whose brand had
  /// been lost. A resolved non-answer is not a value; it gets named.
  ///
  /// It then has to be named CORRECTLY, which is the harder half. "Resolved with
  /// nothing" is two different facts sharing one body: the producer catches
  /// every failure from its live rail read and answers 200 with every field
  /// null, byte-identical to what a customer with no rail receives. Saying "no
  /// card on file" for both told a paying customer their card was gone whenever
  /// the rail was slow, which is a worse sentence than the incoherent tile it
  /// replaced, because it is confident and false rather than merely odd.
  ///
  /// [PaymentMethod.available] is the producer's own answer to which of the two
  /// it was, and it is the field this branches on rather than reconstructing the
  /// answer from `manage_via`. See [_buildEmptyPaymentContent] for its three
  /// states.
  ///
  /// "Resolved with nothing" is deliberately BOTH the brand and the last four
  /// digits being absent, not either: a rail that returned one without the other
  /// has partly answered, and claiming "no card on file" over a partial answer
  /// would be a second wrong sentence rather than a fix for the first.
  Widget _buildPaymentMethodContent() {
    if (controller.pmLoading) return _buildPaymentSkeletonRow();

    // A TRANSPORT failure, which no producer flag can express because the
    // response never arrived. Kept beside the three [PaymentMethod.available]
    // states rather than folded into them: `available` answers a question about
    // the rail, and this one is about the request.
    if (controller.pmError) {
      return _buildPaymentStatementRow(trans('common.error_occurred'));
    }

    final PaymentMethod? paymentMethod = controller.paymentMethod;

    if (paymentMethod == null ||
        (paymentMethod.brand == null && paymentMethod.last4 == null)) {
      return _buildEmptyPaymentContent(paymentMethod?.available);
    }

    final String? last4 = paymentMethod.last4;
    final String? expiry = _cardExpiry(paymentMethod);

    return WDiv(
      className: 'flex flex-row items-center gap-4',
      children: <Widget>[
        WDiv(
          className:
              'h-9 w-12 shrink-0 overflow-hidden '
              'rounded-md border border-color-border '
              'bg-surface-container-high',
          // Centred in Flutter, not in Wind: `place-items-*` is inert in Wind,
          // so a `grid place-items-center` tile sat its brand against the
          // top-left edge.
          child: Center(
            child: WText(
              // Reachable only on a PARTIAL answer (last four digits with no
              // brand); the all-null case returns above.
              paymentMethod.brand ?? trans('common.unknown'),
              className: 'text-xs font-semibold text-fg',
            ),
          ),
        ),
        Expanded(
          child: WDiv(
            className: 'flex flex-col min-w-0',
            children: <Widget>[
              WText(
                last4 != null
                    ? '•••• •••• •••• $last4'
                    : trans('magic_starter.billing.payment_header'),
                className: 'font-mono text-sm tabular-nums text-fg',
              ),
              if (expiry != null)
                WText(
                  trans(
                    'magic_starter.billing.payment_expires',
                    <String, dynamic>{'date': expiry},
                  ),
                  className: 'font-mono text-xs tabular-nums text-fg-muted',
                ),
            ],
          ),
        ),
        if (controller.portalAvailable) _updateCardButton(),
      ],
    );
  }

  /// The payment card's body for a read that RESOLVED and carried no card, in
  /// the three states [PaymentMethod.available] distinguishes.
  ///
  /// `false` is the producer saying its rail could not be asked, so the customer
  /// is told the read failed, next to the button that lets them replace the card
  /// anyway. `true` is the producer saying the rail answered and there is
  /// genuinely nothing on file. `null` is a producer that does not report the
  /// field at all, which is what an adopter on an older release sends, and it
  /// must NOT read as `false` or every such adopter would see their rail
  /// reported as down; that arm falls back to reconstructing the answer from
  /// `manage_via`, which is what the screen did before the field existed.
  ///
  /// In that reconstruction, an UNRESOLVED `manage_via` claims neither sentence:
  /// this read has answered and the entitlement read has not, so which of the
  /// two facts we are looking at is not yet knowable. A skeleton is the only
  /// honest thing left, and "an error occurred" through that window would put a
  /// false sentence on screen in a state where nothing had gone wrong. The wait
  /// is PERMANENT when the entitlement read failed rather than merely being
  /// slow, and that is visible rather than silent: the Update button below
  /// re-reads the entitlement through [_openBillingPortal]'s failure arm, which
  /// resolves this card. On a build with no web rail there is no button and the
  /// card shimmers until the next mount; said here so the next reader does not
  /// rediscover it as a bug.
  Widget _buildEmptyPaymentContent(bool? available) {
    return switch (available) {
      false => _buildPaymentStatementRow(trans('common.error_occurred')),
      true => _buildPaymentStatementRow(
        trans('magic_starter.billing.payment_none'),
      ),
      // The BUTTON stays on the unresolved arm. [MagicStarterBillingController
      // .portalAvailable] is permissive while the rail is unresolved on purpose,
      // and its docblock says why: a slow or failed read must not leave a paying
      // customer with no way to reach their card. An earlier draft returned the
      // skeleton alone and took the affordance away with it.
      null when controller.manageVia == null => _buildPaymentSkeletonRow(
        withUpdateButton: true,
      ),
      null => _buildPaymentStatementRow(
        controller.manageVia == ManageVia.none
            ? trans('magic_starter.billing.payment_none')
            : trans('common.error_occurred'),
      ),
    };
  }

  /// The payment card's shimmer, optionally keeping the Update affordance.
  Widget _buildPaymentSkeletonRow({bool withUpdateButton = false}) {
    return WDiv(
      className: 'flex flex-row items-center gap-4',
      children: <Widget>[
        const MSSkeleton(width: 48, height: 36),
        const Expanded(
          child: MSSkeleton(shape: SkeletonShape.text, height: 16),
        ),
        if (withUpdateButton && controller.portalAvailable) _updateCardButton(),
      ],
    );
  }

  /// The payment card's body when there is a sentence to show instead of a card.
  Widget _buildPaymentStatementRow(String statement) {
    return WDiv(
      className: 'flex flex-row items-center gap-4',
      children: <Widget>[
        Expanded(child: WText(statement, className: 'text-sm text-fg-muted')),
        if (controller.portalAvailable) _updateCardButton(),
      ],
    );
  }

  /// Reports a rail failure to the CUSTOMER, and the developer's version of it
  /// to the log.
  ///
  /// Every message a [BillingException] carries is written for whoever wired the
  /// rail up, not for the person holding the phone: `magic_payments` throws
  /// "Malformed usage response.", "Failed to open the hosted billing page." and,
  /// when a store rail has no key, a sentence naming a config key outright. Four
  /// call sites used to put that straight into a toast body, so a customer on a
  /// non-English session could be shown an internal config key in English. The
  /// text is still worth having, which is why it goes to the log rather than
  /// being dropped.
  ///
  /// The sentence a customer is shown is chosen by [BillingException.code],
  /// never by the message: the message is the developer's prose and the code is
  /// the stable half of the failure. A code with its own copy
  /// (`billing.errors.<code>`) says what actually happened, so "this store
  /// account is signed in for a different team" is not flattened into "something
  /// went wrong". [BillingErrorCode.unknown] has no cause to name and keeps the
  /// generic sentence.
  ///
  /// [UnsupportedPlatformException] keeps its own softer title and sentence,
  /// because it is not a failure: it is this build having no rail for the
  /// action, which reads as "not here yet" rather than "something broke". It
  /// extends [BillingException], so one catch covers both and the type test
  /// lives here.
  ///
  /// [BillingErrorCode.pending] is not a failure either. The store accepted the
  /// purchase and has not settled it, so it is told as information under the
  /// screen's own title and not as a failed checkout.
  ///
  /// No sentence names the web, deliberately. Steering a store customer to a web
  /// purchase is App Store rule 3.1.3(a), and a message written for a storeless
  /// build is exactly where that wording would creep back in.
  void _reportBillingFailure(BillingException error, {required String where}) {
    Log.error('[MagicStarterBillingView.$where] ${error.message}');

    if (error is UnsupportedPlatformException) {
      MagicFeedback.info(
        trans('magic_starter.billing.toast_deferred_title'),
        trans('magic_starter.billing.toast_deferred_text'),
      );

      return;
    }

    final String? copyKey = _errorCopyKey(error.code);
    final String text = copyKey == null
        ? trans('magic_starter.billing.toast_failed_text')
        : trans('magic_starter.billing.errors.$copyKey');

    if (error.code == BillingErrorCode.pending) {
      MagicFeedback.info(trans('magic_starter.billing.title'), text);

      return;
    }

    Magic.error(
      trans('magic_starter.billing.toast_checkout_failed_title'),
      text,
    );
  }

  /// The `billing.errors` key that carries the customer's copy for [code], or
  /// `null` for the code that names no cause.
  ///
  /// Exhaustive with no `default`, so a new [BillingErrorCode] is a compile
  /// error here rather than a customer reading the generic sentence for a cause
  /// the package already knows.
  String? _errorCopyKey(BillingErrorCode code) {
    return switch (code) {
      BillingErrorCode.managedElsewhere => 'managed_elsewhere',
      BillingErrorCode.identityMismatch => 'identity_mismatch',
      BillingErrorCode.notIdentified => 'not_identified',
      BillingErrorCode.pending => 'pending',
      BillingErrorCode.receiptInUse => 'receipt_in_use',
      BillingErrorCode.alreadyOwned => 'already_owned',
      BillingErrorCode.productUnavailable => 'product_unavailable',
      BillingErrorCode.network => 'network',
      BillingErrorCode.store => 'store',
      BillingErrorCode.unmappedActiveProduct => 'unmapped_active_product',
      BillingErrorCode.notConfigured => 'not_configured',
      BillingErrorCode.unknown => null,
    };
  }

  /// Opens the hosted billing portal, shared by the payment card's "Update" and
  /// every invoice row's "Receipt" (both are portal actions; the portal itself
  /// deep-links a customer straight to their invoice history).
  ///
  /// A build with no web rail returns without a word, and cannot be reached from
  /// the UI: [MagicStarterBillingController.portalAvailable] gates every
  /// affordance that calls this on the same rail. The guard is here because a
  /// null rail is not an error to report to a customer, it is a button that was
  /// never rendered.
  ///
  /// A REAL failure re-reads the entitlement, and an
  /// [UnsupportedPlatformException] does not, because it carries no server state
  /// to re-read. The endpoint has two refusals this screen's own gate is supposed
  /// to have made unreachable (a store rail owning the subscription, and no
  /// billing account at all, both of which imply a `manage_via` other than
  /// `portal`), so reaching one means the rail changed under a mounted screen.
  /// Re-reading the authority is the fix, and it keys off the server's
  /// `manage_via` rather than off the refusal's English sentence.
  Future<void> _openBillingPortal() async {
    final WebBillingService? web = controller.webRail;
    if (web == null) return;

    try {
      // A null return url is honourable: the portal's own default lands the
      // customer back with the rail, whereas checkout REQUIRES absolute urls and
      // is gated on the origin instead.
      await web.openPortal(returnUrl: _billingUrl());
    } on BillingException catch (error) {
      _reportBillingFailure(error, where: 'openBillingPortal');

      // Only this site re-reads: the two refusals it can hit both mean the rail
      // changed under a mounted screen, and the authority is the server's
      // `manage_via`, never the refusal's sentence.
      if (error is! UnsupportedPlatformException) {
        await controller.loadEntitlement();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Billing history
  // ---------------------------------------------------------------------------

  /// Builds the billing-history card: one row per invoice, full bleed.
  ///
  /// Paged, and lazily rendered once there is more than a card's worth. The
  /// producer has always paged this endpoint; the client used to read
  /// `page.invoices` and drop `page.nextCursor`, so a customer with more than
  /// one page could never see past the first. Reaching the end of the list now
  /// asks for the next one.
  ///
  /// Below [_invoiceLazyThreshold] rows the card renders them eagerly and keeps
  /// its own height, because a fixed 420px body around three invoices is worse
  /// than the problem: a `ListView` needs a bound, and a bound is only worth
  /// paying for once the list is long enough to scroll.
  ///
  /// A short first page that carries a cursor is lazy anyway, whatever the row
  /// count. `MagicPaginatedListView` is the only thing here that ever calls
  /// `loadMore`, through its post-frame viewport fill, so a producer paging at
  /// fewer than [_invoiceLazyThreshold] rows would otherwise render page one
  /// eagerly and strand every page after it: the defect this section was
  /// rewritten to fix, reintroduced by the threshold that shortens it.
  Widget _buildInvoicesSection() {
    final MagicPaginator<Invoice>? pages = controller.invoicePages;
    final List<Invoice> invoices = controller.invoices;
    final bool lazy =
        pages != null &&
        (invoices.length >= _invoiceLazyThreshold || pages.hasMore);

    return MSCard(
      title: trans('magic_starter.billing.invoices_header'),
      noPadding: true,
      child: lazy
          ? WDiv(
              className: 'h-[${_invoiceBodyHeight}px]',
              child: MagicPaginatedListView<Invoice>(
                paginator: pages,
                itemBuilder: (_, Invoice invoice, int index) =>
                    _buildInvoiceRow(
                      invoice,
                      // Never the last row while more can arrive: the divider
                      // is what tells the reader the list continues.
                      isLast: !pages.hasMore && index == invoices.length - 1,
                    ),
              ),
            )
          : WDiv(
              className: 'flex flex-col',
              children: <Widget>[
                for (final (int index, Invoice invoice) in invoices.indexed)
                  _buildInvoiceRow(
                    invoice,
                    isLast: index == invoices.length - 1,
                  ),
              ],
            ),
    );
  }

  /// Builds one invoice row: date and number, the status pill, the amount, and,
  /// where the portal is this customer's surface, a "Receipt" button.
  Widget _buildInvoiceRow(Invoice invoice, {required bool isLast}) {
    return WDiv(
      className: isLast
          ? 'flex flex-row items-center gap-3 px-5 py-3.5'
          : 'flex flex-row items-center gap-3 px-5 py-3.5 '
                'border-b border-color-border',
      children: <Widget>[
        Expanded(
          child: WDiv(
            className: 'flex flex-col min-w-0',
            children: <Widget>[
              WText(
                _formatDate(invoice.date) ?? '',
                className: 'truncate text-sm font-medium text-fg',
              ),
              WText(
                invoice.number,
                className: 'truncate text-xs text-fg-muted',
              ),
            ],
          ),
        ),
        _buildStatusPill(invoice.status),
        WText(
          invoice.amount,
          className: 'font-mono text-sm tabular-nums text-fg',
        ),
        // The receipt is a portal deep link, not a stored document url, so it is
        // gated on the portal being this customer's surface at all.
        if (controller.portalAvailable)
          MSButton(
            intent: ButtonIntent.ghost,
            size: ButtonSize.sm,
            onPressed: _openBillingPortal,
            child: WText(trans('magic_starter.billing.invoice_receipt_button')),
          ),
      ],
    );
  }

  /// Builds the settlement pill for [status].
  ///
  /// [MSBadge] rather than a hand-rolled pill: the registry already ships the
  /// shape and the three tones, and its tone vocabulary
  /// (success/warning/destructive) is the package's own rather than one
  /// consumer's status language.
  ///
  /// The copy switch sits beside the tone switch on purpose. `magic_payments`
  /// carries [InvoiceStatus] as a pure vocabulary with no label getter, because
  /// a display word would ship one vendor's English into every consumer; the two
  /// switches being adjacent is what keeps the tone and the word from drifting
  /// apart. Both are exhaustive with no `default`, so a fourth settlement state
  /// is a compile error here rather than an unlabelled pill.
  Widget _buildStatusPill(InvoiceStatus status) {
    final BadgeTone tone = switch (status) {
      InvoiceStatus.paid => BadgeTone.success,
      InvoiceStatus.pending => BadgeTone.warning,
      InvoiceStatus.failed => BadgeTone.destructive,
    };

    final String label = switch (status) {
      InvoiceStatus.paid => trans('magic_starter.billing.invoice_status.paid'),
      InvoiceStatus.pending => trans(
        'magic_starter.billing.invoice_status.pending',
      ),
      InvoiceStatus.failed => trans(
        'magic_starter.billing.invoice_status.failed',
      ),
    };

    return MSBadge(label, tone: tone);
  }

  // ---------------------------------------------------------------------------
  // Purchase paths
  // ---------------------------------------------------------------------------

  /// Starts checkout for the plan named in the upgrade query, so a gated action
  /// elsewhere in the app can hand the customer straight into the purchase
  /// instead of dropping them on the grid to find the tier themselves.
  ///
  /// Runs once per mount, only for a tier the catalogue serves and only when it
  /// is above the current plan (a stale link to the tier the customer already
  /// pays for must not open a checkout). Silently does nothing otherwise: the
  /// grid is still there to pick from by hand.
  ///
  /// Both the catalogue and the entitlement have to be in before it fires, so it
  /// hangs off the controller's own notifications rather than off a frame.
  ///
  /// The token is consumed process-wide, not per mount: an arrival can mount
  /// this screen twice and both mounts resolve their reads at about the same
  /// instant, so a per-mount guard let one arrival open two checkout sessions. A
  /// hand-typed url with no token falls back to the plan id, so it still fires
  /// once, and a later Upgrade tap mints a new token and fires again.
  void _startRequestedUpgrade() {
    if (_upgradeRequestHandled) return;
    if (controller.plans.isEmpty || !controller.entitlementLoaded) return;
    // The same gate the call to action renders behind. A deep link is the one
    // path that can reach checkout without a tap, so a store-billed customer or
    // a non-owner arriving on an upgrade link would otherwise be handed a
    // purchase the server is about to refuse.
    if (!_canPurchase) return;

    final Map<String, String> query = MagicRouter.instance.queryParameters;
    final String? requested = query[PlanUpgradeRequirement.planQueryKey];
    if (requested == null || requested.isEmpty) return;

    final String token =
        query[PlanUpgradeRequirement.intentQueryKey] ?? requested;
    if (_consumedUpgradeIntent == token) return;

    final MagicStarterPlan? target = controller.plans
        .where((MagicStarterPlan plan) => plan.id == requested)
        .firstOrNull;
    // A `null` direction means the held tier is unrankable (absent from the
    // catalogue), so there is no confirmed upgrade to open; refusing here is the
    // same "no fallback" answer [_ctaLabel] renders for the same state.
    final int? direction = target == null ? null : _direction(target);
    if (target == null || direction == null || direction <= 0) return;

    _upgradeRequestHandled = true;
    _consumedUpgradeIntent = token;
    // Also drop the query from the url, so a reload of what the customer now
    // sees in the address bar does not read as a fresh purchase intent.
    MagicRoute.replace(MagicStarterConfig.billingRoute());
    _selectPlan(target);
  }

  /// Selects [plan]: hands off to sales for a custom tier, buys through the
  /// STORE rail where this build has one, and otherwise starts a hosted checkout
  /// session, both keyed by the catalogue product this build sells the tier as
  /// on the selected cycle ([_saleProduct]).
  ///
  /// Both rails are keyed by that same catalogue key (`pro_annual`), never by a
  /// store SKU or a price id: what a key maps to belongs to the rail's catalogue,
  /// and a client naming one would need a release to add or reprice a product.
  /// One key names the tier AND the cycle, so a call cannot send half of the
  /// pair. A priced tier with no product to name is reported as unavailable
  /// rather than bought on a guess.
  ///
  /// The store is asked FIRST, and that is a routing decision rather than a
  /// preference: no build serves both rails, and a store build must never fall
  /// through to the web checkout the store forbids steering to.
  ///
  /// The custom tier's sales handoff runs on a build with no rail at all, because
  /// it spends nothing and calls nothing. Its toast names the tier from the
  /// CATALOGUE rather than from a literal, because a framework package cannot
  /// know what an adopter calls its top tier.
  ///
  /// A priced tier with neither rail, or with no configured origin, returns
  /// silently: [_canPurchase] gates every call to action that reaches here, so
  /// there is no button to explain a refusal to.
  Future<void> _selectPlan(MagicStarterPlan plan) async {
    // 1. Custom tier: hand off to sales, no live billing call.
    if (_isCustom(plan)) {
      Magic.success(
        trans('magic_starter.billing.toast_contact_title'),
        trans(
          'magic_starter.billing.toast_contact_description',
          <String, dynamic>{'name': plan.name},
        ),
      );

      return;
    }

    // 2. Name the product the card is showing. The same product the card was
    //    priced from, so the key, the card's figure and the toast below all
    //    agree, and never a grandfathered one.
    final MagicStarterProduct? product = _saleProduct(plan);
    if (product == null) {
      _reportBillingFailure(
        const BillingException(
          'The catalogue names no product for this tier.',
          code: BillingErrorCode.productUnavailable,
        ),
        where: 'selectPlan',
      );

      return;
    }

    // 3. A store build buys in the store.
    if (controller.storeRail != null) return _purchaseInStore(product);

    // 4. Priced tier: start checkout, redirecting the rail back to this screen
    //    on completion or abort.
    final WebBillingService? web = controller.webRail;
    final String? successUrl = _billingUrl('checkout=success');
    final String? cancelUrl = _billingUrl('checkout=cancel');
    if (web == null || successUrl == null || cancelUrl == null) return;

    // An unrankable direction (the held tier is absent from the catalogue) reads
    // as a plan switch rather than an upgrade: the toast is copy on an
    // already-completed purchase, not a claim about the tier's position.
    final int? direction = _direction(plan);
    final bool isUpgrade = direction != null && direction > 0;

    try {
      await web.checkout(
        // The product for the cycle the card's price was rendered for, so the
        // customer is charged the figure they were shown. The cycle used to
        // reach nothing, and the toast below already claimed it, so a customer
        // taking the annual discount was billed monthly and told otherwise.
        //
        // Per card rather than screen-wide: see [_cycleFor], and note the toast
        // below has to read the same value or the two disagree again.
        productKey: product.key,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );
      Magic.success(
        trans(
          isUpgrade
              ? 'magic_starter.billing.toast_upgrade_title'
              : 'magic_starter.billing.toast_switch_title',
          <String, dynamic>{'name': plan.name},
        ),
        trans(
          'magic_starter.billing.toast_change_description',
          <String, dynamic>{'cycle': _cycleLabel(_cycleFor(plan))},
        ),
      );
    } on BillingException catch (error) {
      _reportBillingFailure(error, where: 'startWebCheckout');
    }
  }

  /// Buys [product] through the STORE rail: the platform's own purchase sheet,
  /// on the store product the rail's catalogue maps the catalogue key to.
  ///
  /// The one-team refusal is re-ASKED here rather than read off the mount-time
  /// answer, because this is the point where the money moves: a tap can arrive
  /// long after the screen loaded, and the deep-link path
  /// ([_startRequestedUpgrade]) can arrive before that read resolved at all. One
  /// extra request on a tap is cheaper than a transfer nobody asked for. It names
  /// the team, for the same reason the notice above the grid does.
  ///
  /// A dismissed sheet is the ordinary outcome of a customer closing it, so it
  /// reports nothing at all: an "it did not work" toast for a deliberate
  /// dismissal would be this screen inventing a failure. A completed one is the
  /// STORE's word and not the producer's, so the controller waits for the
  /// entitlement to move before this screen says anything (see
  /// [MagicStarterBillingController.purchaseInStoreAndWait]), and what it says
  /// depends on how the wait ended: confirmed, applying at the end of the
  /// current period, or still processing when the minute ran out.
  Future<void> _purchaseInStore(MagicStarterProduct product) async {
    if (controller.storeRail == null) return;

    await controller.loadStoreFundedTeam();
    if (!mounted) return;

    final String? fundedTeam = controller.storeFundedTeam;
    if (fundedTeam != null) {
      Magic.error(
        trans('magic_starter.billing.store_bound_title'),
        trans('magic_starter.billing.store_bound_text', <String, dynamic>{
          'team': fundedTeam,
        }),
      );

      return;
    }

    // The period the CURRENT subscription runs to, taken before the sheet
    // opens: a change the store applies at renewal starts then, and a read
    // that lands while the sheet is up must not move the date it names.
    final DateTime? currentPeriodEnd =
        controller.entitlementSnapshot.currentPeriodEnd;

    try {
      // Through the controller, which hands the rail the catalogue's tier
      // order and holds the store gate shut until the entitlement confirms.
      final MagicStarterStorePurchaseOutcome outcome = await controller
          .purchaseInStoreAndWait(product);
      if (!mounted) return;

      switch (outcome) {
        case MagicStarterStorePurchaseOutcome.dismissed:
        case MagicStarterStorePurchaseOutcome.abandoned:
          return;
        case MagicStarterStorePurchaseOutcome.confirmed:
          Magic.success(
            trans('magic_starter.billing.store_purchase_title'),
            trans('magic_starter.billing.store_purchase_text'),
          );
        case MagicStarterStorePurchaseOutcome.deferred:
          Magic.success(
            trans('magic_starter.billing.store_purchase_title'),
            trans(
              'magic_starter.billing.wait_takes_effect_on',
              <String, dynamic>{
                'date':
                    _formatDate(currentPeriodEnd) ?? trans('common.unknown'),
              },
            ),
          );
        case MagicStarterStorePurchaseOutcome.processing:
          MagicFeedback.info(
            trans('magic_starter.billing.store_purchase_title'),
            trans('magic_starter.billing.wait_processing'),
          );
      }
    } on BillingException catch (error) {
      _reportBillingFailure(error, where: 'purchaseInStore');
    }
  }

  /// Asks the store for a subscription this account already owns, which is the
  /// customer's only route back after a reinstall or onto a second device, and is
  /// required of any app that sells through a store.
  ///
  /// Both answers are reported, and neither is a failure: `false` means the store
  /// had nothing for this account, which is an answer the customer needs rather
  /// than an error to log. A restore that DID hand something back carries the
  /// same non-promise as a purchase, so it re-reads the entitlement instead of
  /// claiming the plan changed.
  Future<void> _restoreStorePurchases() async {
    final StoreBillingService? store = controller.storeRail;
    if (store == null) return;

    try {
      final bool restored = await store.restore();
      if (!mounted) return;

      if (!restored) {
        MagicFeedback.info(
          trans('magic_starter.billing.store_restore_none_title'),
          trans('magic_starter.billing.store_restore_none_text'),
        );

        return;
      }

      Magic.success(
        trans('magic_starter.billing.store_restore_found_title'),
        trans('magic_starter.billing.store_purchase_text'),
      );
      await controller.loadEntitlement();
    } on BillingException catch (error) {
      _reportBillingFailure(error, where: 'restoreStorePurchases');
    }
  }

  // ---------------------------------------------------------------------------
  // Labels, prices and dates
  // ---------------------------------------------------------------------------

  /// Resolves the call-to-action label for [plan] against the current plan.
  ///
  /// "Current plan" for the active tier; "Contact sales" for a custom tier;
  /// otherwise "Upgrade" or "Downgrade" by position. While the current plan is
  /// unresolved, no card may claim to be the active tier or an upgrade target, so
  /// every priced tier falls back to a neutral label (the custom tier still reads
  /// "Contact sales", since that copy never depended on the current plan). Once
  /// resolved, a held tier the catalogue no longer serves makes [_direction]
  /// unrankable, so every priced tier falls back to a second neutral label rather
  /// than claiming a direction against a tier with no known position.
  String _ctaLabel(MagicStarterPlan plan) {
    if (_isCustom(plan)) {
      return trans('magic_starter.billing.plan_button_contact');
    }
    if (controller.currentPlanId == null) {
      return trans('magic_starter.billing.plan_button_unresolved');
    }
    if (plan.id == controller.currentPlanId) {
      return trans('magic_starter.billing.plan_button_current');
    }

    final int? direction = _direction(plan);
    if (direction == null) {
      return trans('magic_starter.billing.plan_button_unranked');
    }

    return direction > 0
        ? trans('magic_starter.billing.plan_button_upgrade')
        : trans('magic_starter.billing.plan_button_downgrade');
  }

  /// The emphasis [plan]'s call to action carries.
  ///
  /// There is exactly ONE filled button on this grid, and picking it is the
  /// whole job. It used to be `recommended && !isCurrent`, which meant that a
  /// customer already ON the recommended tier saw no filled button anywhere:
  /// four identical grey rectangles, no focal point, and no way to tell the
  /// disabled one from the live ones.
  ///
  /// The filled one is the cheapest tier ABOVE what the customer holds, because
  /// that is the move a grid should make easy, and there is none at all until
  /// the entitlement says what they hold.
  ///
  /// TWO treatments, not three. A downgrade was `ghost` for one revision, on the
  /// reasoning that a grid should not invite it, and `ghost` in this package is
  /// `bg-transparent` with no border: in a card footer it rendered as bare text
  /// with no affordance at all, indistinguishable from the feature list above
  /// it. "Quieter" turned into "not a button". A downgrade is a real action a
  /// customer is entitled to take, so it looks like one; the single filled
  /// button is what carries the hierarchy, and it carries it on its own.
  ButtonIntent _ctaIntent(MagicStarterPlan plan) {
    return plan.id == _featuredUpgradeId
        ? ButtonIntent.primary
        : ButtonIntent.secondary;
  }

  /// The plan id that carries the grid's one filled button, or `null` when
  /// nothing should.
  ///
  /// Null is a real answer and not a gap: a customer on the top tier has nothing
  /// above them, and inventing a filled button for a sideways move would point
  /// at something that is not an upgrade.
  ///
  /// It is also the answer while the entitlement is UNRESOLVED, and that is the
  /// correction of a premise this getter shipped with. It fell back to the
  /// vendor's `recommended` flag there, on the reasoning that an unresolved
  /// current plan is "a visitor with nothing to compare against". No such state
  /// exists: [MagicStarterBillingController.currentPlanId] is null before
  /// `loadEntitlement` resolves and permanently after a failed read, and a
  /// customer on the free tier resolves to `free` like any other. So the branch
  /// ran while the grid was still loading (plans and entitlement load in
  /// parallel, so the cards can paint first) or after the read had failed for
  /// good, and in both [_ctaLabel] returns the deliberately neutral
  /// `plan_button_unresolved` for the very card the fill was pointing at. The
  /// label refuses to claim a direction there on purpose; a filled button makes
  /// the same claim in colour, and after a failed read it never goes away.
  String? get _featuredUpgradeId {
    final List<MagicStarterPlan> plans = controller.plans;

    if (controller.currentPlanId == null) return null;

    // The cheapest tier above the held one, in catalogue order, that this build
    // can actually sell. A custom tier is skipped: its call to action is a
    // sales handoff, not a purchase, so filling it would promise a checkout
    // that does not exist. So is a tier this build sells no product of, which
    // renders no button at all.
    for (final MagicStarterPlan plan in plans) {
      final int? direction = _direction(plan);

      if (direction != null &&
          direction > 0 &&
          !_isCustom(plan) &&
          _saleProduct(plan) != null) {
        return _canPurchase ? plan.id : null;
      }
    }

    return null;
  }

  /// The tier distance of [plan] from the current plan: positive when [plan] is
  /// higher (an upgrade), negative when lower, `0` while the current plan is
  /// still unresolved so no caller can read a false direction.
  ///
  /// `null` when the direction cannot be decided: the held tier is one the
  /// catalogue no longer serves, so it has no rank to compare against. An
  /// unrankable tier has no direction rather than being treated as the cheapest
  /// one, which is what used to show a grandfathered customer another tier's
  /// name, price and features as their own.
  int? _direction(MagicStarterPlan plan) {
    final String? planId = controller.currentPlanId;
    if (planId == null) return 0;

    final int? currentIndex = _planIndex(planId);
    if (currentIndex == null) return null;

    // [plan] is always sourced from the catalogue (the grid, or the deep-link
    // lookup), so its own index always resolves; kept explicit rather than
    // asserted, since a defensive read costs nothing here.
    final int? planIndex = _planIndex(plan.id);
    if (planIndex == null) return null;

    return planIndex - currentIndex;
  }

  /// What a card off the store rail shows where its price goes, and whether
  /// that is a SENTENCE (rendered as one) rather than a figure or a one-word
  /// label.
  ///
  /// 1. The floor and a custom tier sell no product, so each keeps its word.
  /// 2. A tier the web sells nothing on (priced in a store only) says where it
  ///    is sold instead of showing a price nobody here can pay.
  /// 3. A web product the producer gave no displayable price says the hosted
  ///    checkout shows it, which it does before anybody is charged.
  /// 4. Otherwise the producer's own display string (`29.00 USD`), so no
  ///    amount arithmetic or currency table lives here. Of the currencies a
  ///    product is priced in, the first the producer lists is shown: the client
  ///    cannot know which one the rail will charge, and that order is the
  ///    vendor's own.
  ({String text, bool sentence}) _webPrice(
    MagicStarterPlan plan, {
    required bool isFloor,
    required bool isCustom,
  }) {
    // 1. No product to price.
    if (isFloor) {
      return (
        text: trans('magic_starter.billing.plan_price_free'),
        sentence: false,
      );
    }
    if (isCustom) {
      return (
        text: trans('magic_starter.billing.plan_price_custom'),
        sentence: false,
      );
    }

    // 2. Sold, but not on the web.
    final MagicStarterProduct? product = plan.webProductFor(_cycle);
    if (product == null) {
      return (
        text: trans('magic_starter.billing.plan_price_app'),
        sentence: true,
      );
    }

    // 3. and 4. Sold on the web, with or without a figure to show.
    final MagicStarterWebPrice? price = product.webPrices.values.firstOrNull;

    return price == null
        ? (
            text: trans('magic_starter.billing.plan_price_checkout'),
            sentence: true,
          )
        : (text: price.display, sentence: false);
  }

  /// The web price of the product [current] is billed as on [cycle], or `null`
  /// when none can be named.
  ///
  /// The product the entitlement names first, grandfathered or not, because
  /// that is what the customer pays; otherwise the tier's sellable product on
  /// [cycle], never one on another cycle, since the sentence names [cycle].
  MagicStarterWebPrice? _heldWebPrice(
    MagicStarterPlan current,
    BillingCycle cycle,
  ) {
    final String? heldKey = controller.entitlementSnapshot.product;
    final MagicStarterProduct? product =
        current.products
            .where((MagicStarterProduct product) => product.key == heldKey)
            .firstOrNull ??
        current.sellableProducts
            .where((MagicStarterProduct product) => product.cycle == cycle)
            .firstOrNull;

    return product?.webPrices.values.firstOrNull;
  }

  /// The under-price billing note for [plan] at the selected cycle.
  String _billingNote(MagicStarterPlan plan) {
    if (_isCustom(plan)) {
      return trans('magic_starter.billing.plan_billing_custom');
    }
    // The floor first: it has no cycle to name, and checked after the cycle it
    // read "billed annually" under a free tier on any build whose toggle sat on
    // Annual.
    if (_isFloor(plan)) {
      return trans('magic_starter.billing.plan_billing_free');
    }
    // On every rail, the store included: both sell the product for the selected
    // cycle, so the note follows it. It used to be gated on the store rail
    // because the store catalogue was thought to carry monthly SKUs only, which
    // printed "billed monthly" under an annual price.
    if (_cycleFor(plan) == BillingCycle.annual) {
      return trans('magic_starter.billing.plan_billing_annual');
    }

    return trans('magic_starter.billing.plan_billing_monthly');
  }

  /// The renewal and description cycle word for [cycle].
  String _cycleLabel(BillingCycle cycle) {
    return switch (cycle) {
      BillingCycle.monthly => trans(
        'magic_starter.billing.renewal_cycle_monthly',
      ),
      BillingCycle.annual => trans(
        'magic_starter.billing.renewal_cycle_annual',
      ),
    };
  }

  /// The word a recurring price is stated per on [cycle]: `month` or `year`.
  ///
  /// Not [_cycleLabel]: that one is the adverb of "billed annually", and "per
  /// annually" is not a phrase. The words are the store disclosure's own.
  String _periodWord(BillingCycle cycle) {
    return switch (cycle) {
      BillingCycle.monthly => trans(
        'magic_starter.billing.store_disclosure_period_month',
      ),
      BillingCycle.annual => trans(
        'magic_starter.billing.store_disclosure_period_year',
      ),
    };
  }

  /// [count] of [unit] (`day`, `week`, `month`, `year`) as a phrase: `1 day`,
  /// `14 days`.
  String _periodLabel(int count, String unit) =>
      _counted('magic_starter.billing.period_$unit', count);

  /// The length of an ISO 8601 [period] (`P14D`, `P2W`, `P1M`, `P1Y`) as a
  /// phrase, or `null` when it is absent or not one whole unit.
  ///
  /// `null` is an answer the caller acts on: a store period this cannot read
  /// states no trial at all, since the alternative is a free offer of a length
  /// the screen made up.
  String? _isoPeriodLabel(String? period) {
    if (period == null) return null;

    final RegExpMatch? match = _isoPeriod.firstMatch(period);
    if (match == null) return null;

    final int? count = int.tryParse(match.group(1)!);
    final String? unit = _isoPeriodUnits[match.group(2)];
    if (count == null || count < 1 || unit == null) return null;

    return _periodLabel(count, unit);
  }

  /// Picks the `_one` or `_other` form of [key] for [count], and passes the
  /// number through as `:count`.
  ///
  /// The translator has no plural API, so the choice lives here. English has
  /// exactly two forms, and a catalogue in a language with more can still put
  /// whatever it needs behind the two keys.
  String _counted(String key, int count) {
    return trans('${key}_${count == 1 ? 'one' : 'other'}', <String, dynamic>{
      'count': count,
    });
  }

  /// Formats [instant] as `"Jun 1, 2026"`, or `null` when there is no date.
  ///
  /// `magic_payments` hands `Invoice.date` and `PaymentMethod.renewalDate` over
  /// as instants rather than as formatted strings, precisely so a package does
  /// not freeze one date convention into every consumer, so this is the screen's
  /// own rendering.
  ///
  /// Returns `null` rather than an empty string so a caller can tell "no date"
  /// from a formatted one with a plain `!= null` check; the invoice row, which
  /// wants a string either way, falls back with `?? ''`.
  String? _formatDate(DateTime? instant) {
    if (instant == null) return null;

    return '${_monthAbbreviations[instant.month - 1]} '
        '${instant.day}, ${instant.year}';
  }

  /// The card-expiry line for [paymentMethod] (`"08 / 27"`), or `null` when the
  /// rail reported no card.
  ///
  /// Built from the rail's own two numbers, which is what the package carries: a
  /// separator, a zero pad and a two- versus four-digit year are rendering
  /// decisions, and a package freezing them would hand every consumer the same
  /// card row. Both numbers are required, because a month with no year is not an
  /// expiry.
  String? _cardExpiry(PaymentMethod? paymentMethod) {
    final int? month = paymentMethod?.expMonth;
    final int? year = paymentMethod?.expYear;
    if (month == null || year == null) return null;

    return '${month.toString().padLeft(2, '0')} / '
        '${(year % 100).toString().padLeft(2, '0')}';
  }

  /// The absolute url a rail returns the customer to, or `null` when the consumer
  /// configured no web origin.
  ///
  /// [MagicStarterConfig.billingWebOrigin] carries no default on purpose: a
  /// guessed origin yields a relative url the rail refuses, and that refusal is
  /// reported to the log rather than to the customer.
  String? _billingUrl([String? query]) {
    final String? origin = MagicStarterConfig.billingWebOrigin();
    if (origin == null) return null;

    final String url = '$origin${MagicStarterConfig.billingRoute()}';

    return query == null ? url : '$url?$query';
  }

  /// The index of the plan with [id] in the catalogue, or `null` when [id] is
  /// absent from it: a tier this customer is grandfathered on that the vendor no
  /// longer serves.
  int? _planIndex(String id) {
    final List<MagicStarterPlan> plans = controller.plans;
    for (int i = 0; i < plans.length; i++) {
      if (plans[i].id == id) return i;
    }

    return null;
  }

  /// The plan with [id] in the catalogue, or `null` when [id] is absent from it
  /// (see [_planIndex]).
  MagicStarterPlan? _findPlan(String id) {
    final int? index = _planIndex(id);

    return index == null ? null : controller.plans[index];
  }
}
