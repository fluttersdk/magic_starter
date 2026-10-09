// Pins the one property this controller exists for: SIX independent reads that
// degrade INDEPENDENTLY. The whole reason it refuses `MagicStateMixin` is that
// one shared state slot would let any single failing read blank the other five,
// so the failure cases below are written one read at a time. A test that failed
// all six together would pass just as happily against the shared-slot design
// this file is guarding against.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';
import 'package:magic_starter/magic_starter.dart';

/// The six reads, named as the fake records them.
const String _entitlementRead = 'currentEntitlement';
const String _plansRead = 'getPlans';
const String _usageRead = 'getUsage';
const String _invoicesRead = 'getInvoices';
const String _paymentMethodRead = 'getPaymentMethod';

/// A fake serving all three contracts at once, so both rails resolve and the
/// store-funded read is reachable.
///
/// Each read can be failed on its own, which is the axis every case below
/// varies, and every read parks on [gate] while one is held, which is how the
/// parallel-dispatch case observes six in-flight requests at the same instant.
class _FakeBilling
    implements BillingService, WebBillingService, StoreBillingService {
  bool failEntitlement = false;
  bool failPlans = false;
  bool failUsage = false;
  bool failInvoices = false;
  bool failPaymentMethod = false;

  /// Raises an `Error` rather than an `Exception` out of `getInvoices`.
  ///
  /// Its own flag because [failInvoices] cannot reach this path: it throws a
  /// `BillingException`, and `MagicPaginator` catches `on Exception` and parks
  /// it on `error`. Only an `Error` gets past the paginator to the caller, which
  /// is the shape a consumer's own bad cast takes.
  bool throwInvoicesError = false;

  /// Held open to park every read before it resolves.
  Completer<void>? gate;

  /// Gates ONLY the entitlement read, independent of [gate], so a test can
  /// hold that one kind open while the other five resolve normally: the
  /// straddle this fixture exists for needs the batch's OTHER five reads to
  /// have already landed while its entitlement read is still in flight.
  Completer<void>? entitlementGate;

  /// The plan [currentEntitlement] answers with, captured at CALL time
  /// (before the read parks on [gate]) rather than at resolution time: a
  /// caller that changes it while an earlier call is still parked models a
  /// session change arriving while that earlier call's answer is still in
  /// flight, and the earlier call must keep answering for the session it was
  /// actually asked about.
  String entitlementPlan = 'tier-b';

  /// Every read that has STARTED, in dispatch order.
  final List<String> started = <String>[];

  Future<void> _enter(String read) async {
    started.add(read);
    final Completer<void>? held = gate;
    if (held != null) await held.future;
  }

  @override
  Future<BillingEntitlement> currentEntitlement() async {
    final String plan = entitlementPlan;
    await _enter(_entitlementRead);
    final Completer<void>? heldEntitlement = entitlementGate;
    if (heldEntitlement != null) await heldEntitlement.future;
    if (failEntitlement) {
      throw const BillingException('entitlement read failed');
    }

    return BillingEntitlement(
      plan: plan,
      manageVia: ManageVia.portal,
      manageUrl: 'https://example.test/manage',
      raw: <String, dynamic>{'plan': plan},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPlans() async {
    await _enter(_plansRead);
    if (failPlans) throw const BillingException('catalogue read failed');

    return <Map<String, dynamic>>[
      <String, dynamic>{'id': 'tier-a', 'name': 'Tier A', 'monthly': 0},
      <String, dynamic>{'id': 'tier-b', 'name': 'Tier B', 'monthly': 29},
    ];
  }

  @override
  Future<List<UsageStat>> getUsage() async {
    await _enter(_usageRead);
    if (failUsage) throw const BillingException('usage read failed');

    return const <UsageStat>[
      UsageStat(key: 'seats', used: 3, limit: 10),
      UsageStat(key: 'requests_this_month', used: 12, limit: null),
    ];
  }

  @override
  Future<BillingInvoicesPage> getInvoices({String? cursor}) async {
    await _enter(_invoicesRead);
    if (failInvoices) throw const BillingException('invoices read failed');
    if (throwInvoicesError) throw StateError('invoices read blew up');

    return BillingInvoicesPage.fromMap(<String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'in_1',
          'number': 'INV-001',
          'amount': '29.00',
          'status': 'paid',
        },
      ],
      'next_cursor': null,
    });
  }

  @override
  Future<PaymentMethod> getPaymentMethod() async {
    await _enter(_paymentMethodRead);
    if (failPaymentMethod) throw const BillingException('rail unreachable');

    return const PaymentMethod(
      brand: 'visa',
      last4: '4242',
      expMonth: 8,
      expYear: 2030,
      available: true,
    );
  }

  // The rail members exist only so this fake SERVES both contracts; nothing in
  // this step calls them.
  @override
  Future<BillingCheckoutSession> checkout({
    required String productKey,
    required String successUrl,
    required String cancelUrl,
  }) => throw UnimplementedError();

  @override
  Future<void> swap({required String productKey}) => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();

  @override
  Future<String> openPortal({String? returnUrl}) => throw UnimplementedError();

  @override
  Future<void> identify(String appUserId) => throw UnimplementedError();

  @override
  Future<bool> purchase(String productKey, {PurchaseContext? context}) =>
      throw UnimplementedError();

  @override
  StoreChangeTiming? get lastChangeTiming => null;

  @override
  Future<Map<String, StoreProductOffer>> products(
    List<String> productKeys,
  ) async => const <String, StoreProductOffer>{};

  @override
  Future<bool> restore() => throw UnimplementedError();

  @override
  Future<void> openStoreManagement() => throw UnimplementedError();

  @override
  ManageVia get store => ManageVia.appStore;
}

/// The consumer's copy table: it names `seats` and deliberately has no word for
/// `requests_this_month`.
///
/// Modelled on a real consumer helper: every stat the producer reported comes
/// back, in the order it sent them, and one this table cannot name keeps a NULL
/// label rather than falling back to its wire key.
/// The consumer's number format, which this package requires and never
/// supplies.
///
/// A recognisable sentinel rather than `toString`, so a case that cares can
/// tell a formatted number from an interpolated one.
String _format(int value) => 'N$value';

