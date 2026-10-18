import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';
import 'package:magic_starter/magic_starter.dart';

/// The wire body of `GET /billing/campaign`, exactly as the backend package
/// serializes it, window included.
Map<String, dynamic> _fixture() {
  final String raw = File(
    '${Directory.current.path}/test/fixtures/wire/billing-campaign.json',
  ).readAsStringSync();

  return jsonDecode(raw) as Map<String, dynamic>;
}

/// The fixture's campaign with its window moved around the real clock, because
/// the banner hides a campaign that is not running and the fixture's own dates
/// are a fixed calendar week. Open by default; [startsIn] and [endsIn] are
/// offsets from now.
Map<String, dynamic> _wire({
  Duration startsIn = const Duration(days: -1),
  Duration endsIn = const Duration(days: 1),
}) {
  final Map<String, dynamic> data = Map<String, dynamic>.of(
    _fixture()['data'] as Map<String, dynamic>,
  );
  final DateTime now = DateTime.now().toUtc();
  data['starts_at'] = now.add(startsIn).toIso8601String();
  data['ends_at'] = now.add(endsIn).toIso8601String();

  return <String, dynamic>{'data': data};
}

/// The wire body with its campaign renamed, for the "a new campaign shows
/// again" cases.
Map<String, dynamic> _wireWithId(String id, {String? headline}) {
  final Map<String, dynamic> data = Map<String, dynamic>.of(
    (_wire()['data'] as Map<String, dynamic>),
  );
  data['id'] = id;
  if (headline != null) {
    data['headline'] = <String, String>{'en': headline};
  }

  return <String, dynamic>{'data': data};
}

/// The read contract alone, recording every read so a case can prove the banner
/// never fires the billing screen's six. It serves no purchase rail, which is
/// what a store or desktop build resolves to.
class _NoRailBilling implements BillingService {
  final List<String> reads = <String>[];

