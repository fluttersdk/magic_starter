// Pins the one property this controller exists for: SIX independent reads that
// degrade INDEPENDENTLY. The whole reason it refuses `MagicStateMixin` is that
// one shared state slot would let any single failing read blank the other five,
// so the failure cases below are written one read at a time. A test that failed
// all six together would pass just as happily against the shared-slot design
// this file is guarding against.
import 'dart:async';

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

  /// Held open to park every read before it resolves.
  Completer<void>? gate;

  /// Every read that has STARTED, in dispatch order.
  final List<String> started = <String>[];

  Future<void> _enter(String read) async {
    started.add(read);
    final Completer<void>? held = gate;
    if (held != null) await held.future;
  }

  @override
  Future<BillingEntitlement> currentEntitlement() async {
    await _enter(_entitlementRead);
    if (failEntitlement) {
      throw const BillingException('entitlement read failed');
    }

    return const BillingEntitlement(
      plan: 'tier-b',
      manageVia: ManageVia.portal,
      manageUrl: 'https://example.test/manage',
      aiAnalysisTrialsRemaining: null,
      raw: <String, dynamic>{'plan': 'tier-b'},
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
    required String plan,
    String? successUrl,
    String? cancelUrl,
  }) => throw UnimplementedError();

  @override
  Future<void> swap({required String plan}) => throw UnimplementedError();

  @override
  Future<void> cancel() => throw UnimplementedError();

  @override
  Future<String> openPortal({String? returnUrl}) => throw UnimplementedError();

  @override
  Future<void> identify(String appUserId) => throw UnimplementedError();

  @override
  Future<bool> purchase({required String plan}) => throw UnimplementedError();

  @override
  Future<bool> restore() => throw UnimplementedError();

  @override
  Future<void> openStoreManagement() => throw UnimplementedError();
}

/// The consumer's copy table: it names `seats` and deliberately has no word for
/// `requests_this_month`.
///
/// Modelled on a real consumer helper: every stat the producer reported comes
/// back, in the order it sent them, and one this table cannot name keeps a NULL
/// label rather than falling back to its wire key.
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
}

/// A read contract that serves neither rail, modelling a build with no purchase
/// path at all.
class _ReadOnlyBilling implements BillingService {
  @override
  Future<BillingEntitlement> currentEntitlement() async =>
      const BillingEntitlement(
        plan: 'tier-b',
        aiAnalysisTrialsRemaining: null,
        raw: <String, dynamic>{},
      );

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
