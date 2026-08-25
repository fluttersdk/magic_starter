// The billing screen's behaviour, ported from the suite that was written
// against the real screen in its original home.
//
// This file arrived BEFORE the view it exercises. That order is the point: the
// behaviour below is already specified by a suite somebody wrote against a
// running product, and re-deriving those expectations from the ported code
// would certify whatever the port happened to do, mistakes included. Until the
// view is registered under `teams.billing`, every case here fails at the
// registry lookup in `mount`, which is a RUNTIME failure and not a compile
// error: the harness is right and the subject is missing.
//
// Five things the source suite reached for do not exist on this side of the
// package boundary, and each has a named replacement rather than a deleted
// case:
//
// 1. The consumer's plan fixtures become [_planWireRows], the real catalogue
//    rows copied out of a shipping backend and fed through `getPlans()`
//    verbatim (the contract answers rows undecoded). A hand-written minimal map
//    would agree with a decoder that dropped a field.
// 2. The consumer's `User` model and its service provider become container
//    state set up in `setUp`, and the ownership answer becomes the controller's
//    own `isOwnerReader` seam.
// 3. The consumer's shipped `assets/lang/*.json` become the package's OWN
//    shipped catalogue, `assets/stubs/install/en.stub`, read off disk by
//    [_shippedCatalogue] and served through a [TranslationLoader]. An assertion
//    on rendered copy is therefore an assertion about the product rather than
//    about a literal typed here.
// 4. The consumer's second locale has no package equivalent (this package ships
//    English only, on purpose). The two-locale cases below run against
//    [_secondLocaleCatalogue], test-only copy that no English literal in the
//    view could produce, so "the screen reads the active catalogue" stays
//    falsifiable even though "the shipped Turkish is real" now belongs to the
//    consumer's own suite.
// 5. Everything the original held in `State` now lives in
//    [MagicStarterBillingController], so a case that used to reach into private
//    widget state drives a collaborator instead.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';
import 'package:magic_starter/magic_starter.dart';

// ---------------------------------------------------------------------------
// The shipped catalogue
// ---------------------------------------------------------------------------

/// The package's own shipped English copy, flattened to the dotted keys
/// `trans()` looks up.
///
/// Read off disk rather than inlined, for the reason the source suite read the
/// consumer's shipped JSON: an assertion against a literal typed in a test file
/// is an assertion about the test author, and this repository has shipped both
/// an ungrammatical sentence and a raw i18n key past a green suite. The same
/// file is already read this way by the publish command's own test.
///
/// Flattening mirrors `JsonAssetLoader._flatten`, which is what the running app
/// applies to the very same JSON once the installer has copied it into place.
Map<String, dynamic> _shippedCatalogue() {
  final File stub = File(
    '${Directory.current.path}/assets/stubs/install/en.stub',
  );
  final Map<String, dynamic> json =
      jsonDecode(stub.readAsStringSync()) as Map<String, dynamic>;

  return _flatten(json);
}

/// Flattens nested catalogue objects into dotted keys.
Map<String, dynamic> _flatten(Map<String, dynamic> json, [String prefix = '']) {
  final Map<String, dynamic> result = <String, dynamic>{};

  for (final MapEntry<String, dynamic> entry in json.entries) {
    final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    final Object? value = entry.value;

    if (value is Map<String, dynamic>) {
      result.addAll(_flatten(value, key));
    } else {
      result[key] = value;
    }
  }

  return result;
}

/// The CONSUMER's own copy, which this package deliberately does not ship.
///
/// The usage wire carries numbers and no words, so a resource's display name
/// comes from the app that meters it. These keys stand in for the consumer's
/// catalogue and are paired onto the stats by [_usageCopy], exactly as a real
/// adopter's helper does.
const Map<String, String> _consumerCatalogue = <String, String>{
  'test_app.usage.monitors': 'Monitors',
  'test_app.usage.checks_this_month': 'Checks this month',
  'test_app.usage.unit_checks': 'checks',
};

/// A SECOND locale, for the cases whose subject is that rendered copy follows
/// the active catalogue rather than a literal in the widget tree.
///
/// Test fixture data, not shipped copy: this package ships one catalogue and
/// step 6 forbids a second. Only the keys the two-locale cases render are
/// overridden, over the shipped English, so a key nobody translated still
/// resolves. The values are deliberately non-ASCII and sentence-shaped, because
/// the defects these cases guard (a hardcoded English literal, a clipped
/// sentence, a raw key on screen) all hid behind English by construction.
const Map<String, String> _secondLocaleCatalogue = <String, String>{
  'magic_starter.billing.manage_app_store_text':
      'Aboneliğinizi App Store üzerinden aldınız, bu yüzden Apple yönetiyor.',
  'magic_starter.billing.invoice_status.paid': 'Ödendi',
  'magic_starter.billing.payment_expires': 'Son kullanma :date',
  'magic_starter.billing.plan_unavailable_text':
      ':id planı, ayrıntılar kullanılamıyor',
  'magic_starter.billing.plan_button_unranked': 'Planı değiştir',
  'test_app.usage.monitors': 'İzleyiciler',
  'test_app.usage.checks_this_month': 'Bu ayki kontroller',
  'test_app.usage.unit_checks': 'kontrol',
};

/// Feeds one catalogue into the translator, whatever locale it asks for.
///
/// The locale argument is ignored on purpose: which catalogue a session gets is
/// the subject of two cases below, so the test drives it directly rather than
/// through a resolution this package does not own.
class _CatalogueLoader implements TranslationLoader {
  const _CatalogueLoader([this.overrides = const <String, String>{}]);

  /// Copy layered over the shipped English, for a non-English session.
  final Map<String, String> overrides;

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    return <String, dynamic>{
      ..._shippedCatalogue(),
      ..._consumerCatalogue,
      ...overrides,
    };
  }
}

// ---------------------------------------------------------------------------
// The consumer's collaborators
// ---------------------------------------------------------------------------

/// The consumer's number format, which this package requires and never
/// supplies.
///
/// Plain digits, because the ported scenarios assert on rendered prices and
/// usage readouts and a sentinel would have to be threaded through every
/// expectation. The separator behaviour itself is the consumer's to test; what
/// matters here is that the screen renders through THIS function rather than
/// through a hardcoded one.
String _formatNumber(int value) => value.toString();

/// The consumer's usage copy, paired on by [UsageStat.key].
///
/// Modelled on a real adopter's helper: every stat the producer reported comes
/// back, in the order it sent them, and one this table has no word for keeps a
/// NULL label rather than falling back to its wire key. A meter labelled
/// `widgets_provisioned` is a raw key on a customer's screen.
List<UsageStat> _usageCopy(List<UsageStat> stats) {
  final Map<String, ({String label, String unit})> copy =
      <String, ({String label, String unit})>{
        'monitors': (label: trans('test_app.usage.monitors'), unit: ''),
        'checks_this_month': (
          label: trans('test_app.usage.checks_this_month'),
          unit: trans('test_app.usage.unit_checks'),
        ),
      };

  return stats.map((UsageStat stat) {
    final ({String label, String unit})? words = copy[stat.key];
    if (words == null) return stat;

    return UsageStat(
      key: stat.key,
      used: stat.used,
      limit: stat.limit,
      label: words.label,
      unit: words.unit,
    );
  }).toList();
}

// ---------------------------------------------------------------------------
// The plan catalogue fixture
// ---------------------------------------------------------------------------

/// The FOUR real catalogue rows a shipping backend serves, verbatim.
///
/// Real rows rather than a minimal hand-written map, because `getPlans()`
/// answers rows undecoded and a fixture invented here would agree with whatever
/// the decoder happens to read. `limits.regions` is a `count()` call in the PHP
/// source and is inlined at its resolved value, the same way the model's own
/// test inlines it.
///
/// The order is load-bearing in three separate ways: it is cheapest-first, so
/// the Upgrade/Downgrade direction is decided by position; `pro` has both a
/// cheaper and a pricier neighbour, so one fixture resolves an Upgrade, a
/// Downgrade and a Current-plan CTA at once; and exactly one tier is custom
/// (`monthly: null`), which is the tier that keeps its sales handoff through
/// every gate below.
const List<Map<String, dynamic>> _planWireRows = <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 'free',
    'name': 'Free',
    'tagline': 'Kick the tires, solo projects.',
    'monthly': 0,
    'annual': 0,
    'currency': 'usd',
    'ai_line': 'AI anomaly inbox, plus 3 free AI monitor setups.',
    'features': <String>[
      '1 monitor · 3-minute checks · 1 region',
      '1 status page · 100 subscribers',
      '1 responder · Slack, Teams, PagerDuty & webhook alerts',
      'TLS expiry alerts · response-metric bounds',
      '3 AI monitor setups, then Pro',
    ],
    'responder_add_on': null,
    'recommended': false,
    'limits': <String, dynamic>{
      'monitors': 1,
      'check_interval_sec': 180,
      'status_pages': 1,
      'subscribers': 100,
      'responders': 1,
      'regions': 1,
      'ai': 'inbox',
      'ai_analysis_trials': 3,
      'white_label': false,
      'private_pages': false,
      'sso': false,
    },
  },
  <String, dynamic>{
    'id': 'pro',
    'name': 'Pro',
    'tagline': 'Startups and small teams that page.',
    'monthly': 34,
    'annual': 29,
    'currency': 'usd',
    'ai_line':
        'Full AI incident analysis: evidence, confidence, citations, '
        'drafted updates.',
    'features': <String>[
      '50 monitors · 30-second checks',
      '3 status pages · 1,000 subscribers',
      '3 responders · on-call schedules & escalation policies',
      'SLO targets & error budgets',
    ],
    'responder_add_on': r'+$9/mo per extra responder',
    'recommended': true,
    'limits': <String, dynamic>{
      'monitors': 50,
      'check_interval_sec': 30,
      'status_pages': 3,
      'subscribers': 1000,
      'responders': 3,
      'regions': 5,
      'ai': 'analysis',
      'white_label': false,
      'private_pages': false,
      'sso': false,
    },
  },
  <String, dynamic>{
    'id': 'business',
    'name': 'Business',
    'tagline': 'Scaling teams, on the fastest checks we run.',
    'monthly': 119,
    'annual': 99,
    'currency': 'usd',
    'ai_line': 'AI Auto mode plus the weekly written digest.',
    'features': <String>[
      '200 monitors · 10-second checks',
      '10 status pages · 10,000 subscribers · private pages',
      '10 responders',
      'AI Auto mode & weekly digest',
    ],
    'responder_add_on': r'+$9/mo per extra responder',
    'recommended': false,
    'limits': <String, dynamic>{
      'monitors': 200,
      'check_interval_sec': 10,
      'status_pages': 10,
      'subscribers': 10000,
      'responders': 10,
      'regions': 5,
      'ai': 'auto',
      'white_label': true,
      'private_pages': true,
      'sso': true,
    },
  },
  <String, dynamic>{
    'id': 'enterprise',
    'name': 'Enterprise',
    'tagline': 'Custom scale, security and support.',
    'monthly': null,
    'annual': null,
    'currency': 'usd',
    'ai_line': 'AI with custom guardrails & dedicated capacity.',
    'features': <String>[
      'Unlimited monitors · 5-second checks',
      'Unlimited status pages & subscribers',
      'Unlimited responders',
      'Invoicing and custom terms',
    ],
    'responder_add_on': null,
    'recommended': false,
    'limits': <String, dynamic>{
      'monitors': null,
      'check_interval_sec': 5,
      'status_pages': null,
      'subscribers': null,
      'responders': null,
      'regions': 5,
      'ai': 'custom',
      'white_label': true,
      'private_pages': true,
      'sso': true,
    },
  },
];