List<UsageStat> _copy(List<UsageStat> stats) {
  return stats.map((UsageStat stat) {
    if (stat.key != 'seats') return stat;

    return UsageStat(
      key: stat.key,
      used: stat.used,
      limit: stat.limit,
      label: 'Seats',
    );
  }).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBilling billing;

  MagicStarterBillingController build({
    MagicStarterUsageCopy? usageCopy,
    MagicStarterStoreFundedTeamReader? storeFundedTeamReader,
  }) {
    return MagicStarterBillingController(
      usageCopy: usageCopy ?? _copy,
      formatNumber: _format,
      storeFundedTeamReader: storeFundedTeamReader,
      billingService: billing,
    );
  }

  /// Asserts the five non-store reads all landed, so a case that failed exactly
  /// one read can say the OTHER five survived rather than only that the screen
  /// did not crash.
  void expectPopulated(
    MagicStarterBillingController controller, {
    String? except,
  }) {
    if (except != _entitlementRead) {
      expect(controller.currentPlanId, 'tier-b');
      expect(controller.entitlementLoaded, isTrue);
      expect(controller.manageVia, ManageVia.portal);
      expect(controller.manageUrl, 'https://example.test/manage');
    }
    if (except != _plansRead) {
      expect(controller.plans, hasLength(2));
      expect(controller.plans.first.id, 'tier-a');
    }
    if (except != _usageRead) {
      expect(controller.usage, hasLength(2));
    }
    if (except != _invoicesRead) {
      expect(controller.invoices, hasLength(1));
      expect(controller.invoices.first.number, 'INV-001');
    }
    if (except != _paymentMethodRead) {
      expect(controller.paymentMethod?.last4, '4242');
      expect(controller.pmLoading, isFalse);
      expect(controller.pmError, isFalse);
    }
  }

  setUp(() {
    MagicApp.reset();
    Magic.flush();

    // `Log` backs every deliberate degradation below, so it has to resolve or
    // the first failing read would fail for the wrong reason.
    Magic.singleton('log', () => LogManager());
    Config.set('logging', {
      'default': 'console',
      'channels': {
        'console': {'driver': 'console', 'level': 'debug'},
      },
    });

    billing = _FakeBilling();
  });

  group('MagicStarterBillingController, all six reads succeed', () {
    test('every field is published from its own read', () async {
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => 'Other Team',
      );

      await controller.load();

      expectPopulated(controller);
      expect(controller.storeFundedTeam, 'Other Team');
      controller.dispose();
    });

    test('the controller notifies its listeners as reads land', () async {
      final MagicStarterBillingController controller = build();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.load();

      // Five reads publish (the store one is skipped with no reader), so a
      // single coalesced notification would mean the screen repainted once at
      // the end instead of as each card resolved.
      expect(notifications, greaterThanOrEqualTo(5));
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, one read fails at a time', () {
    test('a failed entitlement read leaves the other five populated', () async {
      billing.failEntitlement = true;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => 'Other Team',
      );

      await controller.load();

      expect(controller.currentPlanId, isNull);
      expect(controller.entitlementLoaded, isFalse);
      expect(controller.manageVia, isNull);
      expectPopulated(controller, except: _entitlementRead);
      expect(controller.storeFundedTeam, 'Other Team');
      controller.dispose();
    });

    test('a failed catalogue read leaves the other five populated', () async {
      billing.failPlans = true;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => 'Other Team',
      );

      await controller.load();

      expect(controller.plans, isEmpty);
      expectPopulated(controller, except: _plansRead);
      expect(controller.storeFundedTeam, 'Other Team');
      controller.dispose();
    });

    test('a failed usage read leaves the other five populated', () async {
      billing.failUsage = true;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => 'Other Team',
      );

      await controller.load();

      expect(controller.usage, isEmpty);
      expectPopulated(controller, except: _usageRead);
      expect(controller.storeFundedTeam, 'Other Team');
      controller.dispose();
    });

    test('a failed invoices read leaves the other five populated', () async {
      billing.failInvoices = true;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => 'Other Team',
      );

      await controller.load();

      expect(controller.invoices, isEmpty);
      expectPopulated(controller, except: _invoicesRead);
      expect(controller.storeFundedTeam, 'Other Team');
      controller.dispose();
    });

    test('a failed store check leaves the other five populated', () async {
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async =>
            throw const BillingException('store check failed'),
      );

      await controller.load();

      // Permissive on failure: no name means no refusal, which is the
      // deliberate fail-open the producer's transfer handling backs up.
      expect(controller.storeFundedTeam, isNull);
      expectPopulated(controller);
      controller.dispose();
    });

    test('no read throws out of load()', () async {
      billing
        ..failEntitlement = true
        ..failPlans = true
        ..failUsage = true
        ..failInvoices = true
        ..failPaymentMethod = true;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => throw StateError('boom'),
      );

      await expectLater(controller.load(), completes);
      controller.dispose();
    });

    test('an Error out of the invoices read does not escape either', () async {
      // The test above cannot see this: it throws a `BillingException`, and the
      // paginator catches `on Exception` and parks it on `error`, so the read
      // returns normally whether or not this controller guards it. An `Error`
      // is what the paginator deliberately lets through, `BillingService` is
      // the consumer's own class, and `onInit` calls `load()` unawaited, so a
      // bad cast in a consumer's implementation would land as an unhandled
      // zone error rather than as this screen's documented degradation.
      billing.throwInvoicesError = true;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => 'Other Team',
      );

      await expectLater(controller.load(), completes);

      expect(controller.invoices, isEmpty);
      // The point of degrading: the other five reads still answered.
      expectPopulated(controller, except: _invoicesRead);
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, the payment method is isolated', () {
    test('a failed card read sets pmError and touches nothing else', () async {
      billing.failPaymentMethod = true;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => 'Other Team',
      );

      await controller.load();

      expect(controller.pmError, isTrue);
      expect(controller.pmLoading, isFalse);
      expect(controller.paymentMethod, isNull);
      // The whole point of the separate state: the rest of the screen is
      // untouched by a rail that could not be reached.
      expectPopulated(controller, except: _paymentMethodRead);
      expect(controller.storeFundedTeam, 'Other Team');
      controller.dispose();
    });

    test('pmLoading starts true and clears on the success arm', () async {
      final MagicStarterBillingController controller = build();
      expect(controller.pmLoading, isTrue);

      await controller.load();

      expect(controller.pmLoading, isFalse);
      expect(controller.pmError, isFalse);
      expect(controller.paymentMethod?.available, isTrue);
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, the six reads are parallel', () {
    test('all six are in flight before the first one resolves', () async {
      final Completer<void> gate = Completer<void>();
      billing.gate = gate;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async {
          billing.started.add('storeFundedTeamReader');
          await gate.future;
          return null;
        },
      );

      var settled = false;
      final Future<void> pending = controller.load().then((_) {
        settled = true;
      });

      // One microtask turn is enough for six dispatched reads to reach their
      // first await; it is NOT enough for a sequential implementation to get
      // past its first, because that one is parked on a gate nobody has opened.
      await Future<void>.delayed(Duration.zero);

      expect(settled, isFalse);
      expect(billing.started, hasLength(6));
      expect(billing.started, contains(_entitlementRead));
      expect(billing.started, contains(_plansRead));
      expect(billing.started, contains(_usageRead));
      expect(billing.started, contains(_invoicesRead));
      expect(billing.started, contains(_paymentMethodRead));
      expect(billing.started, contains('storeFundedTeamReader'));

      gate.complete();
      await pending;

      expect(settled, isTrue);
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, the usage copy is the consumer\'s', () {
    // `usageCopy` is required by the TYPE: the constructor has no default for
    // it, so an omitted argument is a compile error rather than a silent
    // pass-through or a silent drop. The cases below pin what the required
    // callback is then allowed to do.
    test('a stat the copy table cannot name keeps a NULL label', () async {
      final MagicStarterBillingController controller = build();

      await controller.load();

      final UsageStat named = controller.usage.firstWhere(
        (UsageStat stat) => stat.key == 'seats',
      );
      final UsageStat unnamed = controller.usage.firstWhere(
        (UsageStat stat) => stat.key == 'requests_this_month',
      );

      expect(named.label, 'Seats');
      // The defect this guards: a wire key on a customer's screen. The renderer
      // skips a null-label stat; it never falls back to the key.
      expect(unnamed.label, isNull);
      expect(unnamed.label, isNot('requests_this_month'));
      controller.dispose();
    });

    test('the copy callback is the ONLY thing that labels a stat', () async {
      var calls = 0;
      final MagicStarterBillingController controller = build(
        usageCopy: (List<UsageStat> stats) {
          calls++;
          return stats;
        },
      );

      await controller.load();

      expect(calls, 1);
      expect(
        controller.usage.every((UsageStat stat) => stat.label == null),
        isTrue,
      );
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, the store check has two nulls', () {
    test(
      'an unregistered reader is distinguishable from a null answer',
      () async {
        final MagicStarterBillingController unregistered = build();
        final MagicStarterBillingController registered = build(
          storeFundedTeamReader: () async => null,
        );

        await unregistered.load();
        await registered.load();

        // Both answers are null, and they mean opposite things: one question was
        // never asked, the other was asked and came back empty. The gate that
        // reads this has to refuse the first and permit the second.
        expect(unregistered.storeFundedTeam, isNull);
        expect(registered.storeFundedTeam, isNull);
        expect(unregistered.storeCheckRegistered, isFalse);
        expect(registered.storeCheckRegistered, isTrue);

        unregistered.dispose();
        registered.dispose();
      },
    );

    test('a failed read stays registered, so it stays permissive', () async {
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async =>
            throw const BillingException('store check failed'),
      );

      await controller.load();

      expect(controller.storeCheckRegistered, isTrue);
      expect(controller.storeFundedTeam, isNull);
      controller.dispose();
    });

    test('an empty name is not a refusal', () async {
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => '',
      );

      await controller.load();

      expect(controller.storeFundedTeam, isNull);
      controller.dispose();
    });

    test('the check is skipped on a build with no store rail', () async {
      var calls = 0;
      final MagicStarterBillingController controller =
          MagicStarterBillingController(
            usageCopy: _copy,
            formatNumber: _format,
            storeFundedTeamReader: () async {
              calls++;
              return 'Other Team';
            },
            // A read fake that serves NEITHER rail models a build that cannot
            // sell through a store, so there is nothing for the check to gate.
            billingService: _ReadOnlyBilling(),
          );

      await controller.load();

      expect(controller.storeRail, isNull);
      expect(controller.webRail, isNull);
      expect(calls, 0);
      controller.dispose();
    });
  });

  /// Builds a controller over one of the rail fakes below and runs its reads.
  ///
  /// Separate from [build], which is pinned to the both-rails fake: the axis
  /// every gate case varies is which rails a build serves, and a fake that
  /// always serves both can never model a build that serves one.
  Future<MagicStarterBillingController> loaded(
    BillingService service, {
    MagicStarterStoreFundedTeamReader? storeFundedTeamReader,
    MagicStarterTeamOwnershipReader? isOwnerReader,
  }) async {
    final MagicStarterBillingController controller =
        MagicStarterBillingController(
          usageCopy: _copy,
          formatNumber: _format,
          storeFundedTeamReader: storeFundedTeamReader,
          isOwnerReader: isOwnerReader,
          billingService: service,
        );

    await controller.load();

    return controller;
  }

  group('MagicStarterBillingController, the gates are permissive until a read '
      'resolves', () {
    test('with NOTHING read, the web affordances are open', () {
      final MagicStarterBillingController controller =
          MagicStarterBillingController(
            usageCopy: _copy,
            formatNumber: _format,
            billingService: _WebGateBilling(),
          );

      // Deliberately NOT loaded. This is the state a customer sees for the
      // duration of the first fetch, and a suite that only asserts after
      // `load()` cannot see it at all: the property being pinned is that a slow
      // read never hides a paying customer's card.
      expect(controller.manageVia, isNull);
      expect(controller.isOwner, isNull);
      expect(controller.storeManaged, isFalse);
      expect(controller.portalAvailable, isTrue);
      expect(controller.canPurchaseViaWeb, isTrue);
      expect(controller.canPurchase, isTrue);
      controller.dispose();
    });

    test('a FAILED entitlement read stays permissive too', () async {
      final MagicStarterBillingController controller = await loaded(
        _WebGateBilling(resolveEntitlement: false),
      );

      // The unresolved state is permanent here, not a window: the read failed
      // and no retry has run. It still may not stand between an owner and the
      // portal that holds their card.
      expect(controller.manageVia, isNull);
      expect(controller.portalAvailable, isTrue);
      expect(controller.canPurchaseViaWeb, isTrue);
      controller.dispose();
    });

    test('an unregistered ownership reader is unresolved, not a refusal', () {
      final MagicStarterBillingController controller =
          MagicStarterBillingController(
            usageCopy: _copy,
            formatNumber: _format,
            billingService: _WebGateBilling(),
          );

      expect(controller.isOwner, isNull);
      expect(controller.isOwner, isNot(false));
      expect(controller.portalAvailable, isTrue);
      expect(controller.canPurchaseViaWeb, isTrue);
      controller.dispose();
    });

    test('the ownership reader is asked again on every gate read', () async {
      var owner = false;
      final MagicStarterBillingController controller = await loaded(
        _WebGateBilling(),
        isOwnerReader: () => owner,
      );

      expect(controller.canPurchaseViaWeb, isFalse);

      // A team switch moves the answer under a singleton controller, so a value
      // captured at construction would go stale on exactly the transition that
      // matters.
      owner = true;

      expect(controller.canPurchaseViaWeb, isTrue);
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, every gate can go false', () {
    test('storeManaged follows the two store rails only', () async {
      final MagicStarterBillingController appStore = await loaded(
        _WebGateBilling(manageVia: ManageVia.appStore),
      );
      final MagicStarterBillingController playStore = await loaded(
        _WebGateBilling(manageVia: ManageVia.playStore),
      );
      final MagicStarterBillingController portal = await loaded(
        _WebGateBilling(manageVia: ManageVia.portal),
      );
      final MagicStarterBillingController none = await loaded(
        _WebGateBilling(),
      );

      expect(appStore.storeManaged, isTrue);
      expect(playStore.storeManaged, isTrue);
      expect(portal.storeManaged, isFalse);
      expect(none.storeManaged, isFalse);

      appStore.dispose();
      playStore.dispose();
      portal.dispose();
      none.dispose();
    });

    test('portalAvailable refuses on each of its four axes', () async {
      final MagicStarterBillingController open = await loaded(
        _WebGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => true,
      );
      // No web rail: the portal call has no implementation to invoke.
      final MagicStarterBillingController noRail = await loaded(
        _StoreGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => true,
      );
      // `none` is the rail saying there is nowhere to send this customer.
      final MagicStarterBillingController nowhere = await loaded(
        _WebGateBilling(),
        isOwnerReader: () => true,
      );
      // A store rail owns its own management surface.
      final MagicStarterBillingController store = await loaded(
        _WebGateBilling(manageVia: ManageVia.appStore),
        isOwnerReader: () => true,
      );
      // A KNOWN non-owner: the portal endpoint refuses through the same owner
      // check as the write routes, so the button is a 403 waiting to happen.
      final MagicStarterBillingController member = await loaded(
        _WebGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => false,
      );

      expect(open.portalAvailable, isTrue);
      expect(noRail.portalAvailable, isFalse);
      expect(nowhere.portalAvailable, isFalse);
      expect(store.portalAvailable, isFalse);
      expect(member.portalAvailable, isFalse);

      open.dispose();
      noRail.dispose();
      nowhere.dispose();
      store.dispose();
      member.dispose();
    });

    test('canPurchaseViaWeb refuses on each of its three axes', () async {
      final MagicStarterBillingController open = await loaded(
        _WebGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => true,
      );
      final MagicStarterBillingController noRail = await loaded(
        _StoreGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => true,
      );
      // A store already charging: a second rail must not open a parallel
      // subscription.
      final MagicStarterBillingController storeCharging = await loaded(
        _WebGateBilling(manageVia: ManageVia.playStore),
        isOwnerReader: () => true,
      );
      final MagicStarterBillingController member = await loaded(
        _WebGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => false,
      );

      expect(open.canPurchaseViaWeb, isTrue);
      expect(noRail.canPurchaseViaWeb, isFalse);
      expect(storeCharging.canPurchaseViaWeb, isFalse);
      expect(member.canPurchaseViaWeb, isFalse);

      open.dispose();
      noRail.dispose();
      storeCharging.dispose();
      member.dispose();
    });

    test('canPurchaseViaStore refuses on each of its five axes', () async {
      final MagicStarterBillingController open = await loaded(
        _StoreGateBilling(),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final MagicStarterBillingController noRail = await loaded(
        _WebGateBilling(),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final MagicStarterBillingController member = await loaded(
        _StoreGateBilling(),
        isOwnerReader: () => false,
        storeFundedTeamReader: () async => null,
      );
      // The web rail already charging, the mirror image of the refusal above.
      final MagicStarterBillingController webCharging = await loaded(
        _StoreGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final MagicStarterBillingController unregistered = await loaded(
        _StoreGateBilling(),
        isOwnerReader: () => true,
      );
      final MagicStarterBillingController funded = await loaded(
        _StoreGateBilling(),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => 'Second Team',
      );

      expect(open.canPurchaseViaStore, isTrue);
      expect(noRail.canPurchaseViaStore, isFalse);
      expect(member.canPurchaseViaStore, isFalse);
      expect(webCharging.canPurchaseViaStore, isFalse);
      expect(unregistered.canPurchaseViaStore, isFalse);
      expect(funded.canPurchaseViaStore, isFalse);

      open.dispose();
      noRail.dispose();
      member.dispose();
      webCharging.dispose();
      unregistered.dispose();
      funded.dispose();
    });

    test(
      'the two store manage_via values are NOT store-purchase refusals',
      () async {
        final MagicStarterBillingController appStore = await loaded(
          _StoreGateBilling(manageVia: ManageVia.appStore),
          isOwnerReader: () => true,
          storeFundedTeamReader: () async => null,
        );
        final MagicStarterBillingController playStore = await loaded(
          _StoreGateBilling(
            manageVia: ManageVia.playStore,
            rail: ManageVia.playStore,
          ),
          isOwnerReader: () => true,
          storeFundedTeamReader: () async => null,
        );

        // The tiers share one subscription group, so buying the other tier in
        // the SAME store IS the upgrade path: the store replaces rather than
        // adds.
        expect(appStore.canPurchaseViaStore, isTrue);
        expect(playStore.canPurchaseViaStore, isTrue);

        appStore.dispose();
        playStore.dispose();
      },
    );

    test('canPurchase is the union, and goes false when both do', () async {
      final MagicStarterBillingController web = await loaded(
        _WebGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => true,
      );
      final MagicStarterBillingController store = await loaded(
        _StoreGateBilling(),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      // No rail at all: nothing to buy through, on either side.
      final MagicStarterBillingController neither = await loaded(
        _GateBilling(),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );

      expect(web.canPurchaseViaWeb, isTrue);
      expect(web.canPurchaseViaStore, isFalse);
      expect(web.canPurchase, isTrue);

      expect(store.canPurchaseViaStore, isTrue);
      expect(store.canPurchaseViaWeb, isFalse);
      expect(store.canPurchase, isTrue);

      expect(neither.canPurchase, isFalse);

      web.dispose();
      store.dispose();
      neither.dispose();
    });
  });

  group('MagicStarterBillingController, a store purchase is refused while '
      'another store or a wait holds the billable', () {
    test('a subscription the OTHER store sold refuses this store\'s '
        'purchase', () async {
      // App Store billing reaching a Play build: a purchase here opens a
      // second subscription in a store that cannot see the first, which is a
      // double charge no refund flow joins up. The decision reads the rail's
      // own store against the entitlement, never the running platform.
      final MagicStarterBillingController appStoreOnPlay = await loaded(
        _StoreGateBilling(
          manageVia: ManageVia.appStore,
          rail: ManageVia.playStore,
        ),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final MagicStarterBillingController playOnAppStore = await loaded(
        _StoreGateBilling(manageVia: ManageVia.playStore),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );

      expect(appStoreOnPlay.canPurchaseViaStore, isFalse);
      expect(appStoreOnPlay.canPurchase, isFalse);
      expect(playOnAppStore.canPurchaseViaStore, isFalse);

      appStoreOnPlay.dispose();
      playOnAppStore.dispose();
    });

    test('selecting Pro annual buys pro_annual with the catalogue\'s tier '
        'order', () async {
      final _StorePurchaseBilling store = _StorePurchaseBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final MagicStarterPlan pro = controller.plans.firstWhere(
        (MagicStarterPlan plan) => plan.id == 'pro',
      );

      final bool bought = await controller.purchaseInStore(
        pro.productFor(BillingCycle.annual)!,
      );

      expect(bought, isTrue);
      expect(store.purchasedKeys, <String>['pro_annual']);
      final PurchaseContext context = store.contexts.single!;
      expect(context.tierOrder, <String>['free', 'pro', 'business']);
      // Every product the rows list, the grandfathered one included: the rail
      // has to rank a product a customer still holds.
      expect(context.tierOfProduct, <String, String>{
        'pro_monthly': 'pro',
        'pro_annual': 'pro',
        'pro_monthly_2025': 'pro',
        'business_monthly': 'business',
      });
      expect(context.tierOfStoreProduct, <String, String>{
        'com.example.pro.monthly': 'pro',
        'pro:monthly': 'pro',
        'com.example.pro.monthly.2025': 'pro',
        'pro:monthly-2025': 'pro',
        'com.example.business.monthly': 'business',
      });
      controller.dispose();
    });

    test('a completed purchase holds the store gate shut until the '
        'entitlement names the product', () async {
      final _StorePurchaseBilling store = _StorePurchaseBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final MagicStarterProduct annual = controller.plans
          .firstWhere((MagicStarterPlan plan) => plan.id == 'pro')
          .productFor(BillingCycle.annual)!;

      expect(controller.canPurchaseViaStore, isTrue);

      await controller.purchaseInStore(annual);

      // The store's `true` is not the webhook's: until the backend says the
      // team holds pro_annual, a second tap would be a second charge.
      expect(controller.awaitingProductKey, 'pro_annual');
      expect(controller.canPurchaseViaStore, isFalse);

      await controller.loadEntitlement();
      expect(
        controller.canPurchaseViaStore,
        isFalse,
        reason: 'the webhook has not landed yet',
      );

      store.entitlementProductKey = 'pro_annual';
      await controller.loadEntitlement();

      expect(controller.awaitingProductKey, isNull);
      expect(controller.canPurchaseViaStore, isTrue);
      controller.dispose();
    });

    test('a store-pending purchase waits too, and rethrows for the screen to '
        'report', () async {
      final _StorePurchaseBilling store = _StorePurchaseBilling(
        purchaseError: const BillingException(
          'Awaiting approval.',
          code: BillingErrorCode.pending,
        ),
      );
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final MagicStarterProduct monthly = controller.plans
          .firstWhere((MagicStarterPlan plan) => plan.id == 'pro')
          .productFor(BillingCycle.monthly)!;

      await expectLater(
        controller.purchaseInStore(monthly),
        throwsA(
          isA<BillingException>().having(
            (BillingException error) => error.code,
            'code',
            BillingErrorCode.pending,
          ),
        ),
      );

      expect(controller.awaitingProductKey, 'pro_monthly');
      expect(controller.canPurchaseViaStore, isFalse);
      controller.dispose();
    });

    test('a dismissed sheet or a failed purchase leaves nothing to wait '
        'for', () async {
      final _StorePurchaseBilling dismissed = _StorePurchaseBilling(
        purchaseResult: false,
      );
      final _StorePurchaseBilling failed = _StorePurchaseBilling(
        purchaseError: const BillingException(
          'Store refused.',
          code: BillingErrorCode.store,
        ),
      );
      final MagicStarterBillingController first = await loaded(
        dismissed,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final MagicStarterBillingController second = await loaded(
        failed,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );

      expect(
        await first.purchaseInStore(first.plans[1].products.first),
        isFalse,
      );
      await expectLater(
        second.purchaseInStore(second.plans[1].products.first),
        throwsA(isA<BillingException>()),
      );

      expect(first.awaitingProductKey, isNull);
      expect(first.canPurchaseViaStore, isTrue);
      expect(second.awaitingProductKey, isNull);
      expect(second.canPurchaseViaStore, isTrue);
      first.dispose();
      second.dispose();
    });

    test('a session switch drops the wait with the rest of the old team\'s '
        'state', () async {
      final _StorePurchaseBilling store = _StorePurchaseBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );

      await controller.purchaseInStore(controller.plans[1].products.first);
      expect(controller.awaitingProductKey, isNotNull);

      await controller.resetForSession();

      expect(controller.awaitingProductKey, isNull);
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, the store gate reads two nulls', () {
    test('unregistered refuses, a failed read does not, a name refuses BY '
        'name', () async {
      // All three run on the same store build, with the same owner, so the only
      // axis that moves is the store check itself.
      final MagicStarterBillingController unregistered = await loaded(
        _StoreGateBilling(),
        isOwnerReader: () => true,
      );
      final MagicStarterBillingController failedRead = await loaded(
        _StoreGateBilling(),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async =>
            throw const BillingException('store check failed'),
      );
      final MagicStarterBillingController named = await loaded(
        _StoreGateBilling(),
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => 'Second Team',
      );

      // 1. Never asked, and never can be. Nothing here can promise a purchase
      //    will not transfer another team's subscription away, so it refuses.
      expect(unregistered.storeCheckRegistered, isFalse);
      expect(unregistered.storeFundedTeam, isNull);
      expect(unregistered.canPurchaseViaStore, isFalse);
      expect(unregistered.canPurchase, isFalse);

      // 2. Asked, and the read broke. The SAME null as case 1, and the opposite
      //    answer: the deliberate fail-open the producer's transfer handling
      //    backs up. A refusal here would be this gate regressing into strict.
      expect(failedRead.storeCheckRegistered, isTrue);
      expect(failedRead.storeFundedTeam, isNull);
      expect(failedRead.canPurchaseViaStore, isTrue);

      // 3. Asked, and it named a team. The refusal carries the NAME, because a
      //    refusal this screen cannot name is one it cannot explain.
      expect(named.storeCheckRegistered, isTrue);
      expect(named.storeFundedTeam, 'Second Team');
      expect(named.canPurchaseViaStore, isFalse);

      unregistered.dispose();
      failedRead.dispose();
      named.dispose();
    });

    test(
      'a registered check that found nothing permits the purchase',
      () async {
        final MagicStarterBillingController controller = await loaded(
          _StoreGateBilling(),
          isOwnerReader: () => true,
          storeFundedTeamReader: () async => null,
        );

        expect(controller.storeCheckRegistered, isTrue);
        expect(controller.storeFundedTeam, isNull);
        expect(controller.canPurchaseViaStore, isTrue);
        controller.dispose();
      },
    );

    test('an unregistered check does NOT refuse the web purchase', () async {
      final MagicStarterBillingController controller = await loaded(
        _WebGateBilling(manageVia: ManageVia.portal),
        isOwnerReader: () => true,
      );

      // The refusal is about a store account funding a second team, so it
      // belongs to the store gate alone. Spreading it onto the web rail would
      // block a purchase the check has nothing to say about.
      expect(controller.storeCheckRegistered, isFalse);
      expect(controller.canPurchaseViaWeb, isTrue);
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, session scoping', () {
    test('a session change clears every field BEFORE it refills, not just at '
        'the end', () async {
      // 1. Populate fully as team A: all six reads resolved with real
      //    values in every field a session change must clear. Gated on
      //    `billing.gate` on the same terms as `_FakeBilling._enter`, so
      //    that setting the gate before firing the session change parks
      //    this read too; an ungated reader would resolve inside the
      //    single microtask turn below and refill before the checkpoint,
      //    hiding exactly the window this test exists to catch.
      Future<String?> gatedStoreFundedTeamReader() async {
        final Completer<void>? held = billing.gate;
        if (held != null) await held.future;
        return 'Other Team';
      }

      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: gatedStoreFundedTeamReader,
      );
      await controller.load();

      expect(controller.currentPlanId, 'tier-b');
      expect(controller.entitlementLoaded, isTrue);
      expect(controller.manageVia, ManageVia.portal);
      expect(controller.manageUrl, isNotNull);
      expect(controller.plans, isNotEmpty);
      expect(controller.usage, isNotEmpty);
      expect(controller.invoices, isNotEmpty);
      expect(controller.paymentMethod, isNotNull);
      expect(controller.pmLoading, isFalse);
      expect(controller.storeFundedTeam, 'Other Team');

      // 2. Fire the session change, but hold every read open so nothing
      //    can refill yet. Asserting empty only AFTER the refetch settles
      //    would also pass against a controller that never clears,
      //    because the second read overwrites regardless; the window this
      //    guards is the one in between, where team A's rows would
      //    otherwise still be on team B's screen.
      final Completer<void> gate = Completer<void>();
      billing.gate = gate;
      final Future<void> resetting = controller.resetForSession();

      // One microtask turn is enough for the cleared state to publish and
      // for the refetch to dispatch and park on the gate; it is not enough
      // for the gate to open.
      await Future<void>.delayed(Duration.zero);

      // 3. Assert EMPTY first, field by field, including the two fields a
      //    careless reset gets backwards: pmLoading back to true (its own
      //    declaration's start state, not false) and pmError back to
      //    false.
      expect(controller.currentPlanId, isNull);
      expect(controller.entitlementLoaded, isFalse);
      expect(controller.manageVia, isNull);
      expect(controller.manageUrl, isNull);
      expect(controller.plans, isEmpty);
      expect(controller.usage, isEmpty);
      expect(controller.invoices, isEmpty);
      expect(controller.paymentMethod, isNull);
      expect(controller.pmLoading, isTrue);
      expect(controller.pmError, isFalse);
      expect(controller.storeFundedTeam, isNull);

      // 4. Only now let the refetch complete, and assert it refills.
      gate.complete();
      await resetting;

      expect(controller.currentPlanId, 'tier-b');
      expect(controller.entitlementLoaded, isTrue);
      expect(controller.plans, isNotEmpty);
      expect(controller.usage, isNotEmpty);
      expect(controller.invoices, isNotEmpty);
      expect(controller.paymentMethod, isNotNull);
      expect(controller.pmLoading, isFalse);
      expect(controller.storeFundedTeam, 'Other Team');
      controller.dispose();
    });

    test('the reset is exhaustive: every public getter the six reads populate '
        'reports its declaration-time initial value', () async {
      // Reflection is not available, so completeness is proven
      // structurally: every public getter the six reads populate is
      // enumerated below against the literal value ITS OWN field
      // declaration starts at, which is what a reset must reproduce.
      // Parking the refetch on the gate (as the ordering test above does)
      // is what makes this a check of the CLEARED state rather than of
      // whatever the refill happens to publish; asserting after a full
      // `resetForSession()` completes, as an earlier draft of this test
      // did, made every field pass by refilling regardless of whether the
      // reset had cleared it first, which is precisely the false-pass the
      // step's QA warns about.
      //
      // Honest limit: this enumeration is only as complete as the list
      // below. A future field the six reads add and this list forgets to
      // name is invisible to it, the same way it would be invisible to a
      // reset that forgot to clear it.
      Future<String?> gatedStoreFundedTeamReader() async {
        final Completer<void>? held = billing.gate;
        if (held != null) await held.future;
        return 'Other Team';
      }

      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: gatedStoreFundedTeamReader,
      );
      await controller.load();

      final Completer<void> gate = Completer<void>();
      billing.gate = gate;
      final Future<void> resetting = controller.resetForSession();
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentPlanId, isNull);
      expect(controller.entitlementLoaded, isFalse);
      expect(controller.manageVia, isNull);
      expect(controller.manageUrl, isNull);
      expect(controller.plans, isEmpty);
      expect(controller.usage, isEmpty);
      expect(controller.invoices, isEmpty);
      expect(controller.paymentMethod, isNull);
      expect(controller.pmLoading, isTrue);
      expect(controller.pmError, isFalse);
      expect(controller.storeFundedTeam, isNull);

      gate.complete();
      await resetting;
      controller.dispose();
    });

    test('a read from the session a switch interrupted does not land after the '
        'fresh one that replaced it', () async {
      // 1. Team A's own load starts and parks on its own gate: this models
      //    the ordinary `onInit` load still in flight when the team switch
      //    below arrives, which is the window a plain field assignment
      //    after an `await` cannot tell apart from a fresh read for the
      //    NEW session.
      final Completer<void> teamAGate = Completer<void>();
      billing.gate = teamAGate;
      billing.entitlementPlan = 'team-a-plan';
      final MagicStarterBillingController controller = build();
      final Future<void> teamALoad = controller.load();
      await Future<void>.delayed(Duration.zero);

      // 2. The session resets to team B while team A's read is still
      //    parked. `resetForSession` clears the fields and starts its OWN
      //    load, which parks on a fresh gate of its own.
      final Completer<void> teamBGate = Completer<void>();
      billing.gate = teamBGate;
      billing.entitlementPlan = 'team-b-plan';
      final Future<void> resetting = controller.resetForSession();
      await Future<void>.delayed(Duration.zero);

      // 3. Team B's fresh read lands first, same as a customer who stays
      //    on the billing screen through an ordinary switch.
      teamBGate.complete();
      await resetting;
      expect(controller.currentPlanId, 'team-b-plan');

      // 4. Only now does team A's superseded read land. Without the
      //    guard this overwrites team B's plan with team A's, which is
      //    the defect this test exists to catch.
      teamAGate.complete();
      await teamALoad;

      expect(controller.currentPlanId, 'team-b-plan');
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, a standalone read does not straddle '
      'the batch', () {
    test('a standalone entitlement read in flight does not invalidate the '
        "batch's other five reads", () async {
      // 1. Hold the batch's OWN entitlement read open while the other
      //    five resolve normally: this is the shape a real batch takes
      //    while a customer's browser is still waiting on invoices.
      final Completer<void> batchEntitlementGate = Completer<void>();
      billing.entitlementGate = batchEntitlementGate;
      final MagicStarterBillingController controller = build(
        storeFundedTeamReader: () async => 'Other Team',
      );
      final Future<void> batch = controller.load();

      // One microtask turn is enough for the five ungated reads to
      // land; it is not enough for the gate to open.
      await Future<void>.delayed(Duration.zero);
      expect(controller.invoices, isNotEmpty);
      expect(controller.pmLoading, isFalse);
      expect(controller.paymentMethod, isNotNull);
      expect(controller.storeFundedTeam, 'Other Team');

      // 2. A standalone read of the SAME kind runs to completion while
      //    the batch's own entitlement read is still parked, exactly as
      //    the billing view's own retry affordances do. Before this
      //    fix, `loadEntitlement()`'s `_latestRead.begin()` bumped the
      //    ONE counter every read shared, which invalidated the
      //    batch's five OTHER reads too.
      billing.entitlementGate = null;
      billing.entitlementPlan = 'standalone-plan';
      await controller.loadEntitlement();
      expect(controller.currentPlanId, 'standalone-plan');

      // 3. Only now let the batch's own (now superseded) entitlement
      //    read land. Its answer must be dropped rather than overwrite
      //    the standalone one, and the batch's other five reads must
      //    still have published rather than been dropped alongside it.
      batchEntitlementGate.complete();
      await batch;

      expect(controller.currentPlanId, 'standalone-plan');
      expect(controller.invoices, isNotEmpty);
      expect(controller.pmLoading, isFalse);
      expect(controller.paymentMethod, isNotNull);
      expect(controller.storeFundedTeam, 'Other Team');
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, the store prices come from the '
      'store', () {
    test('every catalogue product is priced by one products() read after the '
        'catalogue lands', () async {
      final _WaitStoreBilling store = _WaitStoreBilling(
        offers: const <String, StoreProductOffer>{
          'pro_annual': StoreProductOffer(
            priceString: r'$34.99',
            currencyCode: 'USD',
            price: 34.99,
            subscriptionPeriod: 'P1Y',
          ),
        },
      );
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );

      expect(store.requestedKeys, <List<String>>[
        <String>['pro_monthly', 'pro_annual', 'business_monthly'],
      ]);
      expect(controller.storeOffers.keys, <String>['pro_annual']);
      expect(controller.storeOffers['pro_annual']?.priceString, r'$34.99');
      controller.dispose();
    });

    test('a failed price read degrades: the catalogue stays, the offers stay '
        'empty', () async {
      final _WaitStoreBilling store = _WaitStoreBilling(
        offersError: const BillingException(
          'Store unreachable.',
          code: BillingErrorCode.network,
        ),
      );
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );

      expect(controller.plans, isNotEmpty);
      expect(controller.storeOffers, isEmpty);
      controller.dispose();
    });

    test('a session reset drops the previous team\'s offers', () async {
      final _WaitStoreBilling store = _WaitStoreBilling(
        offers: const <String, StoreProductOffer>{
          'pro_annual': StoreProductOffer(
            priceString: r'$34.99',
            currencyCode: 'USD',
            price: 34.99,
          ),
        },
      );
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      store.offers = const <String, StoreProductOffer>{};

      await controller.resetForSession();

      expect(controller.storeOffers, isEmpty);
      controller.dispose();
    });
  });

  group('MagicStarterBillingController, a store purchase waits for the '
      'backend', () {
    testWidgets('a dismissed sheet waits for nothing and reads nothing', (
      tester,
    ) async {
      final _WaitStoreBilling store = _WaitStoreBilling(purchaseResult: false);
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final int readsBefore = store.entitlementReads;

      final MagicStarterStorePurchaseOutcome outcome = await controller
          .purchaseInStoreAndWait(_product(controller, 'pro_annual'));

      expect(outcome, MagicStarterStorePurchaseOutcome.dismissed);
      expect(store.entitlementReads, readsBefore);
      expect(controller.awaitingProductKey, isNull);
      controller.dispose();
    });

    testWidgets('polls on 1, 2, 4 s and stops the moment the entitlement '
        'differs from the pre-sheet snapshot', (tester) async {
      // Read 1 is the mount's own, so reads 2, 3 and 4 are the three polls and
      // the change lands on the third.
      final _WaitStoreBilling store = _WaitStoreBilling(
        changeOnRead: 4,
        changeTo: 'pro_annual',
      );
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      MagicStarterStorePurchaseOutcome? outcome;
      unawaited(
        controller
            .purchaseInStoreAndWait(_product(controller, 'pro_annual'))
            .then((MagicStarterStorePurchaseOutcome value) => outcome = value),
      );
      await tester.pump();

      expect(controller.awaitingProductKey, 'pro_annual');
      expect(store.entitlementReads, 1, reason: 'nothing is read before 1 s');

      await tester.pump(const Duration(seconds: 1));
      expect(store.entitlementReads, 2);
      await tester.pump(const Duration(seconds: 2));
      expect(store.entitlementReads, 3);
      expect(outcome, isNull);
      await tester.pump(const Duration(seconds: 4));

      expect(store.entitlementReads, 4);
      expect(outcome, MagicStarterStorePurchaseOutcome.confirmed);
      expect(controller.awaitingProductKey, isNull);
      expect(controller.canPurchaseViaStore, isTrue);

      // No fifth read: the wait ended, and a timer left behind would also fail
      // the test on its own.
      await tester.pump(const Duration(seconds: 120));
      expect(store.entitlementReads, 4);
      controller.dispose();
    });

    testWidgets('a backend that never confirms ends in processing after 60 s '
        'and re-opens the store gate', (tester) async {
      final _WaitStoreBilling store = _WaitStoreBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      MagicStarterStorePurchaseOutcome? outcome;
      unawaited(
        controller
            .purchaseInStoreAndWait(_product(controller, 'pro_annual'))
            .then((MagicStarterStorePurchaseOutcome value) => outcome = value),
      );
      await tester.pump();

      await tester.pump(const Duration(seconds: 59));
      expect(outcome, isNull);
      expect(controller.canPurchaseViaStore, isFalse);

      await tester.pump(const Duration(seconds: 1));

      expect(outcome, MagicStarterStorePurchaseOutcome.processing);
      // The wait flag has to be released on a timeout, or the store CTA stays
      // hidden for the rest of the session.
      expect(controller.awaitingProductKey, isNull);
      expect(controller.canPurchaseViaStore, isTrue);
      expect(store.entitlementReads, 7, reason: 'the mount plus six polls');
      controller.dispose();
    });

    testWidgets('a change the rail times at renewal skips the poll and '
        'defers to the pre-sheet period end', (tester) async {
      final _WaitStoreBilling store = _WaitStoreBilling(
        heldProduct: 'business_monthly',
      )..changeTiming = StoreChangeTiming.atRenewal;
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final int readsBefore = store.entitlementReads;

      final MagicStarterStorePurchaseOutcome outcome = await controller
          .purchaseInStoreAndWait(_product(controller, 'pro_annual'));

      expect(outcome, MagicStarterStorePurchaseOutcome.deferred);
      expect(store.entitlementReads, readsBefore);
      expect(controller.entitlementSnapshot.currentPeriodEnd, store.periodEnd);
      expect(controller.awaitingProductKey, isNull);
      expect(controller.canPurchaseViaStore, isTrue);
      controller.dispose();
    });

    testWidgets('the rail decides the timing, not a guess from the catalogue: '
        'immediate and unknown both poll', (tester) async {
      // A held business product moving to pro looks like a downgrade from the
      // catalogue's order, and used to be deferred on that guess. The rail is
      // the one that knows what the store will do, so its answer wins.
      for (final StoreChangeTiming? timing in <StoreChangeTiming?>[
        StoreChangeTiming.immediate,
        null,
      ]) {
        final _WaitStoreBilling store = _WaitStoreBilling(
          heldProduct: 'business_monthly',
        )..changeTiming = timing;
        final MagicStarterBillingController controller = await loaded(
          store,
          isOwnerReader: () => true,
          storeFundedTeamReader: () async => null,
        );
        MagicStarterStorePurchaseOutcome? outcome;
        unawaited(
          controller
              .purchaseInStoreAndWait(_product(controller, 'pro_monthly'))
              .then(
                (MagicStarterStorePurchaseOutcome value) => outcome = value,
              ),
        );
        await tester.pump();

        expect(outcome, isNull, reason: '$timing is polled for');
        await tester.pump(const Duration(seconds: 1));
        expect(store.entitlementReads, 2, reason: '$timing reads at 1 s');

        controller.cancelWait();
        await tester.pump();
        expect(outcome, MagicStarterStorePurchaseOutcome.abandoned);
        controller.dispose();
      }
    });

    testWidgets('cancelling the wait stops every read and leaves no timer', (
      tester,
    ) async {
      final _WaitStoreBilling store = _WaitStoreBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      MagicStarterStorePurchaseOutcome? outcome;
      unawaited(
        controller
            .purchaseInStoreAndWait(_product(controller, 'pro_annual'))
            .then((MagicStarterStorePurchaseOutcome value) => outcome = value),
      );
      await tester.pump(const Duration(seconds: 1));
      final int readsBefore = store.entitlementReads;

      controller.cancelWait();
      await tester.pump();

      expect(outcome, MagicStarterStorePurchaseOutcome.abandoned);
      await tester.pump(const Duration(seconds: 120));
      expect(store.entitlementReads, readsBefore);
      controller.dispose();
    });

    testWidgets('a session switch abandons the wait with the rest of the old '
        'team\'s state', (tester) async {
      final _WaitStoreBilling store = _WaitStoreBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      MagicStarterStorePurchaseOutcome? outcome;
      unawaited(
        controller
            .purchaseInStoreAndWait(_product(controller, 'pro_annual'))
            .then((MagicStarterStorePurchaseOutcome value) => outcome = value),
      );
      await tester.pump(const Duration(seconds: 1));

      await controller.resetForSession();
      await tester.pump();

      expect(outcome, MagicStarterStorePurchaseOutcome.abandoned);
      expect(controller.awaitingProductKey, isNull);
      await tester.pump(const Duration(seconds: 120));
      controller.dispose();
    });

    testWidgets('a pending purchase throws for the screen to report, then '
        'polls and releases the store gate after 60 s', (tester) async {
      final _WaitStoreBilling store = _WaitStoreBilling(
        purchaseError: const BillingException(
          'Awaiting approval.',
          code: BillingErrorCode.pending,
        ),
      );
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      final int readsBefore = store.entitlementReads;

      await expectLater(
        controller.purchaseInStoreAndWait(_product(controller, 'pro_annual')),
        throwsA(isA<BillingException>()),
      );
      expect(controller.awaitingProductKey, 'pro_annual');

      await tester.pump(const Duration(seconds: 1));
      expect(store.entitlementReads, readsBefore + 1);

      await tester.pump(const Duration(seconds: 58));
      expect(controller.canPurchaseViaStore, isFalse);

      await tester.pump(const Duration(seconds: 1));
      // Parental approval can take days. A gate held shut for that long hides
      // the store from a customer who has already been told it is pending.
      expect(controller.awaitingProductKey, isNull);
      expect(controller.canPurchaseViaStore, isTrue);
      expect(store.entitlementReads, readsBefore + 6);
      await tester.pump(const Duration(seconds: 120));
      expect(store.entitlementReads, readsBefore + 6);
      controller.dispose();
    });

    testWidgets('a second tap refused as already waiting starts no second '
        'poll', (tester) async {
      final _WaitStoreBilling store = _WaitStoreBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      unawaited(
        controller.purchaseInStoreAndWait(_product(controller, 'pro_annual')),
      );
      await tester.pump();

      await expectLater(
        controller.purchaseInStoreAndWait(_product(controller, 'pro_monthly')),
        throwsA(isA<BillingException>()),
      );
      final int readsBefore = store.entitlementReads;
      await tester.pump(const Duration(seconds: 1));

      expect(store.entitlementReads, readsBefore + 1, reason: 'one poll only');
      expect(store.purchasedKeys, <String>['pro_annual']);
      await tester.pump(const Duration(seconds: 60));
      controller.dispose();
    });

    testWidgets('a read that differs from the pre-sheet snapshot releases the '
        'gate even when it names no catalogue product', (tester) async {
      // A Play purchase the producer can only name by its bare store id
      // decodes with `product: null`, so waiting for the key never ends.
      final _WaitStoreBilling store = _WaitStoreBilling(
        changeOnRead: 2,
        changeTo: 'pro',
      )..bareStoreProduct = true;
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      MagicStarterStorePurchaseOutcome? outcome;
      unawaited(
        controller
            .purchaseInStoreAndWait(_product(controller, 'pro_annual'))
            .then((MagicStarterStorePurchaseOutcome value) => outcome = value),
      );
      await tester.pump();
      expect(controller.awaitingProductKey, 'pro_annual');

      await tester.pump(const Duration(seconds: 1));

      expect(controller.entitlementSnapshot.product, isNull);
      expect(controller.awaitingProductKey, isNull);
      expect(controller.canPurchaseViaStore, isTrue);
      expect(outcome, MagicStarterStorePurchaseOutcome.confirmed);
      controller.dispose();
    });

    testWidgets('the 60 s window releases the gate even after the screen '
        'closed and stopped polling', (tester) async {
      final _WaitStoreBilling store = _WaitStoreBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      unawaited(
        controller.purchaseInStoreAndWait(_product(controller, 'pro_annual')),
      );
      await tester.pump(const Duration(seconds: 1));

      // The screen closes: no poll is left to time the wait out.
      controller.cancelWait();
      await tester.pump(const Duration(seconds: 58));
      expect(controller.awaitingProductKey, 'pro_annual');

      await tester.pump(const Duration(seconds: 1));

      expect(controller.awaitingProductKey, isNull);
      expect(controller.canPurchaseViaStore, isTrue);
      controller.dispose();
    });

    testWidgets('the remount read releases the gate when the entitlement moved '
        'while nobody was polling', (tester) async {
      final _WaitStoreBilling store = _WaitStoreBilling();
      final MagicStarterBillingController controller = await loaded(
        store,
        isOwnerReader: () => true,
        storeFundedTeamReader: () async => null,
      );
      unawaited(
        controller.purchaseInStoreAndWait(_product(controller, 'pro_annual')),
      );
      await tester.pump();
      controller.cancelWait();

      // The webhook lands, as the bare store id, while the screen is closed.
      store
        ..heldProduct = 'pro'
        ..bareStoreProduct = true;
      await controller.loadEntitlement();

      expect(controller.awaitingProductKey, isNull);
      controller.dispose();
    });
  });
}

/// The catalogue product named [key], from what [controller] loaded.
MagicStarterProduct _product(
  MagicStarterBillingController controller,
  String key,
) {
  return <MagicStarterProduct>[
    for (final MagicStarterPlan plan in controller.plans) ...plan.products,
  ].firstWhere((MagicStarterProduct product) => product.key == key);
}

/// A store build whose entitlement can MOVE between reads, so the wait has
/// something to observe, and whose price read is scripted.
///
/// Counts every entitlement read, because "stops polling" and "skips the poll"
/// are both claims about how many reads happened and not about what the screen
/// shows.
class _WaitStoreBilling extends _StorePurchaseBilling {
  _WaitStoreBilling({
    super.purchaseResult,
    super.purchaseError,
    this.heldProduct,
    this.changeOnRead,
    this.changeTo,
    this.offers = const <String, StoreProductOffer>{},
    this.offersError,
  });

  /// The catalogue key the entitlement reports, or `null` for a customer
  /// holding nothing.
  String? heldProduct;

  /// The 1-based read number at which [heldProduct] becomes [changeTo], which
  /// models the backend's webhook landing between two polls.
  final int? changeOnRead;

  /// The key the entitlement moves to on [changeOnRead].
  final String? changeTo;

  /// What the store answers for a price read.
  Map<String, StoreProductOffer> offers;

  /// A failure raised instead of [offers].
  final BillingException? offersError;

  /// The paid period's end, constant across reads so that a changed product,
  /// not a changed date, is what a test observes.
  final DateTime periodEnd = DateTime.utc(2026, 7, 1);

  /// How many times the entitlement was read, the mount's own read included.
  int entitlementReads = 0;

  /// Reports the held product with NO catalogue key, the way the producer
  /// answers a Play purchase it can name only by its bare store id.
  bool bareStoreProduct = false;

  /// Every key list passed to [products], in call order.
  final List<List<String>> requestedKeys = <List<String>>[];

  @override
  Future<BillingEntitlement> currentEntitlement() async {
    entitlementReads++;
    if (changeOnRead != null && entitlementReads >= changeOnRead!) {
      heldProduct = changeTo;
    }
    final String? held = heldProduct;

    return BillingEntitlement(
      plan: held?.split('_').first ?? 'free',
      productKey: bareStoreProduct ? null : held,
      provider: held == null ? BillingProvider.none : BillingProvider.appStore,
      currentPeriodEnd: held == null ? null : periodEnd,
      raw: const <String, dynamic>{},
    );
  }

  @override
  Future<Map<String, StoreProductOffer>> products(
    List<String> productKeys,
  ) async {
    requestedKeys.add(productKeys);
    final BillingException? error = offersError;
    if (error != null) throw error;

    return offers;
  }
}

/// A read contract that serves neither rail, modelling a build with no purchase
/// path at all.
class _ReadOnlyBilling implements BillingService {
  @override
  Future<BillingEntitlement> currentEntitlement() async =>
      const BillingEntitlement(plan: 'tier-b', raw: <String, dynamic>{});

  @override
  Future<List<Map<String, dynamic>>> getPlans() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<UsageStat>> getUsage() async => const <UsageStat>[];

  @override
  Future<BillingInvoicesPage> getInvoices({String? cursor}) async =>
      const BillingInvoicesPage(invoices: <Invoice>[], nextCursor: null);

  @override
  Future<PaymentMethod> getPaymentMethod() async => const PaymentMethod();
}

/// A read contract for the GATE cases: it serves no rail, and its entitlement
/// carries whichever [ManageVia] the case needs.
///
/// The four reads besides the entitlement answer empty, because no gate looks at
/// a plan row, a meter, an invoice or a card. What a gate does look at is which
/// rails the build serves, which is why this comes in three subclasses rather
/// than as one fake serving both: a fake that always serves both can never model
/// a build that serves one, and "no rail in this build" is a refusal every gate
/// here carries.
class _GateBilling implements BillingService {
  _GateBilling({
    this.manageVia = ManageVia.none,
    this.resolveEntitlement = true,
  });

  /// Where the server says management lives.
  final ManageVia manageVia;

  /// Whether the entitlement read answers at all. `false` fails it, which is how
  /// a case reaches the permanently unresolved state.
  final bool resolveEntitlement;

  @override
  Future<BillingEntitlement> currentEntitlement() async {
    if (!resolveEntitlement) {
      throw const BillingException('entitlement read failed');
    }

    return BillingEntitlement(
      plan: 'tier-b',
      manageVia: manageVia,
      raw: const <String, dynamic>{},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPlans() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<UsageStat>> getUsage() async => const <UsageStat>[];

  @override
  Future<BillingInvoicesPage> getInvoices({String? cursor}) async =>
      const BillingInvoicesPage(invoices: <Invoice>[], nextCursor: null);

  @override
  Future<PaymentMethod> getPaymentMethod() async => const PaymentMethod();
}

/// The web rail's four calls, none of which a gate invokes: serving the contract
/// is the whole point, because its presence IS the availability answer.
mixin _WebRailStubs implements WebBillingService {
  @override
  Future<BillingCheckoutSession> checkout({
    required String productKey,
    required String successUrl,
    required String cancelUrl,
  }) => throw UnimplementedError();

  @override
  Future<void> swap({required String productKey}) => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();

  @override
  Future<String> openPortal({String? returnUrl}) => throw UnimplementedError();
}

/// The store rail's calls, on the same terms as [_WebRailStubs]. [store] is
/// left to the class, because which store a rail sells through is a gate input.
mixin _StoreRailStubs implements StoreBillingService {
  @override
  Future<void> identify(String appUserId) => throw UnimplementedError();

  @override
  Future<bool> purchase(String productKey, {PurchaseContext? context}) =>
      throw UnimplementedError();

  @override
  StoreChangeTiming? get lastChangeTiming => null;

  @override
  Future<Map<String, StoreProductOffer>> products(
    List<String> productKeys,
  ) async => const <String, StoreProductOffer>{};

  @override
  Future<bool> restore() => throw UnimplementedError();

  @override
  Future<void> openStoreManagement() => throw UnimplementedError();
}

/// A build that serves the WEB rail only, which is every browser and desktop
/// build.
class _WebGateBilling extends _GateBilling with _WebRailStubs {
  _WebGateBilling({super.manageVia, super.resolveEntitlement});
}

/// A store build reading the PRODUCER's catalogue fixture, recording every
/// purchase, so a case can assert the product key and the tier order that
/// reach the rail.
class _StorePurchaseBilling extends _GateBilling with _StoreRailStubs {
  _StorePurchaseBilling({this.purchaseResult = true, this.purchaseError});

  /// What the store reports for a completed sheet.
  final bool purchaseResult;

  /// A rail failure to raise instead of answering.
  final BillingException? purchaseError;

  /// The catalogue key the entitlement reports, moved by a case to model the
  /// webhook landing.
  String? entitlementProductKey;

  /// Every key passed to [purchase], in call order.
  final List<String> purchasedKeys = <String>[];

  /// Every context passed to [purchase], in call order.
  final List<PurchaseContext?> contexts = <PurchaseContext?>[];

  /// When the rail says the last purchase takes effect, set by a case.
  StoreChangeTiming? changeTiming;

  @override
  StoreChangeTiming? get lastChangeTiming => changeTiming;

  @override
  ManageVia get store => ManageVia.appStore;

  @override
  Future<BillingEntitlement> currentEntitlement() async {
    return BillingEntitlement(
      plan: 'free',
      productKey: entitlementProductKey,
      raw: const <String, dynamic>{},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPlans() async {
    final File file = File(
      '${Directory.current.path}/test/fixtures/wire/billing-plans.json',
    );
    final Map<String, dynamic> body =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    return (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<bool> purchase(String productKey, {PurchaseContext? context}) async {
    purchasedKeys.add(productKey);
    contexts.add(context);
    final BillingException? error = purchaseError;
    if (error != null) throw error;

    return purchaseResult;
  }
}

/// A build that serves the STORE rail only, which is iOS and Android.
class _StoreGateBilling extends _GateBilling with _StoreRailStubs {
  _StoreGateBilling({super.manageVia, this.rail = ManageVia.appStore});

  /// Which store this rail sells through, independent of [manageVia]: the two
  /// disagreeing is the cross-store case the store gate has to refuse.
  final ManageVia rail;

  @override
  ManageVia get store => rail;
}