  @override
  Future<BillingEntitlement> currentEntitlement() async {
    reads.add('entitlement');

    return BillingEntitlement.fromMap(<String, dynamic>{
      'plan': 'free',
      'plan_status': 'none',
      'subscribed': false,
      'renews': null,
      'cycle': null,
      'provider': 'none',
      'manage_via': 'none',
      'manage_url': null,
      'ai_analysis_trials_remaining': null,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getPlans() async {
    reads.add('plans');

    return const <Map<String, dynamic>>[];
  }

  @override
  Future<List<UsageStat>> getUsage() async {
    reads.add('usage');

    return const <UsageStat>[];
  }

  @override
  Future<BillingInvoicesPage> getInvoices({String? cursor}) async {
    reads.add('invoices');

    return const BillingInvoicesPage(invoices: <Invoice>[], nextCursor: null);
  }

  @override
  Future<PaymentMethod> getPaymentMethod() async {
    reads.add('payment_method');

    return const PaymentMethod(available: true);
  }
}

/// The reads plus the WEB rail: the build where a campaign can be acted on.
class _WebRailBilling extends _NoRailBilling implements WebBillingService {
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

/// A signed-in account, for the per-account dismissal key.
class _User extends Model with Authenticatable {
  @override
  String get table => 'users';

  @override
  String get resource => 'users';

  @override
  List<String> get fillable => <String>['id'];
}

_User _user(int id) {
  final _User user = _User();
  user.fill(<String, dynamic>{'id': id});
  user.exists = true;

  return user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLogManager logs;
  late List<String> requests;
  late FutureOr<Map<String, dynamic>> Function() campaignBody;

  setUp(() {
    MagicApp.reset();
    Magic.flush();
    logs = Log.fake();
    Vault.fake();
    Auth.fake(user: _user(1));

    Config.set('magic_starter.features.billing', true);

    requests = <String>[];
    campaignBody = _wire;
    Http.fake((request) async {
      requests.add(request.url);

      return Http.response(await campaignBody());
    });
  });

  tearDown(() {
    Http.unfake();
    Vault.unfake();
    Auth.unfake();
    Log.unfake();
    MagicApp.reset();
    Magic.flush();
  });

  MagicStarterBillingController register({
    BillingService? billing,
    bool? isOwner,
  }) {
    return Magic.put(
      MagicStarterBillingController(
        usageCopy: (List<UsageStat> stats) => stats,
        formatNumber: (int value) => value.toString(),
        isOwnerReader: isOwner == null ? null : () => isOwner,
        billingService: billing ?? _WebRailBilling(),
      ),
    );
  }

  int campaignRequests() =>
      requests.where((String url) => url.contains('billing/campaign')).length;

  group('MagicStarterBillingController.loadCampaign', () {
    test('reads the campaign once and keeps it on the instance', () async {
      final MagicStarterBillingController controller = register();

      await controller.loadCampaign();
      await controller.loadCampaign();

      expect(controller.campaign?.id, 'camp-1');
      expect(campaignRequests(), 1);
      expect(requests.single, '/billing/campaign');
    });

    test('is a null campaign for `data: null`', () async {
      campaignBody = () => <String, dynamic>{'data': null};
      final MagicStarterBillingController controller = register();

      await controller.loadCampaign();

      expect(controller.campaign, isNull);
      expect(campaignRequests(), 1);
    });

    test('asks nothing while the billing feature is off', () async {
      Config.set('magic_starter.features.billing', false);
      final MagicStarterBillingController controller = register();

      await controller.loadCampaign();

      expect(controller.campaign, isNull);
      expect(campaignRequests(), 0);
    });

    test('asks nothing when the web rail cannot purchase', () async {
      final MagicStarterBillingController noRail = register(
        billing: _NoRailBilling(),
      );
      await noRail.loadCampaign();

      final MagicStarterBillingController notOwner = register(isOwner: false);
      await notOwner.loadCampaign();

      expect(noRail.campaign, isNull);
      expect(notOwner.campaign, isNull);
      expect(campaignRequests(), 0);
    });

    test('keeps no campaign when the read is refused', () async {
      Http.fake((request) {
        requests.add(request.url);

        return Http.response(<String, dynamic>{'message': 'Nope.'}, 500);
      });
      final MagicStarterBillingController controller = register();

      await controller.loadCampaign();

      expect(controller.campaign, isNull);
      logs.assertLogged(
        'warning',
        '[MagicStarterBillingController.loadCampaign] status 500',
      );
    });

    test('a 404 is no campaign, without a warning', () async {
      Http.fake((request) {
        requests.add(request.url);

        return Http.response(<String, dynamic>{'message': 'Not Found.'}, 404);
      });
      final MagicStarterBillingController controller = register();

      await controller.loadCampaign();
      await controller.loadCampaign();

      expect(controller.campaign, isNull);
      expect(campaignRequests(), 1);
      logs.assertNothingLogged();
    });

    test('does not fire any of the six billing reads', () async {
      final _WebRailBilling billing = _WebRailBilling();
      final MagicStarterBillingController controller = register(
        billing: billing,
      );

      await controller.loadCampaign();

      expect(billing.reads, isEmpty);
    });

    test('resetForSession drops it and lets the next read repeat', () async {
      final MagicStarterBillingController controller = register();
      await controller.loadCampaign();
      expect(controller.campaign, isNotNull);

      campaignBody = () => <String, dynamic>{'data': null};
      await controller.resetForSession();

      expect(controller.campaign, isNull);

      campaignBody = () => _wireWithId('camp-2');
      await controller.loadCampaign();

      expect(controller.campaign?.id, 'camp-2');
      expect(campaignRequests(), 2);
    });

    test('a read a reset superseded never publishes', () async {
      final Completer<Map<String, dynamic>> held =
          Completer<Map<String, dynamic>>();
      campaignBody = () => held.future;
      final MagicStarterBillingController controller = register();

      final Future<void> stale = controller.loadCampaign();
      await Future<void>.delayed(Duration.zero);
      campaignBody = () => <String, dynamic>{'data': null};
      await controller.resetForSession();
      held.complete(_wireWithId('camp-old'));
      await stale;

      expect(controller.campaign, isNull);
    });
  });
}