// ---------------------------------------------------------------------------
// The rail fakes
// ---------------------------------------------------------------------------

/// The five entitlement READS, with a configurable rail and no purchase rail at
/// all: the base every fake below extends.
///
/// It is split from the two rail fakes because which rails a fake serves is the
/// subject of half this file. The controller resolves the web rail and the
/// store rail from the INJECTED object's own type, so a single fake
/// implementing both would model a build that cannot exist (`dart.library.io`
/// has no web checkout and the web arm has no store) and would let a store-rail
/// test pass on a web affordance.
///
/// The rail arrives as its RAW WIRE WORD (`app_store`, not `ManageVia`
/// .appStore), because that is the only thing the real decoder ever sees; a
/// fake taking an already-decoded case could pass while
/// `ManageVia.fromWire('play_store')` silently fell into its fallback. The
/// entitlement is therefore built through [BillingEntitlement.fromMap] rather
/// than through the const constructor, which takes cases already decoded.
class _ReadsBillingService implements BillingService {
  _ReadsBillingService({
    this.manageVia = 'none',
    this.manageUrl,
    this.invoices = const <Invoice>[],
    this.usage = const <UsageStat>[],
  });

  /// The wire word for `manage_via`.
  final String manageVia;

  /// The wire value for `manage_url`; `null` models a store rail whose
  /// management destination has not arrived.
  final String? manageUrl;

  /// The wire value for `plan`, fixed rather than injectable: every assertion
  /// in this file is about the rail or the membership, and the tier only has to
  /// be a real catalogue id (one with a cheaper and a pricier neighbour) so the
  /// grid resolves an Upgrade, a Downgrade and a Current-plan CTA.
  ///
  /// A getter rather than a field, so [_HeldRetiredTierBillingService] can
  /// override it without the `overridden_fields` lint a second `final` field
  /// would trigger.
  String get entitlementPlan => 'pro';

  /// The billing history the invoices read resolves to.
  final List<Invoice> invoices;

  /// The metered usage the usage read resolves to, LABEL-FREE, exactly as the
  /// package decodes it: pairing the display copy on is the consumer's job, and
  /// a fixture that pre-labelled these would assert its own words instead.
  final List<UsageStat> usage;

