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
/// included. That map is the point: the package types the eight fields every
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

  /// The one currency code this package renders as a symbol.
  ///
  /// [MagicStarterPlan.currency] documents the rest of the rule: anything else
  /// falls back to the raw wire code beside the amount, because a currency
  /// formatting table is not a thing this package owns.
  static const String _usdCurrency = 'usd';

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
  /// tier has no price for it.
  ///
  /// A catalogue row with a monthly price and no annual one is a state this
  /// screen already expects (`_priceLabel` renders the custom label for it and
  /// `_billingNote` guards on it), and [_cycle] is a screen-wide value that knows
  /// nothing about the row it is being applied to. Left unqualified, such a tier
  /// stayed purchasable while the toggle sat on Annual and handed the checkout a
  /// (tier, annual) pair the producer has no price for: an unresolvable payload
  /// on a live Upgrade button, and the same class of defect as charging the
  /// monthly figure under an annual heading, since the customer is again offered
  /// one thing and sold another.
  ///
  /// Deliberately per CARD rather than a refusal in [_selectPlan]. That row is
  /// sellable, monthly, and refusing it would hide a tier the vendor is selling
  /// because of a toggle position; naming its real cycle sells it at the figure
  /// its card shows.
  BillingCycle _cycleFor(MagicStarterPlan plan) =>
      plan.annual == null ? BillingCycle.monthly : _cycle;

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
  }

  @override
  void onClose() {
    controller.removeListener(_startRequestedUpgrade);
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
  Widget _buildCurrentPlanCard() {
    final String? planId = controller.currentPlanId;
    final bool resolving = controller.plans.isEmpty || planId == null;
    final MagicStarterPlan? current = _current;

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
                  ],
                ),
                WText(
                  _renewalLine(current),
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
    if (current.monthly == 0 && current.annual == 0) {
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
    // whole change exists to stop making.
    final BillingCycle? cycle = controller.cycle;

    if (cycle == null) {
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
        'price': _priceLabel(current, cycle),
        'cycle': _cycleLabel(cycle),
        'date':
            _formatDate(controller.paymentMethod?.renewalDate) ??
            trans('common.unknown'),
      },
    );
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
  /// The monthly/annual toggle is absent on a store build, and that absence is
  /// correctness rather than tidiness: a store catalogue carries the MONTHLY
  /// SKUs only, so a customer who picked "Annual" and tapped Upgrade would be
  /// charged monthly by the sheet that opened.
  Widget _buildPlansSection() {
    final String? fundedTeam = controller.storeFundedTeam;

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
            if (controller.storeRail == null)
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
    final bool isCustom = plan.monthly == null;
    // The catalogue's price is a figure in the vendor's own currency, and a
    // store charges a storefront-localised amount in the customer's, so on a
    // store build that figure is not the price of anything. The rail's own
    // localised string is the right source and the driver exposes none, so this
    // states where the price comes from instead: the sheet shows the real one
    // before anybody is charged, and showing a wrong price is worse than showing
    // none. A zero price stays a zero price, which is true in every currency,
    // and the custom tier keeps its own label.
    final bool storePriced =
        controller.storeRail != null && !isCustom && plan.monthly != 0;
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
        ValueListenableBuilder<BillingCycle?>(
          valueListenable: _cycleOverride,
          builder: (_, _, _) => WDiv(
            className: 'flex flex-col gap-0.5',
            children: <Widget>[
              if (storePriced)
                WText(
                  trans('magic_starter.billing.plan_price_store'),
                  className: 'text-base font-medium text-fg',
                )
              else
                WDiv(
                  className: 'flex flex-row items-baseline gap-1',
                  children: <Widget>[
                    WText(
                      _priceLabel(plan, _cycleFor(plan)),
                      className: 'text-3xl font-semibold tabular-nums text-fg',
                    ),
                    if (!isCustom)
                      WText(
                        trans('magic_starter.billing.plan_price_monthly'),
                        className: 'text-sm text-fg-muted',
                      ),
                  ],
                ),
              WText(_billingNote(plan), className: 'text-xs text-fg-muted'),
            ],
          ),
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
        //    The button below therefore renders for two reasons, both of them
        //    live: a custom tier's sales handoff (driven by the GRID rather
        //    than by the entitlement, so it survives both gates and spends
        //    nothing), and an actual purchase, which needs a rail and the
        //    membership to allow it. Which of the four emphases it takes is
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
        else if (isCustom || _canPurchase)
          MSButton(
            intent: _ctaIntent(plan),
            fullWidth: true,
            onPressed: () => _selectPlan(plan),
            child: WText(_ctaLabel(plan)),
          ),
      ],
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
  /// [UnsupportedPlatformException] keeps its own softer title and sentence,
  /// because it is not a failure: it is this build having no rail for the
  /// action, which reads as "not here yet" rather than "something broke". It
  /// extends [BillingException], so one catch covers both and the type test
  /// lives here.
  ///
  /// Neither sentence names the web, deliberately. Steering a store customer to
  /// a web purchase is App Store rule 3.1.3(a), and a message written for a
  /// storeless build is exactly where that wording would creep back in.
  void _reportBillingFailure(BillingException error, {required String where}) {
    Log.error('[MagicStarterBillingView.$where] ${error.message}');

    if (error is UnsupportedPlatformException) {
      MagicFeedback.info(
        trans('magic_starter.billing.toast_deferred_title'),
        trans('magic_starter.billing.toast_deferred_text'),
      );

      return;
    }

    Magic.error(
      trans('magic_starter.billing.toast_checkout_failed_title'),
      trans('magic_starter.billing.toast_failed_text'),
    );
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
  /// session keyed by the plan id.
  ///
  /// Both rails are keyed by that same plan id, never by a store product id: the
  /// SKU a plan maps to belongs to the rail's catalogue, and a client naming one
  /// would need a release to add or reprice a product.
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
    if (plan.monthly == null) {
      Magic.success(
        trans('magic_starter.billing.toast_contact_title'),
        trans(
          'magic_starter.billing.toast_contact_description',
          <String, dynamic>{'name': plan.name},
        ),
      );

      return;
    }

    // 2. A store build buys in the store.
    if (controller.storeRail != null) return _purchaseInStore(plan);

    // 3. Priced tier: start checkout, redirecting the rail back to this screen
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
        plan: plan.id,
        // The cycle the card's price was rendered for, so the customer is
        // charged the figure they were shown. It used to reach nothing, and the
        // toast two lines below already claimed it, so a customer taking the
        // annual discount was billed monthly and told otherwise.
        //
        // Per card rather than screen-wide: see [_cycleFor], and note the toast
        // below has to read the same value or the two disagree again.
        cycle: _cycleFor(plan),
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

  /// Buys [plan] through the STORE rail: the platform's own purchase sheet, on
  /// the SKU the rail's catalogue keys by the plan id.
  ///
  /// The one-team refusal is re-ASKED here rather than read off the mount-time
  /// answer, because this is the point where the money moves: a tap can arrive
  /// long after the screen loaded, and the deep-link path
  /// ([_startRequestedUpgrade]) can arrive before that read resolved at all. One
  /// extra request on a tap is cheaper than a transfer nobody asked for. It names
  /// the team, for the same reason the notice above the grid does.
  ///
  /// `false` from the rail is the ordinary outcome of a customer closing the
  /// sheet, so it reports nothing at all: an "it did not work" toast for a
  /// deliberate dismissal would be this screen inventing a failure. `true` is the
  /// STORE's word and not the producer's, which is why the confirmation says the
  /// plan updates when the store confirms it and the entitlement is re-read
  /// rather than assumed: the rail's webhook is the authority and it may not have
  /// arrived yet.
  Future<void> _purchaseInStore(MagicStarterPlan plan) async {
    final StoreBillingService? store = controller.storeRail;
    if (store == null) return;

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

    try {
      final bool bought = await store.purchase(plan: plan.id);
      if (!bought || !mounted) return;

      Magic.success(
        trans('magic_starter.billing.store_purchase_title'),
        trans('magic_starter.billing.store_purchase_text'),
      );
      await controller.loadEntitlement();
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
    if (plan.monthly == null) {
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
    // that does not exist.
    for (final MagicStarterPlan plan in plans) {
      final int? direction = _direction(plan);

      if (direction != null && direction > 0 && plan.monthly != null) {
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

  /// The big price label for [plan] at [cycle], or the "Custom" label when the
  /// plan carries no numeric price.
  ///
  /// Rendered through the consumer's own [MagicStarterBillingController
  /// .formatNumber], which is the third of this screen's three call sites: a
  /// thousands separator is a comma in one language and a full stop in another,
  /// and a package that picked one would re-ship a defect this ecosystem has
  /// already shipped and fixed.
  ///
  /// The symbol follows [MagicStarterPlan.currency]'s own contract: `usd` renders
  /// as a symbol and anything else keeps its raw wire code, because a currency
  /// formatting table is not something this package owns.
  String _priceLabel(MagicStarterPlan plan, BillingCycle cycle) {
    final int? price = cycle == BillingCycle.annual
        ? plan.annual
        : plan.monthly;
    if (price == null) {
      return trans('magic_starter.billing.plan_price_custom');
    }

    final String amount = controller.formatNumber(price);

    return plan.currency.toLowerCase() == _usdCurrency
        ? '\$$amount'
        : '${plan.currency} $amount';
  }

  /// The under-price billing note for [plan] at the selected cycle.
  String _billingNote(MagicStarterPlan plan) {
    if (plan.monthly == null) {
      return trans('magic_starter.billing.plan_billing_custom');
    }
    // Gated on the store RAIL and not on the price being suppressed: a store
    // catalogue carries the monthly SKUs only, so an annual note on a store build
    // would describe a cadence nothing there sells, including on the free tier
    // whose price is not suppressed.
    if (controller.storeRail == null &&
        _cycleFor(plan) == BillingCycle.annual) {
      return trans('magic_starter.billing.plan_billing_annual');
    }
    if (plan.monthly == 0) {
      return trans('magic_starter.billing.plan_billing_free');
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