  @override
  Future<BillingEntitlement> currentEntitlement() async {
    return BillingEntitlement.fromMap(<String, dynamic>{
      'plan': entitlementPlan,
      'plan_status': 'active',
      'subscribed': true,
      'renews': true,
      'cycle': 'annual',
      'provider': 'stripe',
      'manage_via': manageVia,
      'manage_url': manageUrl,
      'ai_analysis_trials_remaining': null,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPlans() async => _planWireRows;

  @override
  Future<List<UsageStat>> getUsage() async => usage;

  @override
  Future<BillingInvoicesPage> getInvoices({String? cursor}) async {
    return BillingInvoicesPage(invoices: invoices, nextCursor: null);
  }

  /// The card and the renewal date as the RAIL reports them: two numbers for
  /// the expiry and an instant for the renewal, not `'08 / 27'` and
  /// `'Jun 1, 2026'`. Formatting both is the screen's job, so a fixture that
  /// handed over finished strings would be asserting the fixture's own
  /// formatting rather than the product's.
  @override
  Future<PaymentMethod> getPaymentMethod() async {
    return PaymentMethod(
      brand: 'Visa',
      last4: '4242',
      expMonth: 8,
      expYear: 2027,
      renewalDate: DateTime.utc(2026, 6, 1),
      available: true,
    );
  }
}

/// A tier with no rail behind it: every read answers, and every answer is
/// "nothing".
///
/// The two payloads below are copied off the live billing endpoints on a dev
/// box, for a team holding a paid tier with no billing provider (a tier granted
/// directly rather than sold). They are not invented: a live walk is what
/// produced them.
///
/// [_ReadsBillingService] cannot model this state, and that is why it went
/// unnoticed. Its payment-method read pins a Visa ending 4242 with a real
/// renewal instant, so every other test in this file reaches the renewal
/// sentence through a date that EXISTS, and the branch taken when the read
/// resolves EMPTY had no fixture pointing at it. A fixture that pins one value
/// makes the other branch unreachable, and an unreachable branch is not covered
/// by however many tests pass.
class _UnbilledBillingService extends _ReadsBillingService {
  @override
  Future<BillingEntitlement> currentEntitlement() async {
    return BillingEntitlement.fromMap(<String, dynamic>{
      'plan': 'business',
      'plan_status': 'none',
      'subscribed': false,
      'renews': null,
      'cycle': null,
      'provider': 'none',
      'manage_via': 'none',
      'manage_url': null,
      'current_period_end': null,
      'ai_analysis_trials_remaining': null,
    });
  }

  /// Resolved, and carrying nothing. Distinct from the fetch never having
  /// answered: the controller keeps `paymentMethod` null for that, and the
  /// neutral pending label is correct there.
  ///
  /// `available: true` is the producer saying the rail WAS reachable and there
  /// is genuinely no card, which is the honest half of the empty payload.
  @override
  Future<PaymentMethod> getPaymentMethod() async =>
      const PaymentMethod(available: true);
}

/// A subscription the customer has CANCELLED, still granting until its period
/// ends.
///
/// Everything except `renews` matches the renewing fixture on purpose: the plan
/// is live, the rail is Stripe, the portal is reachable and the date is the same
/// instant. That is what makes the one changed field the whole test. The rail
/// really does report it this way, because an end-of-period cancellation leaves
/// a customer entitled and the date attached to them stops being a renewal.
class _CancelledBillingService extends _ReadsBillingService {
  @override
  Future<BillingEntitlement> currentEntitlement() async {
    return BillingEntitlement.fromMap(<String, dynamic>{
      'plan': entitlementPlan,
      'plan_status': 'active',
      'subscribed': true,
      'renews': false,
      'cycle': 'annual',
      'provider': 'stripe',
      'manage_via': manageVia,
      'manage_url': manageUrl,
      'ai_analysis_trials_remaining': null,
    });
  }
}

/// A PAYING customer whose payment-method read soft-failed.
///
/// `manage_via` is `portal`, which the server sends exactly when a billing
/// customer exists, and the payment method resolves EMPTY. That pair is not
/// exotic: the producer catches every Throwable from its live rail reads and
/// answers 200 with all five fields null, which is byte-identical to the body a
/// team with no rail receives. So a timeout at the rail puts a real subscriber
/// into exactly this state.
///
/// It exists because the first version of the "no rail behind this tier" copy
/// keyed on the empty read alone and told this customer they had no
/// subscription and no card.
///
/// `available: false` is the producer's own answer to which of the two empties
/// this is, and it is the field the port must branch on rather than
/// reconstructing the answer from `manage_via`.
class _SoftFailedPaymentBillingService extends _ReadsBillingService {
  _SoftFailedPaymentBillingService() : super(manageVia: 'portal');

  @override
  Future<PaymentMethod> getPaymentMethod() async =>
      const PaymentMethod(available: false);
}

/// The payment-method read answers EMPTY while the entitlement read never does.
///
/// Both are dispatched together on mount, and for a customer-less team the
/// payment-method one is the cheaper, so this ordering is ordinary rather than
/// contrived. A failing entitlement read makes it permanent.
///
/// In that window neither sentence is available: "no card on file" needs to
/// know there is no rail, and "the read failed" needs to know one failed. The
/// payload carries no `available` either, which is what an adopter on an older
/// producer sends and is the third of the three states the port may not
/// collapse.
class _UnresolvedRailBillingService extends _ReadsBillingService {
  @override
  Future<BillingEntitlement> currentEntitlement() async {
    throw const BillingException('Failed to load the billing entitlement.');
  }

  @override
  Future<PaymentMethod> getPaymentMethod() async => const PaymentMethod();
}

/// A payment-method read that RESOLVED and carried no card, with the producer's
/// own [PaymentMethod.available] answer under the test's control.
///
/// The three sibling fixtures above each pin ONE of the three states, which is
/// what makes each of their scenarios readable and what makes the fourth
/// question, "do the states actually render differently", impossible to ask
/// from any one of them. This one varies the single axis so the bodies can be
/// compared side by side.
class _EmptyCardBillingService extends _ReadsBillingService {
  _EmptyCardBillingService({this.available, super.manageVia = 'none'});

  /// The producer's answer to whether its rail could be asked at all.
  final bool? available;

  @override
  Future<PaymentMethod> getPaymentMethod() async =>
      PaymentMethod(available: available);
}

/// A payment-method read that never ARRIVED.
///
/// Distinct from every `available` state above, and not expressible by any of
/// them: `available` is the producer's answer about its rail, and this is the
/// response failing to reach the client at all, which no server flag can carry
/// because no server flag was received. It is what keeps the controller's own
/// `pmError` load-bearing.
class _TransportFailedPaymentBillingService extends _ReadsBillingService {
  @override
  Future<PaymentMethod> getPaymentMethod() async {
    throw const BillingException('Failed to load the payment method.');
  }
}

/// The catalogue with its CUSTOM tier renamed to something no English literal
/// in the view could produce.
///
/// The sales-handoff toast interpolates the tier's name, and in a catalogue
/// whose top tier is called "Enterprise" a hardcoded "Enterprise" passes by
/// construction. This renames it, so the assertion can only pass if the name
/// travelled from the catalogue row.
class _RenamedCustomTierBillingService extends _RailBillingService {
  @override
  Future<List<Map<String, dynamic>>> getPlans() async {
    return _planWireRows.map((Map<String, dynamic> row) {
      if (row['id'] != 'enterprise') return row;

      return <String, dynamic>{...row, 'name': 'Kurumsal Ölçek'};
    }).toList();
  }
}

/// The same catalogue with `business` sold MONTHLY ONLY.
///
/// A priced tier with no annual price is a row this screen already expects
/// elsewhere (`_priceLabel` renders the custom label for it, `_billingNote`
/// guards on it), and it is what a vendor has the day they add a tier and have
/// not created its annual price in Stripe yet. It is built by rewriting one
/// field of the shipping catalogue rather than by hand, so every other field
/// stays the one the producer sends and the test cannot pass because the row was
/// simplified.
class _MonthlyOnlyTierBillingService extends _RailBillingService {
  @override
  Future<List<Map<String, dynamic>>> getPlans() async {
    return _planWireRows.map((Map<String, dynamic> row) {
      if (row['id'] != 'business') return row;

      return <String, dynamic>{...row, 'annual': null};
    }).toList();
  }
}

/// A paying customer whose CYCLE nothing reported.
///
/// The producer answers null for a store subscription and for a Stripe price the
/// adopter mapped without declaring its cycle, so this is a real state and not a
/// contrived one. Everything else about the subscription is present, which is
/// what makes it a test of the sentence rather than of the loading path.
class _CyclelessBillingService extends _RailBillingService {
  @override
  Future<BillingEntitlement> currentEntitlement() async {
    return BillingEntitlement.fromMap(<String, dynamic>{
      'plan': entitlementPlan,
      'plan_status': 'active',
      'subscribed': true,
      'renews': true,
      'cycle': null,
      'provider': 'stripe',
      'manage_via': 'none',
      'manage_url': null,
      'ai_analysis_trials_remaining': null,
    });
  }
}

/// A customer billed MONTHLY, on the same web rail.
///
/// One field apart from [_RailBillingService], which is what makes the
/// toggle-default test a real one: everything else about the two is identical,
/// so the cycle the screen opens on is the only thing that can explain a
/// different charge.
class _MonthlyBillingService extends _RailBillingService {
  @override
  Future<BillingEntitlement> currentEntitlement() async {
    return BillingEntitlement.fromMap(<String, dynamic>{
      'plan': entitlementPlan,
      'plan_status': 'active',
      'subscribed': true,
      'renews': true,
      'cycle': 'monthly',
      'provider': 'stripe',
      'manage_via': 'none',
      'manage_url': null,
      'ai_analysis_trials_remaining': null,
    });
  }
}

/// The reads PLUS the WEB rail, recording every purchase-affecting call so a
/// test can assert an affordance was not merely hidden but never reachable.
///
/// `checkout` and `openPortal` live on [WebBillingService] rather than on the
/// read contract, and the screen renders no purchase or portal affordance at
/// all when that rail is absent, so a read-only fake would have made every "the
/// affordance is gone" assertion below pass for the wrong reason.
class _RailBillingService extends _ReadsBillingService
    implements WebBillingService {
  _RailBillingService({
    super.manageVia = 'none',
    super.manageUrl,
    super.invoices = const <Invoice>[],
    super.usage = const <UsageStat>[],
    this.checkoutError,
  });

  /// Every `plan` passed to [checkout], in call order.
  final List<String> checkoutPlans = <String>[];

  /// A rail failure to raise instead of answering, so [checkout]'s error
  /// paths (a generic [BillingException] and its [UnsupportedPlatformException]
  /// subtype) are reachable without a real rail.
  final BillingException? checkoutError;

  /// Every cycle [checkout] was called with, so a test can assert the customer
  /// is charged on the cycle whose figure they were shown.
  final List<BillingCycle> checkoutCycles = <BillingCycle>[];

  /// Every (plan, cycle) pair [swap] was called with.
  final List<(String, BillingCycle)> swappedTo = <(String, BillingCycle)>[];

  /// How many times [openPortal] was called.
  int portalCalls = 0;

  @override
  Future<BillingCheckoutSession> checkout({
    required String plan,
    required BillingCycle cycle,
    required String successUrl,
    required String cancelUrl,
  }) async {
    checkoutPlans.add(plan);
    checkoutCycles.add(cycle);
    final BillingException? error = checkoutError;
    if (error != null) throw error;

    return const BillingCheckoutSession(
      checkoutUrl: 'https://checkout.example.test/test_session',
      sessionId: 'session_test',
    );
  }

  @override
  Future<void> swap({required String plan, required BillingCycle cycle}) async {
    swappedTo.add((plan, cycle));
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<String> openPortal({String? returnUrl}) async {
    portalCalls++;

    return 'https://portal.example.test/session/test';
  }
}

/// A team grandfathered on a tier the current catalogue no longer serves.
///
/// [_ReadsBillingService.entitlementPlan] is fixed to `'pro'`, a real catalogue
/// id, because every other test in this file needs a tier with both a cheaper
/// and a pricier neighbour so the grid resolves an Upgrade AND a Downgrade CTA.
/// This fixture overrides just that one field with an id [_planWireRows] never
/// carries, modelling a customer whose tier the backend retired: the plan
/// lookup must answer absence rather than the catalogue's cheapest entry.
///
/// Extends [_RailBillingService] (a WEB rail) rather than the bare reads,
/// because a build with no rail at all renders no CTA on a priced tier
/// regardless of direction, which would make the neutral-label assertion below
/// pass for the wrong reason.
class _HeldRetiredTierBillingService extends _RailBillingService {
  @override
  String get entitlementPlan => 'legacy_grandfathered';
}

/// The reads PLUS the STORE rail, recording every call the store rail can
/// receive.
///
/// It deliberately does NOT implement [WebBillingService]: a build with a store
/// has no web checkout, so a fake serving both would let a store test pass on
/// the web CTA and would make "a store build never offers web checkout"
/// unfalsifiable.
class _StoreRailBillingService extends _ReadsBillingService
    implements StoreBillingService {
  _StoreRailBillingService({
    super.manageVia = 'none',
    this.purchaseResult = true,
    this.purchaseError,
    this.restoreResult = true,
  });

  /// What the store reports for a completed sheet: `true` is a transaction,
  /// `false` is the customer dismissing it (which is not a failure).
  final bool purchaseResult;

  /// A rail failure to raise instead of answering, so the error paths are
  /// reachable without the platform channel.
  final BillingException? purchaseError;

  /// Whether the store hands a previous purchase back to [restore].
  final bool restoreResult;

  /// Every `appUserId` passed to [identify], in call order.
  final List<String> identifiedIds = <String>[];

  /// Every `plan` passed to [purchase], in call order.
  final List<String> purchasedPlans = <String>[];

  /// How many times [restore] was called.
  int restoreCalls = 0;

  @override
  Future<void> identify(String appUserId) async {
    identifiedIds.add(appUserId);
  }

  @override
  Future<bool> purchase({required String plan}) async {
    purchasedPlans.add(plan);
    final BillingException? error = purchaseError;
    if (error != null) throw error;

    return purchaseResult;
  }

  @override
  Future<bool> restore() async {
    restoreCalls++;

    return restoreResult;
  }

  @override
  Future<void> openStoreManagement() async {}
}

void main() {
  /// The one invoice the billing-history assertions need, so the receipt
  /// affordance has a row to live on.
  ///
  /// `final`, not `const`: the date is an instant (month names and date order
  /// are display copy the screen owns), and a [DateTime] can never be a
  /// constant.
  final Invoice invoice = Invoice(
    id: 'in_test_1',
    number: 'INV-0001',
    date: DateTime.utc(2026, 6, 1),
    amount: r'$29.00',
    status: InvoiceStatus.paid,
  );

  /// The origin the consumer configures for the checkout redirects and the
  /// portal return.
  ///
  /// It has to be SET for the purchase CTA to render at all (the config carries
  /// no default, deliberately: an unset origin yields a relative url the rail
  /// refuses), and it is the string the store cases assert never reaches the
  /// screen.
  const String webOrigin = 'https://billing.example.test';

  setUp(() async {
    MagicApp.reset();
    Magic.flush();

    // Card / Button / Badge / PageHeader resolve their themes through
    // MagicStarter.*, and MagicFeedback falls through to a warning log with no
    // mounted navigator, so both bindings are needed without a full app boot.
    Magic.singleton('log', () => LogManager());
    Config.set('logging', <String, dynamic>{
      'default': 'console',
      'channels': <String, dynamic>{
        'console': <String, dynamic>{'driver': 'console', 'level': 'debug'},
      },
    });

    // The feature flag decides whether the view is registered at all, and the
    // manager registers its defaults in its constructor, so it is set before
    // the singleton is ever resolved.
    Config.set('magic_starter.features.billing', true);
    Config.set('magic_starter.billing.web_origin', webOrigin);
    Magic.singleton('magic_starter', () => MagicStarterManager());

    // Every sibling view in the manager is gated on its feature flag alone.
    // Should the billing registration also carry an ability, this permissive
    // definition keeps the harness from refusing the view for a reason no
    // scenario here is about.
    Gate.flush();
    Gate.define('starter.manage-billing', (user, [_]) => true);

    Http.fake();

    Translator.instance.setLoader(const _CatalogueLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    Gate.flush();
    MagicApp.reset();
    Magic.flush();
  });

  /// Wraps [widget] with a default [WindTheme] under a viewport tall enough for
  /// the whole screen.
  ///
  /// A BARE [WindThemeData], with no consumer supplement: every token the
  /// package's own components reference has to resolve without one, because
  /// Wind drops an unknown token silently and a shared component referencing a
  /// consumer's token renders nothing at all in every app that has not
  /// hand-authored it.
  ///
  /// No scroll view of its own, unlike the source harness: the page scaffold
  /// owns one, and nesting a second unbounded vertical scroll would fail the
  /// layout for a reason no case here is about.
  Widget wrap(Widget widget) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1280, 12000)),
        child: WindTheme(
          data: WindThemeData(),
          child: Scaffold(body: widget),
        ),
      ),
    );
  }

  /// Wraps [widget] so a [MagicFeedback] toast can actually render.
  ///
  /// [WindTheme] sits ABOVE the [MaterialApp] because the toast is inserted
  /// into the Navigator's overlay, which is a sibling of `home`: a Wind-built
  /// toast under `home` throws "No WindTheme found in context". Without it
  /// `MagicFeedback` degrades to a warning log and an assertion on the reported
  /// copy passes for nobody.
  Widget wrapWithSnackbar(Widget widget) {
    return WindTheme(
      data: WindThemeData(),
      child: MaterialApp(
        navigatorKey: MagicRouter.instance.navigatorKey,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 12000)),
          child: Scaffold(body: widget),
        ),
      ),
    );
  }

  /// Registers the controller the view resolves, mounts the view THROUGH THE
  /// REGISTRY, and settles the mount-time reads.
  ///
  /// Through the registry rather than by constructing the widget, and that is
  /// the half a consumer actually depends on: the screen is reached by key, so
  /// a view that exists but is not registered is a screen nobody can open.
  ///
  /// [isOwner] mirrors the source's injectable membership: `null` is genuinely
  /// unresolved (no reader registered), which every gate reads permissively.
  ///
  /// [storeFundedTeam] defaults to a REGISTERED reader answering nothing, which
  /// is what the source's default stub answered. It is not the same as leaving
  /// it out: an unregistered check refuses the store purchase outright, because
  /// nothing in that build can promise a second purchase will not transfer
  /// another team's subscription away.
  Future<void> mount(
    WidgetTester tester,
    BillingService billing, {
    bool? isOwner,
    MagicStarterStoreFundedTeamReader? storeFundedTeam,
    bool withToasts = false,
  }) async {
    Magic.put(
      MagicStarterBillingController(
        usageCopy: _usageCopy,
        formatNumber: _formatNumber,
        isOwnerReader: isOwner == null ? null : () => isOwner,
        storeFundedTeamReader: storeFundedTeam ?? () async => null,
        billingService: billing,
      ),
    );

    await tester.binding.setSurfaceSize(const Size(1280, 12000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final Widget view = MagicStarter.view.make('teams.billing');

    await tester.pumpWidget(withToasts ? wrapWithSnackbar(view) : wrap(view));
    await tester.pump();
    await tester.pump();
  }

  /// Every string this build rendered, for the "nothing anywhere in the tree
  /// points at a web purchase" assertion. Reads the widget tree rather than a
  /// list of known labels: the point is to catch a URL nobody thought to look
  /// for, which a label-by-label check cannot do.
  List<String> renderedText(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((Text text) => text.data ?? '')
        .toList();
  }

  group('MagicStarterBillingView manage_via: portal', () {
    testWidgets('keeps the three portal affordances and the purchase '
        'CTA', (tester) async {
      final _RailBillingService billing = _RailBillingService(
        manageVia: 'portal',
        invoices: <Invoice>[invoice],
      );

      await mount(tester, billing);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.payment_update_button')),
        findsOneWidget,
        reason: 'the portal rail keeps the payment-method Update button',
      );
      expect(
        find.text(trans('magic_starter.billing.invoice_receipt_button')),
        findsOneWidget,
        reason: 'the portal rail keeps the invoice Receipt button',
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsOneWidget,
        reason: 'the portal rail can still buy a higher tier',
      );
      expect(
        find.text(trans('magic_starter.billing.manage_header')),
        findsNothing,
        reason: 'no store-managed statement on a rail we manage ourselves',
      );
    });
  });

  group('MagicStarterBillingView manage_via: app_store', () {
    testWidgets('renders the App Store statement with its passed-through link, '
        'and no web billing affordance anywhere', (tester) async {
      final _RailBillingService billing = _RailBillingService(
        manageVia: 'app_store',
        manageUrl: 'https://apps.apple.com/account/subscriptions',
        invoices: <Invoice>[invoice],
      );

      await mount(tester, billing);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.manage_app_store_text')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.billing.manage_store_button')),
        findsOneWidget,
        reason: 'a non-null manage_url gets a tappable affordance',
      );
      expect(
        find.text(trans('magic_starter.billing.manage_play_store_text')),
        findsNothing,
      );

      // The three portal affordances are gone, and so is the purchase CTA: a
      // second rail must not be able to start charging this team.
      expect(
        find.text(trans('magic_starter.billing.payment_update_button')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.invoice_receipt_button')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_downgrade')),
        findsNothing,
      );
      expect(billing.portalCalls, 0);
      expect(billing.checkoutPlans, isEmpty);

      // Nothing rendered points at a web purchase or the hosted portal
      // (Apple's 3.1.3 steering rule), and the custom tier's contact-sales CTA
      // still comes off the plan GRID rather than off the rail.
      for (final String text in renderedText(tester)) {
        expect(
          text.toLowerCase(),
          allOf(
            isNot(contains('checkout')),
            isNot(contains('billing.example.test')),
          ),
          reason: 'a store-billed screen must not steer to a web purchase',
        );
      }
      expect(
        find.text(trans('magic_starter.billing.plan_button_contact')),
        findsOneWidget,
      );
    });

    testWidgets('renders the statement from the ACTIVE catalogue, not from an '
        'English literal', (tester) async {
      // English is the locale where a hardcoded literal passes by construction,
      // so the same sentence is read again from a second catalogue.
      Translator.instance.setLoader(
        const _CatalogueLoader(_secondLocaleCatalogue),
      );
      await Translator.instance.setLocale(const Locale('xx'));

      final String statement =
          _secondLocaleCatalogue['magic_starter.billing.manage_app_store_text']!;

      final _RailBillingService billing = _RailBillingService(
        manageVia: 'app_store',
        manageUrl: 'https://apps.apple.com/account/subscriptions',
      );

      await mount(tester, billing);

      expect(tester.takeException(), isNull);
      expect(find.text(statement), findsOneWidget);
      expect(
        find.textContaining('magic_starter.billing.'),
        findsNothing,
        reason: 'a raw i18n key must never reach the screen',
      );
    });
  });

  group('MagicStarterBillingView manage_via: play_store', () {
    testWidgets('a null manage_url states where the subscription lives and '
        'offers no tappable affordance', (tester) async {
      final _RailBillingService billing = _RailBillingService(
        manageVia: 'play_store',
        invoices: <Invoice>[invoice],
      );

      await mount(tester, billing);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.manage_play_store_text')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.billing.manage_store_no_url')),
        findsOneWidget,
        reason: 'the statement explains where to go instead of a dead button',
      );
      expect(
        find.text(trans('magic_starter.billing.manage_store_button')),
        findsNothing,
        reason: 'a null manage_url renders no button at all, disabled or not',
      );
      expect(
        find.text(trans('magic_starter.billing.payment_update_button')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.invoice_receipt_button')),
        findsNothing,
      );
    });
  });

  group('MagicStarterBillingView manage_via: none', () {
    testWidgets('renders the purchase surface and no dead portal button', (
      tester,
    ) async {
      final _RailBillingService billing = _RailBillingService(
        invoices: <Invoice>[invoice],
      );

      await mount(tester, billing);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsOneWidget,
        reason: 'manage_via none is where a team starts a subscription',
      );
      expect(
        find.text(trans('magic_starter.billing.manage_header')),
        findsNothing,
      );
      // The portal endpoint answers 409 for a team with no billing customer,
      // which is precisely the team the server reports as `none`. So the
      // affordance is absent rather than dead.
      expect(
        find.text(trans('magic_starter.billing.payment_update_button')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.invoice_receipt_button')),
        findsNothing,
      );
      expect(billing.portalCalls, 0);
    });
  });

  group('MagicStarterBillingView ownership', () {
    testWidgets('a non-owner gets no purchase CTA and an owner-can-upgrade '
        'message instead', (tester) async {
      final _RailBillingService billing = _RailBillingService(
        invoices: <Invoice>[invoice],
      );

      await mount(tester, billing, isOwner: false);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.owner_only_notice')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_downgrade')),
        findsNothing,
      );
      expect(billing.checkoutPlans, isEmpty);
      // A sales handoff is not a purchase, and it is driven by the plan GRID
      // rather than by the entitlement, so it survives the owner gate.
      expect(
        find.text(trans('magic_starter.billing.plan_button_contact')),
        findsOneWidget,
      );
    });

    testWidgets('a non-owner gets no portal affordance either, since the '
        'portal route is the owner\'s too', (tester) async {
      // The portal endpoint resolves its team through the same owner check as
      // the other write routes, so a member's Update and Receipt buttons are
      // 403s waiting to happen rather than actions.
      final _RailBillingService billing = _RailBillingService(
        manageVia: 'portal',
        invoices: <Invoice>[invoice],
      );

      await mount(tester, billing, isOwner: false);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.payment_update_button')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.invoice_receipt_button')),
        findsNothing,
      );
      expect(billing.portalCalls, 0);
    });

    testWidgets('the owner keeps the purchase CTA', (tester) async {
      final _RailBillingService billing = _RailBillingService();

      await mount(tester, billing, isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.billing.owner_only_notice')),
        findsNothing,
      );
    });
  });

  group('display copy the payments package does not carry', () {
    /// The usage wire the producer sends, decoded by the package and therefore
    /// label-free. Every label and unit below has to come from the CATALOGUE
    /// via the consumer's copy callback, which is the whole point.
    final List<UsageStat> usage = UsageStat.fromWireMap(<String, dynamic>{
      'monitors': <String, dynamic>{'used': 47, 'limit': 50},
      'checks_this_month': <String, dynamic>{'used': 128400, 'limit': null},
      // A resource this app has no word for. It must reach the gates (they look
      // a resource up by key) and must NOT reach the screen as a raw wire key.
      'widgets_provisioned': <String, dynamic>{'used': 3, 'limit': 9},
    });

    testWidgets('renders the date, the expiry, the usage label and the status '
        'pill from the instants and numbers the rail reported', (tester) async {
      final _RailBillingService billing = _RailBillingService(
        manageVia: 'portal',
        invoices: <Invoice>[invoice],
        usage: usage,
      );

      await mount(tester, billing);

      expect(tester.takeException(), isNull);

      // 1. A date. The invoice date and the renewal date are instants; both are
      //    rendered by the same formatter, so both the invoice row and the
      //    renewal sentence carry that exact string.
      expect(find.text('Jun 1, 2026'), findsOneWidget);
      expect(
        find.text(r'$29/mo billed annually · renews Jun 1, 2026'),
        findsOneWidget,
      );

      // 2. A card expiry, built from the rail's own exp_month / exp_year.
      expect(find.text('Expires 08 / 27'), findsOneWidget);

      // 3. A usage label and a unit, paired on by key from the catalogue. The
      //    unlabelled third resource renders no meter at all.
      expect(find.text('Monitors'), findsOneWidget);
      expect(find.text('Checks this month'), findsOneWidget);
      expect(find.textContaining('checks'), findsWidgets);
      expect(find.textContaining('widgets_provisioned'), findsNothing);

      // 4. An invoice-status pill, whose word now sits beside its tone.
      expect(find.text('Paid'), findsOneWidget);
    });

    testWidgets('the labels and the pill follow the ACTIVE catalogue, and the '
        'date shape is unchanged', (tester) async {
      // English is the locale where a hardcoded literal passes by
      // construction, so the same four strings are read again from a second
      // catalogue.
      Translator.instance.setLoader(
        const _CatalogueLoader(_secondLocaleCatalogue),
      );
      await Translator.instance.setLocale(const Locale('xx'));

      final _RailBillingService billing = _RailBillingService(
        manageVia: 'portal',
        invoices: <Invoice>[invoice],
        usage: usage,
      );

      await mount(tester, billing);

      expect(tester.takeException(), isNull);
      expect(find.text('İzleyiciler'), findsOneWidget);
      expect(find.text('Bu ayki kontroller'), findsOneWidget);
      expect(find.text('Ödendi'), findsOneWidget);
      expect(find.text('Son kullanma 08 / 27'), findsOneWidget);
      // The date table itself is English-only by decision (it always was), so
      // this locks the shape rather than claiming a translation.
      expect(find.text('Jun 1, 2026'), findsOneWidget);
    });
  });

  group('MagicStarterBillingView web checkout', () {
    testWidgets('tapping the Upgrade CTA starts a checkout for the tapped '
        'plan', (tester) async {
      final _RailBillingService billing = _RailBillingService();

      await mount(tester, billing, isOwner: true);

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // 'business' sits above the fixture's 'pro', so its CTA reads Upgrade.
      expect(billing.checkoutPlans, <String>['business']);
      // AND the cycle whose figure the card was rendering. The fixture is on
      // annual, so the toggle opens there and the charge follows the price the
      // customer read. Before the cycle travelled, this call carried the plan
      // alone and the producer picked whichever price it found: a customer
      // taking the annual discount was billed the monthly rate.
      expect(billing.checkoutCycles, <BillingCycle>[BillingCycle.annual]);
      // Flush the confirmation toast's auto-dismiss timer.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('the cycle a purchase is made on follows the toggle, so the '
        'charge matches the figure on the card', (tester) async {
      // The other half, and the half that makes the assertion above mean
      // something: an implementation hardcoding either member would pass one of
      // these two and fail the other. The fixture bills annually, so pressing
      // Monthly is a real divergence between what the customer holds and what
      // they are choosing, which is exactly the case a screen must not get
      // wrong.
      final _RailBillingService billing = _RailBillingService();

      await mount(tester, billing, isOwner: true);

      await tester.tap(find.text(trans('magic_starter.billing.plans_monthly')));
      await tester.pump();

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(billing.checkoutCycles, <BillingCycle>[BillingCycle.monthly]);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a tier sold monthly only is bought monthly, even while the '
        'toggle sits on annual', (tester) async {
      // The screen-wide cycle knows nothing about the row it is applied to. With
      // `business` priced monthly and not annually, the toggle still opens on
      // annual (the fixture's subscription is annual), the card still carries a
      // live Upgrade button, and the payload used to name a (business, annual)
      // pair the producer has no price for. It is the same defect as charging
      // the monthly rate under an annual heading, in the other direction: the
      // customer is offered one thing and sold another, or nothing at all.
      final _MonthlyOnlyTierBillingService billing =
          _MonthlyOnlyTierBillingService();

      await mount(tester, billing, isOwner: true);

      // The premise, asserted rather than assumed: the toggle really is on
      // annual, so a monthly charge here can only come from the row.
      expect(
        find.text(trans('magic_starter.billing.plan_billing_annual')),
        findsWidgets,
      );

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(billing.checkoutPlans, <String>['business']);
      expect(billing.checkoutCycles, <BillingCycle>[BillingCycle.monthly]);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('the toggle opens on the cycle the customer is already billed '
        'on, so a tap cannot move them off it by accident', (tester) async {
      // Not cosmetic. With the toggle opening on a fixed segment, a customer on
      // monthly whose screen opened on annual and who then tapped a plan card
      // was moved to that tier ANNUALLY without ever choosing annual.
      final _MonthlyBillingService billing = _MonthlyBillingService();

      await mount(tester, billing, isOwner: true);

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(billing.checkoutCycles, <BillingCycle>[BillingCycle.monthly]);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('an UnsupportedPlatformException renders the deferred info '
        'toast instead of the generic failure one', (tester) async {
      final _RailBillingService billing = _RailBillingService(
        checkoutError: const UnsupportedPlatformException(
          'Web checkout is not available on this platform.',
        ),
      );

      await mount(tester, billing, isOwner: true, withToasts: true);

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(billing.checkoutPlans, <String>['business']);
      expect(
        find.text(trans('magic_starter.billing.toast_deferred_title')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.billing.toast_deferred_text')),
        findsOneWidget,
      );
      // The generic failure sentence must not render alongside it: the two
      // toasts have to stay distinguishable, or this case could not tell a
      // deferral from a real failure.
      expect(
        find.text(trans('magic_starter.billing.toast_checkout_failed_title')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.toast_failed_text')),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('MagicStarterBillingView store rail', () {
    testWidgets('the owner gets a store purchase CTA, no web checkout, and no '
        'catalogue price', (tester) async {
      final _StoreRailBillingService store = _StoreRailBillingService();

      await mount(tester, store, isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsOneWidget,
        reason: 'a store build sells through the store rail',
      );
      // The catalogue's integer figure is not what a storefront charges, and
      // the driver exposes no localised string yet, so the surface states where
      // the price comes from instead of naming a wrong one. Asserted as the
      // exact card price rather than as a substring: the renewal line above the
      // grid legitimately carries the web price for a team a store did NOT sell
      // to, which is this fixture's `manage_via: none`, and the store-billed
      // case has its own test below.
      expect(find.text(r'$29'), findsNothing);
      expect(
        find.text(trans('magic_starter.billing.plan_price_store')),
        findsWidgets,
      );
      // Nothing on a store build may point at web checkout or the portal.
      expect(
        find.text(trans('magic_starter.billing.payment_update_button')),
        findsNothing,
      );
      for (final String text in renderedText(tester)) {
        expect(
          text.toLowerCase(),
          allOf(
            isNot(contains('checkout')),
            isNot(contains('billing.example.test')),
          ),
          reason: 'a store build must not steer to a web purchase',
        );
      }
    });

    testWidgets('tapping the CTA buys through the store rail', (tester) async {
      final _StoreRailBillingService store = _StoreRailBillingService();

      await mount(tester, store, isOwner: true);

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // 'business' sits above the fixture's 'pro', so its CTA reads Upgrade.
      expect(store.purchasedPlans, <String>['business']);
      // Flush the confirmation toast's auto-dismiss timer.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('the one-team refusal is re-asked at the tap, not read off the '
        'mount', (tester) async {
      final _StoreRailBillingService store = _StoreRailBillingService();

      // The consumer's cross-team check, whose answer moves under a mounted
      // screen. This replaces the source's endpoint stub: the question is the
      // consumer's own, so the package asks it through a callback.
      String? fundedTeam;
      var storeChecks = 0;

      await mount(
        tester,
        store,
        isOwner: true,
        withToasts: true,
        storeFundedTeam: () async {
          storeChecks++;

          return fundedTeam;
        },
      );

      // The CTA rendered because nothing funded another team when the screen
      // loaded.
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsOneWidget,
      );
      expect(storeChecks, 1, reason: 'the mount asks once');

      // Then the answer changes under a mounted screen: another device bought,
      // or a deep link fired before the read had resolved at all.
      fundedTeam = 'Kodizm Ops';

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        storeChecks,
        2,
        reason: 'the tap is the one that guards the money, so it asks again',
      );
      expect(
        store.purchasedPlans,
        isEmpty,
        reason: 'the sheet must not open at all, not open and be undone',
      );
      expect(
        find.text(trans('magic_starter.billing.store_bound_title')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a dismissed purchase sheet reports nothing at all', (
      tester,
    ) async {
      // `false` is the ordinary outcome of a customer changing their mind, so a
      // "purchase complete" or an "it failed" toast would both be this screen
      // inventing an event.
      final _StoreRailBillingService store = _StoreRailBillingService(
        purchaseResult: false,
      );

      await mount(tester, store, isOwner: true, withToasts: true);

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(store.purchasedPlans, <String>['business']);
      expect(
        find.text(trans('magic_starter.billing.store_purchase_title')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.toast_checkout_failed_title')),
        findsNothing,
      );
    });

    testWidgets('a rail failure surfaces the failure toast and does not crash '
        'the screen', (tester) async {
      // The message a real unconfigured rail throws, near enough verbatim: the
      // payments package writes these for whoever wired the rail up, and this
      // one names an internal config key.
      const String developerMessage =
          'The store rail is not configured. Set '
          'payments.revenuecat.public_sdk_key to this platform\'s public '
          'RevenueCat SDK key.';

      final _StoreRailBillingService store = _StoreRailBillingService(
        purchaseError: const BillingException(developerMessage),
      );

      await mount(tester, store, isOwner: true, withToasts: true);

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.toast_checkout_failed_title')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.billing.store_purchase_title')),
        findsNothing,
      );

      // The body is the customer's sentence, and the developer's never reaches
      // the screen. This used to render the exception message directly, so a
      // non-English session was shown an English sentence naming a config key.
      expect(
        find.text(trans('magic_starter.billing.toast_failed_text')),
        findsOneWidget,
      );
      expect(find.textContaining('public_sdk_key'), findsNothing);
      expect(find.text(developerMessage), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a non-owner gets no store purchase CTA and no restore', (
      tester,
    ) async {
      final _StoreRailBillingService store = _StoreRailBillingService();

      await mount(tester, store, isOwner: false);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.store_restore_button')),
        findsNothing,
        reason: 'a restore would re-attribute a subscription to this team too',
      );
      expect(store.purchasedPlans, isEmpty);
      expect(
        find.text(trans('magic_starter.billing.owner_only_notice')),
        findsOneWidget,
      );
    });

    testWidgets('a store account already funding another team is refused with '
        'that team named', (tester) async {
      final _StoreRailBillingService store = _StoreRailBillingService();

      await mount(
        tester,
        store,
        isOwner: true,
        storeFundedTeam: () async => 'Kodizm Ops',
      );

      expect(tester.takeException(), isNull);
      // The refusal names the team, because "a store account can fund only one
      // team" is unactionable without knowing which one holds it.
      expect(
        find.text(
          trans('magic_starter.billing.store_bound_text', <String, dynamic>{
            'team': 'Kodizm Ops',
          }),
        ),
        findsOneWidget,
      );
      // And it is a refusal rather than a warning beside a live button: the
      // second purchase would TRANSFER the subscription off the named team.
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.store_restore_button')),
        findsNothing,
      );
      expect(store.purchasedPlans, isEmpty);
    });

    testWidgets('a build with NO store check registered refuses the store '
        'purchase outright', (tester) async {
      // The same null the case above reaches through a registered check that
      // found nothing, arriving from the opposite direction: the question was
      // never asked and never can be. Nothing here can promise a second
      // purchase will not transfer another team's subscription away, and an
      // unregistered hook must not be able to permit one silently.
      final _StoreRailBillingService store = _StoreRailBillingService();

      Magic.put(
        MagicStarterBillingController(
          usageCopy: _usageCopy,
          formatNumber: _formatNumber,
          isOwnerReader: () => true,
          billingService: store,
        ),
      );

      await tester.binding.setSurfaceSize(const Size(1280, 12000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(MagicStarter.view.make('teams.billing')));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.store_restore_button')),
        findsNothing,
      );
      expect(store.purchasedPlans, isEmpty);
    });

    testWidgets('a web-billed team gets no store purchase surface', (
      tester,
    ) async {
      // The mirror of the store-rail refusal on the web side: a second rail
      // must never open a parallel subscription, whichever rail is second.
      final _StoreRailBillingService store = _StoreRailBillingService(
        manageVia: 'portal',
      );

      await mount(tester, store, isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.store_restore_button')),
        findsNothing,
      );
      expect(store.purchasedPlans, isEmpty);
    });

    testWidgets('restoring hands the store purchase back and reports what the '
        'store answered', (tester) async {
      final _StoreRailBillingService store = _StoreRailBillingService(
        restoreResult: false,
      );

      await mount(tester, store, isOwner: true, withToasts: true);

      await tester.tap(
        find.text(trans('magic_starter.billing.store_restore_button')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(store.restoreCalls, 1);
      // `false` is an answer to show the customer, not a failure to log.
      expect(
        find.text(trans('magic_starter.billing.store_restore_none_title')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a store-billed team reads its renewal line off the store, not '
        'off the catalogue', (tester) async {
      final _StoreRailBillingService store = _StoreRailBillingService(
        manageVia: 'app_store',
      );

      await mount(tester, store, isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.renewal_store')),
        findsOneWidget,
      );
      expect(
        find.textContaining(trans('magic_starter.billing.plan_billing_annual')),
        findsNothing,
      );
    });
  });

  group('a tier with no rail behind it says so', () {
    testWidgets('the renewal line does not promise a renewal it cannot have', (
      tester,
    ) async {
      await mount(tester, _UnbilledBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.renewal_unbilled')),
        findsOneWidget,
      );
      // The defect this replaces: the sentence rendered `renews Unknown`, which
      // reads as a renewal whose date was lost rather than as no renewal.
      expect(find.textContaining(trans('common.unknown')), findsNothing);
      // The live sentence's own separator, not the bare word: the honest
      // replacement above ends in "nothing renews", so asserting on `renews`
      // alone matches the fix and fails on the very thing it is checking.
      expect(find.textContaining('· renews '), findsNothing);
    });

    testWidgets('the renewal line names the cycle the customer BOUGHT, not the '
        'one the toggle is showing', (tester) async {
      // The defect in its exact shape. The sentence used to pass
      // `BillingCycle.annual` as a LITERAL, so every paying customer read
      // "billed annually" whatever they were charged. Reading the toggle
      // instead would only move the claim onto a control the customer can
      // press, so the test presses it: this fixture is billed monthly, the
      // toggle is moved to annual, and the sentence has to keep saying monthly
      // because that is what is being charged.
      await mount(tester, _MonthlyBillingService(), isOwner: true);

      expect(
        find.text(r'$34/mo billed monthly · renews Jun 1, 2026'),
        findsOneWidget,
      );

      await tester.tap(find.text(trans('magic_starter.billing.plans_annual')));
      await tester.pumpAndSettle();

      expect(
        find.text(r'$34/mo billed monthly · renews Jun 1, 2026'),
        findsOneWidget,
        reason: 'the toggle changes catalogue figures, never the charge',
      );
    });

    testWidgets('a cycle nothing reported is left unnamed rather than guessed', (
      tester,
    ) async {
      // A store subscription and a price mapped without a declared cycle both
      // reach the client as a null cycle. Naming either one is the claim this
      // whole change exists to stop making, so the sentence drops the price and
      // the cycle and keeps the date, which is the part that was reported.
      await mount(tester, _CyclelessBillingService(), isOwner: true);

      expect(
        find.text(
          trans(
            'magic_starter.billing.renewal_text_cycleless',
            <String, dynamic>{'date': 'Jun 1, 2026'},
          ),
        ),
        findsOneWidget,
      );

      // Scoped to the renewal sentence's own separator, not to the word
      // "billed": the plan CARDS legitimately carry "billed annually" as
      // catalogue display copy for the column they are showing, and asserting
      // on that would fail against correct behaviour.
      expect(find.textContaining('· renews '), findsNothing);
      expect(find.textContaining('/mo billed'), findsNothing);
    });

    testWidgets('a cancelled subscription is told when it ends, not that it '
        'renews', (tester) async {
      await mount(tester, _CancelledBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);

      // The same date the renewing case shows, under the other verb. Asserting
      // the whole sentence rather than the verb alone: the price and the date
      // have to survive the branch, and an arm that dropped either would still
      // pass a check for the word "ends".
      expect(
        find.text(r'$29/mo billed annually · ends Jun 1, 2026'),
        findsOneWidget,
      );

      // The defect: this read "renews Jun 1, 2026" to the one customer who had
      // just cancelled and was checking that it took.
      expect(find.textContaining('· renews '), findsNothing);
    });

    testWidgets('the payment section names the absence instead of labelling a '
        'card Unknown', (tester) async {
      await mount(tester, _UnbilledBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.payment_none')),
        findsOneWidget,
      );
      // Two symptoms of one defect, both pinned. The brand tile rendered
      // `common.unknown` beside a row that fell back to the SECTION HEADING, so
      // "Payment method" appeared twice and the pair read as a real card of an
      // unknown brand.
      expect(find.textContaining(trans('common.unknown')), findsNothing);
      expect(
        find.text(trans('magic_starter.billing.payment_header')),
        findsOneWidget,
      );
    });
  });

  group('a held tier the catalogue no longer serves renders as unknown', () {
    testWidgets('the current-plan card names the held tier id instead of the '
        "catalogue's cheapest plan", (tester) async {
      await mount(tester, _HeldRetiredTierBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);
      // The defect this replaces: the plan lookup fell back to the first
      // catalogue row, so a grandfathered customer saw the cheapest tier's name
      // and renewal line as their own current plan.
      expect(
        find.text(
          trans(
            'magic_starter.billing.plan_unavailable_text',
            <String, dynamic>{'id': 'legacy_grandfathered'},
          ),
        ),
        findsOneWidget,
      );
      // The "Current" badge still marks the card as theirs, even though its
      // details are unavailable. Exactly one: no priced-tier card in the grid
      // may claim to be the active plan when the lookup found none.
      expect(
        find.text(trans('magic_starter.billing.plan_current_badge')),
        findsOneWidget,
      );
    });

    testWidgets('every plan card falls back to a neutral comparison label '
        'rather than Upgrade or Downgrade', (tester) async {
      await mount(tester, _HeldRetiredTierBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_downgrade')),
        findsNothing,
      );
      // Every priced, non-custom card reads the neutral label; the custom tier
      // keeps its own contact-sales copy.
      expect(
        find.text(trans('magic_starter.billing.plan_button_unranked')),
        findsNWidgets(3),
      );
    });

    testWidgets('a second-catalogue session renders that catalogue\'s copy, '
        'not a raw i18n key', (tester) async {
      Translator.instance.setLoader(
        const _CatalogueLoader(_secondLocaleCatalogue),
      );
      await Translator.instance.setLocale(const Locale('xx'));

      await mount(tester, _HeldRetiredTierBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          trans(
            'magic_starter.billing.plan_unavailable_text',
            <String, dynamic>{'id': 'legacy_grandfathered'},
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_unranked')),
        findsNWidgets(3),
      );
      expect(find.textContaining('magic_starter.billing.'), findsNothing);
    });
  });

  group('a failed read is never reported as an absence', () {
    testWidgets('a paying customer is not told they have no subscription when '
        'the rail read soft-failed', (tester) async {
      await mount(tester, _SoftFailedPaymentBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);

      // The sentence is TRUE only of a team with no rail. This team has one:
      // `manage_via` is `portal`, so a billing customer exists, and the
      // producer's own `available: false` says the rail could not be asked.
      expect(
        find.text(trans('magic_starter.billing.renewal_unbilled')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.payment_none')),
        findsNothing,
      );
    });

    testWidgets('it says the read failed rather than inventing a card', (
      tester,
    ) async {
      await mount(tester, _SoftFailedPaymentBillingService(), isOwner: true);

      // What the customer should see: the truth, which is that we could not
      // read their card, next to the button that lets them replace it.
      expect(find.text(trans('common.error_occurred')), findsOneWidget);

      // And not the incoherent pair this whole thread started from: a brand
      // tile reading "Unknown" beside a row that fell back to the SECTION
      // HEADING, so the heading appeared twice.
      expect(
        find.text(trans('magic_starter.billing.payment_header')),
        findsOneWidget,
      );

      // The renewal line DOES still read "renews Unknown" here, and that is the
      // intended answer rather than an oversight: the read did not resolve into
      // anything, so a neutral label is the honest fallback, and it is what this
      // state rendered before any of this work. Asserted rather than forbidden,
      // because the temptation on seeing it is to reach for the confident
      // sentence, which is exactly the defect the sibling test pins.
      expect(find.textContaining(trans('common.unknown')), findsOneWidget);
    });
  });

  group('MagicStarterBillingView registration', () {
    testWidgets('the registry answers under teams.billing, and what it '
        'answers wears the shared page chrome', (tester) async {
      // The half a consumer actually depends on. The screen is reached BY KEY
      // (the route resolves `teams.billing` through the registry), so a view
      // that exists but is not registered is a screen nobody can open, and a
      // case that constructed the widget directly would pass against exactly
      // that.
      expect(MagicStarter.view.has('teams.billing'), isTrue);

      await mount(tester, _RailBillingService());

      expect(tester.takeException(), isNull);
      // Through MSPageScaffold rather than hand-rolled page chrome: the
      // scaffold is what routes the page through the host's one container
      // geometry, and a page that painted its own would centre at its own
      // width inside the same shell.
      expect(find.byType(MSPageScaffold), findsOneWidget);
      expect(find.text(trans('magic_starter.billing.title')), findsOneWidget);
      expect(
        find.text(trans('magic_starter.billing.description')),
        findsOneWidget,
      );
    });

    test('the feature flag off leaves the key unregistered entirely', () {
      // Not "registered and then refused at build": absent. The manager
      // registers its defaults in its constructor, so the flag is flipped
      // before the singleton is ever resolved.
      Config.set('magic_starter.features.billing', false);
      Magic.singleton('magic_starter', () => MagicStarterManager());

      expect(MagicStarter.view.has('teams.billing'), isFalse);
      expect(
        () => MagicStarter.view.make('teams.billing'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('an unresolved rail claims neither sentence', () {
    testWidgets('the payment card waits instead of picking one', (
      tester,
    ) async {
      await mount(tester, _UnresolvedRailBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);

      // Neither is knowable yet: "no card on file" needs to know there is no
      // rail, and "the read failed" needs to know one failed. The payload
      // carries no `available` either, so nothing in it settles the question.
      // The second sneaked in with the fix for the first, because `null` is not
      // `ManageVia.none` and the branch keyed on the negative.
      expect(
        find.text(trans('magic_starter.billing.payment_none')),
        findsNothing,
      );
      expect(find.text(trans('common.error_occurred')), findsNothing);
    });
  });

  /// Which of the payment card's two sentences a build put on screen.
  ///
  /// A record rather than a pair of expectations inside each scenario, because
  /// the subject below is that the bodies DIFFER FROM EACH OTHER, and that
  /// comparison cannot be made one scenario at a time. Neither sentence is
  /// rendered anywhere else on this screen, so their presence is the body.
  ({bool none, bool failed}) paymentBody(WidgetTester tester) {
    return (
      none: find
          .text(trans('magic_starter.billing.payment_none'))
          .evaluate()
          .isNotEmpty,
      failed: find.text(trans('common.error_occurred')).evaluate().isNotEmpty,
    );
  }

  /// Tears the screen down between two mounts inside one case.
  ///
  /// Not optional, and not tidiness. [mount] pumps the same widget shape every
  /// time, so Flutter matches the existing element and REUSES the state: the
  /// second mount's controller is registered but never resolved, and every
  /// assertion after it silently re-reads the first scenario's body. Every
  /// comparison below would pass by construction without this.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  group('an empty card read is four questions, not one', () {
    testWidgets('the three available states render three different bodies, and '
        'a transport failure renders the failure one', (tester) async {
      // 1. The producer says its rail answered and there is genuinely no card.
      await mount(
        tester,
        _EmptyCardBillingService(available: true),
        isOwner: true,
      );
      final ({bool none, bool failed}) resolvedEmpty = paymentBody(tester);
      await unmount(tester);

      // 2. The producer says its rail could not be asked. Note the entitlement
      //    is `none` here as well: `available` OVERRIDES the reconstruction
      //    rather than agreeing with it, which is the whole reason the field was
      //    added. A screen that kept reading `manage_via` would answer 1 and 2
      //    identically.
      await mount(
        tester,
        _EmptyCardBillingService(available: false),
        isOwner: true,
      );
      final ({bool none, bool failed}) railUnreachable = paymentBody(tester);
      await unmount(tester);

      // 3. A producer too old to report the field at all, on a screen whose
      //    entitlement read has not resolved either. Neither sentence is
      //    knowable, so neither is claimed.
      await mount(tester, _UnresolvedRailBillingService(), isOwner: true);
      final ({bool none, bool failed}) unreported = paymentBody(tester);
      await unmount(tester);

      // 4. The response never arrived. No producer flag can express this,
      //    because no producer flag was received.
      await mount(
        tester,
        _TransportFailedPaymentBillingService(),
        isOwner: true,
      );
      final ({bool none, bool failed}) transportFailed = paymentBody(tester);

      expect(tester.takeException(), isNull);

      expect(resolvedEmpty, (none: true, failed: false));
      expect(railUnreachable, (none: false, failed: true));
      expect(unreported, (none: false, failed: false));
      expect(transportFailed, (none: false, failed: true));

      // The three `available` states differ from each other, which is the
      // collapse this guards: every earlier version of this branch answered two
      // of the three with one sentence, and each time the sentence was
      // confident and wrong rather than missing.
      expect(<({bool none, bool failed})>{
        resolvedEmpty,
        railUnreachable,
        unreported,
      }, hasLength(3));

      // A transport failure deliberately reads the SAME as a rail the producer
      // could not ask, and that is not a fourth distinct body by oversight: both
      // are "we could not read your card", the customer's action is the same in
      // both, and the package ships one sentence for it. Pinned rather than left
      // implicit, because the temptation on seeing three bodies for four inputs
      // is to invent a fourth sentence that names an internal distinction the
      // customer cannot act on.
      expect(transportFailed, railUnreachable);
    });

    testWidgets('an unreported field falls back to the reconstruction, so an '
        'adopter on an older producer still gets both sentences', (
      tester,
    ) async {
      // The reason the `null` arm may not read as `false`: this is what a
      // backend that predates the field sends, and answering "the rail is down"
      // for every one of them would be a screen-wide regression on upgrade.
      await mount(
        tester,
        _EmptyCardBillingService(manageVia: 'none'),
        isOwner: true,
      );
      expect(paymentBody(tester), (none: true, failed: false));
      await unmount(tester);

      await mount(
        tester,
        _EmptyCardBillingService(manageVia: 'portal'),
        isOwner: true,
      );
      expect(paymentBody(tester), (none: false, failed: true));

      expect(tester.takeException(), isNull);
    });
  });

  group('the plan card is complete without the consumer, and richer with it', () {
    /// The two product lines the shipped catalogue carries and this package
    /// deliberately does not name: a value claim, and a recurring SURCHARGE.
    const String proAiLine =
        'Full AI incident analysis: evidence, confidence, citations, '
        'drafted updates.';
    const String responderAddOn = r'+$9/mo per extra responder';

    testWidgets('with no slot registered the card still names, prices and sells '
        'the tier, and claims nothing it cannot', (tester) async {
      await mount(tester, _RailBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);

      // Complete: the tier, its positioning, its price, its cadence, every
      // feature bullet the catalogue carries, and a way to buy it.
      //
      // Twice for the name, because the held tier is `pro` in this fixture and
      // the current-plan card above the grid names it too.
      expect(find.text('Pro'), findsNWidgets(2));
      expect(find.text('Startups and small teams that page.'), findsOneWidget);
      expect(find.text(r'$29'), findsOneWidget);
      expect(
        find.text(trans('magic_starter.billing.plan_billing_annual')),
        findsWidgets,
      );
      for (final String feature in <String>[
        '50 monitors · 30-second checks',
        '3 status pages · 1,000 subscribers',
        '3 responders · on-call schedules & escalation policies',
        'SLO targets & error budgets',
      ]) {
        expect(find.text(feature), findsOneWidget);
      }
      expect(
        find.text(trans('magic_starter.billing.plan_button_current')),
        findsOneWidget,
      );

      // Honest: the two fields the package never typed are absent rather than
      // guessed at. A package that picked one of them would pick the wrong one
      // for the next adopter.
      expect(find.text(proAiLine), findsNothing);
      expect(find.text(responderAddOn), findsNothing);
    });

    testWidgets('a registered slot receives the whole catalogue row, so BOTH '
        'product lines reach the card', (tester) async {
      // The slot renders two fields, and that is the point of handing the raw
      // map over rather than a field the package chose: dropping the surcharge
      // line omits a recurring CHARGE from a purchase decision, which is a
      // different class of harm from dropping the value claim beside it.
      MagicStarter.view.slot('teams.billing', 'plan_card_highlight', (
        BuildContext context,
      ) {
        final MagicStarterPlan plan = MagicStarterPlanCardScope.of(context);
        final Object? aiLine = plan.raw['ai_line'];
        final Object? addOn = plan.raw['responder_add_on'];

        return WDiv(
          className: 'flex flex-col gap-1',
          children: <Widget>[
            if (aiLine is String) WText(aiLine, className: 'text-xs'),
            if (addOn is String) WText(addOn, className: 'text-xs'),
          ],
        );
      });

      await mount(tester, _RailBillingService(), isOwner: true);

      expect(tester.takeException(), isNull);
      expect(find.text(proAiLine), findsOneWidget);
      // Two of the four catalogue rows carry the surcharge, and both render it:
      // the slot is built per CARD, not once for the grid.
      expect(find.text(responderAddOn), findsNWidgets(2));
      // And the card the package builds is unchanged around it.
      expect(find.text(r'$29'), findsOneWidget);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsOneWidget,
      );
    });
  });

  group('a store build names no catalogue price', () {
    testWidgets('every priced tier states where its price comes from, and no '
        'catalogue figure reaches the screen', (tester) async {
      // A store-BILLED team, so the renewal line above the grid carries no
      // figure either and the assertion can be a substring search over the whole
      // tree rather than an exact-text one. The catalogue's integers are in the
      // vendor's own currency; a storefront charges a localised amount on its
      // own cadence, so every one of these figures would be wrong.
      final _StoreRailBillingService store = _StoreRailBillingService(
        manageVia: 'app_store',
      );

      await mount(tester, store, isOwner: true);

      expect(tester.takeException(), isNull);
      for (final String figure in <String>[r'$29', r'$34', r'$99', r'$119']) {
        expect(
          find.textContaining(figure),
          findsNothing,
          reason: 'a store build must not name a catalogue price',
        );
      }
      expect(
        find.text(trans('magic_starter.billing.plan_price_store')),
        findsNWidgets(2),
        reason: 'both priced tiers say where the price comes from instead',
      );
      // The free tier keeps its zero, which is true in every currency, and the
      // custom tier keeps its own word.
      expect(find.text(r'$0'), findsOneWidget);
      expect(
        find.text(trans('magic_starter.billing.plan_price_custom')),
        findsOneWidget,
      );
      // And no annual cadence anywhere: a store catalogue sells the monthly
      // SKUs only, so the toggle is gone and no card claims an annual bill.
      expect(
        find.text(trans('magic_starter.billing.plans_annual')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_billing_annual')),
        findsNothing,
      );
    });
  });

  group('an unset web origin cannot sell', () {
    testWidgets('no checkout CTA renders, because the session it would open '
        'cannot be created', (tester) async {
      // An empty value rather than an absent key: a half-filled `.env` produces
      // exactly this, and the config reads it as unset for the same reason (it
      // would still yield a relative url). Without this gate the CTA renders,
      // the rail refuses the session, and the refusal names the config key to
      // the LOG and nothing at all to the adopter who forgot it.
      Config.set('magic_starter.billing.web_origin', '');

      final _RailBillingService billing = _RailBillingService(
        invoices: <Invoice>[invoice],
      );

      await mount(tester, billing, isOwner: true);

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.plan_button_upgrade')),
        findsNothing,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_downgrade')),
        findsNothing,
      );
      expect(billing.checkoutPlans, isEmpty);

      // The two labels that are not purchases survive, because neither spends
      // anything: the active tier's read-out and the custom tier's sales
      // handoff.
      expect(
        find.text(trans('magic_starter.billing.plan_button_current')),
        findsOneWidget,
      );
      expect(
        find.text(trans('magic_starter.billing.plan_button_contact')),
        findsOneWidget,
      );
    });

    testWidgets('the portal affordances survive it, since a return url is '
        'optional where a checkout redirect is not', (tester) async {
      Config.set('magic_starter.billing.web_origin', '');

      await mount(
        tester,
        _RailBillingService(manageVia: 'portal', invoices: <Invoice>[invoice]),
        isOwner: true,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text(trans('magic_starter.billing.payment_update_button')),
        findsOneWidget,
        reason:
            'an unconfigured origin must not take a customer away from '
            'their own card',
      );
      expect(
        find.text(trans('magic_starter.billing.invoice_receipt_button')),
        findsOneWidget,
      );
    });
  });

  group('the sales handoff names the tier the catalogue named', () {
    testWidgets('the toast carries the plan name, not a tier this package '
        'hardcoded', (tester) async {
      // A framework package may not ship one vendor's tier name, and English is
      // where a hardcoded "Enterprise" passes by construction, so the catalogue
      // renames its custom tier to something no literal here could produce.
      final _RenamedCustomTierBillingService billing =
          _RenamedCustomTierBillingService();

      await mount(tester, billing, isOwner: true, withToasts: true);

      await tester.tap(
        find.text(trans('magic_starter.billing.plan_button_contact')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          trans(
            'magic_starter.billing.toast_contact_description',
            <String, dynamic>{'name': 'Kurumsal Ölçek'},
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Enterprise'), findsNothing);
      // A sales handoff spends nothing, so it reaches no rail.
      expect(billing.checkoutPlans, isEmpty);
      expect(billing.portalCalls, 0);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
