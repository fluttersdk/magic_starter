import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_payments/magic_payments.dart';
import 'package:magic_starter/magic_starter.dart';

/// The package's own English copy, served for every locale, so the banner
/// renders real labels whichever language the case selects.
class _ShippedLoader implements TranslationLoader {
  const _ShippedLoader();

  @override
  Future<Map<String, dynamic>> load(Locale _) async {
    final raw = File(
      '${Directory.current.path}/assets/stubs/install/en.stub',
    ).readAsStringSync();

    return _flatten(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Map<String, dynamic> _flatten(
    Map<String, dynamic> json, [
    String prefix = '',
  ]) {
    final Map<String, dynamic> result = <String, dynamic>{};

    for (final MapEntry<String, dynamic> entry in json.entries) {
      final String key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';

      if (entry.value is Map<String, dynamic>) {
        result.addAll(_flatten(entry.value as Map<String, dynamic>, key));
      } else {
        result[key] = entry.value;
      }
    }

    return result;
  }
}

/// The wire body of `GET /billing/campaign`, exactly as the backend package
/// serializes it.
Map<String, dynamic> _wire() {
  final String raw = File(
    '${Directory.current.path}/test/fixtures/wire/billing-campaign.json',
  ).readAsStringSync();

  return jsonDecode(raw) as Map<String, dynamic>;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> requests;
  late FutureOr<Map<String, dynamic>> Function() campaignBody;
  const Key bannerKey = Key('campaign-banner');

  setUp(() async {
    MagicApp.reset();
    Magic.flush();
    Log.fake();
    Vault.fake();

    Config.set('magic_starter.features.billing', true);

    requests = <String>[];
    campaignBody = _wire;
    Http.fake((request) async {
      requests.add(request.url);

      return Http.response(await campaignBody());
    });

    Translator.instance.setLoader(const _ShippedLoader());
    await Translator.instance.setLocale(const Locale('en'));
  });

  tearDown(() {
    MagicStarterCampaignBanner.debugNavigateTo = null;
    Http.unfake();
    Vault.unfake();
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

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WindTheme(
          data: WindThemeData(),
          child: const Scaffold(
            body: MagicStarterCampaignBanner(key: bannerKey),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  int campaignRequests() =>
      requests.where((String url) => url.contains('billing/campaign')).length;

  final Finder seePlans = find.text('See plans');
  final Finder dismiss = find.text('Dismiss');
  final Finder headline = find.textContaining('Pro is 20% off this week');

  group('MagicStarterCampaign', () {
    test('decodes the wire fixture', () {
      final MagicStarterCampaign campaign = MagicStarterCampaign.fromMap(
        (_wire()['data'] as Map<String, dynamic>),
      );

      expect(campaign.id, 'camp-1');
      expect(campaign.startsAt, DateTime.utc(2026, 11, 1));
      expect(campaign.endsAt, DateTime.utc(2026, 11, 8));
      expect(campaign.products, <String>['pro_monthly', 'pro_annual']);
      expect(campaign.discount.type, MagicStarterCampaignDiscountType.percent);
      expect(campaign.discount.value, 20);
      expect(campaign.discount.currency, isNull);
      expect(campaign.coversProduct('pro_annual'), isTrue);
      expect(campaign.coversProduct('business_annual'), isFalse);
    });

    test('decodes an amount discount with its currency', () {
      final Map<String, dynamic> data = Map<String, dynamic>.of(
        (_wire()['data'] as Map<String, dynamic>),
      );
      data['discount'] = <String, dynamic>{
        'type': 'amount',
        'value': 500,
        'currency': 'USD',
      };

      final MagicStarterCampaign campaign = MagicStarterCampaign.fromMap(data);

      expect(campaign.discount.type, MagicStarterCampaignDiscountType.amount);
      expect(campaign.discount.value, 500);
      expect(campaign.discount.currency, 'USD');
    });

    test('picks the reader locale, then the default, then any copy', () {
      final MagicStarterCampaign campaign = MagicStarterCampaign.fromMap(
        (_wire()['data'] as Map<String, dynamic>),
      );

      expect(campaign.headlineFor('tr'), 'Pro bu hafta %20 indirimli');
      expect(
        campaign.bodyFor('tr'),
        'Fiyatı korumak için pazardan önce yükselt.',
      );
      expect(campaign.headlineFor('fr'), 'Pro is 20% off this week');
      expect(
        campaign.bodyFor('fr'),
        'Upgrade before Sunday to keep the price.',
      );

      final Map<String, dynamic> data = Map<String, dynamic>.of(
        (_wire()['data'] as Map<String, dynamic>),
      );
      data['headline'] = <String, String>{'de': 'Nur diese Woche'};
      data['body'] = <String, String>{};
      final MagicStarterCampaign onlyGerman = MagicStarterCampaign.fromMap(
        data,
      );

      expect(onlyGerman.headlineFor('fr'), 'Nur diese Woche');
      expect(onlyGerman.bodyFor('fr'), '');
    });
  });

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

  group('MagicStarterCampaignBanner', () {
    testWidgets('shows the headline and body in the app locale', (
      tester,
    ) async {
      register();
      await Translator.instance.setLocale(const Locale('tr'));

      await mount(tester);

      expect(find.textContaining('Pro bu hafta %20 indirimli'), findsOneWidget);
      expect(
        find.textContaining('Fiyatı korumak için pazardan önce yükselt.'),
        findsOneWidget,
      );
      expect(seePlans, findsOneWidget);
      expect(dismiss, findsOneWidget);
    });

    testWidgets('falls back to the default locale copy', (tester) async {
      register();
      await Translator.instance.setLocale(const Locale('fr'));

      await mount(tester);

      expect(headline, findsOneWidget);
      expect(
        find.textContaining('Upgrade before Sunday to keep the price.'),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing for a null campaign', (tester) async {
      campaignBody = () => <String, dynamic>{'data': null};
      register();

      await mount(tester);

      expect(campaignRequests(), 1);
      expect(find.byType(MSUpdateBanner), findsNothing);
      expect(seePlans, findsNothing);
    });

    testWidgets('renders nothing, and asks nothing, without a web rail', (
      tester,
    ) async {
      register(billing: _NoRailBilling());

      await mount(tester);

      expect(campaignRequests(), 0);
      expect(find.byType(MSUpdateBanner), findsNothing);
    });

    testWidgets('renders nothing for a member who is not the owner', (
      tester,
    ) async {
      register(isOwner: false);

      await mount(tester);

      expect(campaignRequests(), 0);
      expect(find.byType(MSUpdateBanner), findsNothing);
    });

    testWidgets('renders nothing when no billing controller is registered', (
      tester,
    ) async {
      await mount(tester);

      expect(campaignRequests(), 0);
      expect(find.byType(MSUpdateBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounting never fires the six billing reads', (tester) async {
      final _WebRailBilling billing = _WebRailBilling();
      register(billing: billing);

      await mount(tester);

      expect(headline, findsOneWidget);
      expect(billing.reads, isEmpty);
      expect(campaignRequests(), 1);
    });

    testWidgets('See plans navigates to the billing route', (tester) async {
      final List<String> paths = <String>[];
      MagicStarterCampaignBanner.debugNavigateTo = paths.add;
      register();
      await mount(tester);

      await tester.tap(seePlans);
      await settle(tester);

      expect(paths, <String>[MagicStarterConfig.billingRoute()]);
    });

    testWidgets('dismissing hides it and remembers the campaign id', (
      tester,
    ) async {
      register();
      await mount(tester);

      await tester.tap(dismiss);
      await settle(tester);

      expect(headline, findsNothing);
      expect(
        await Vault.get(MagicStarterCampaignBanner.dismissedCampaignKey),
        'camp-1',
      );

      // A fresh mount (a layout rebuilt, the app reopened) stays hidden.
      await tester.pumpWidget(const SizedBox());
      await mount(tester);

      expect(headline, findsNothing);
    });

    testWidgets('a dismissed campaign stays hidden, a new one shows again', (
      tester,
    ) async {
      Vault.fake(<String, String>{
        MagicStarterCampaignBanner.dismissedCampaignKey: 'camp-1',
      });
      register();
      await mount(tester);

      expect(headline, findsNothing);

      campaignBody = () => _wireWithId('camp-2');
      final MagicStarterBillingController controller =
          Magic.find<MagicStarterBillingController>();
      await controller.resetForSession();
      await settle(tester);

      expect(headline, findsOneWidget);
    });

    testWidgets('a team switch drops it, then shows the next team\'s', (
      tester,
    ) async {
      final MagicStarterBillingController controller = register();
      await mount(tester);
      expect(headline, findsOneWidget);

      final Completer<Map<String, dynamic>> next =
          Completer<Map<String, dynamic>>();
      campaignBody = () => next.future;
      unawaited(controller.resetForSession());
      await settle(tester);

      expect(controller.campaign, isNull);
      expect(headline, findsNothing);

      next.complete(_wireWithId('camp-2', headline: 'Business is 10% off'));
      await settle(tester);

      expect(find.textContaining('Business is 10% off'), findsOneWidget);
      expect(campaignRequests(), 2);
    });

    testWidgets('keeps nothing across controllers', (tester) async {
      register();
      await mount(tester);
      expect(headline, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      Magic.delete<MagicStarterBillingController>();
      campaignBody = () => <String, dynamic>{'data': null};
      register();
      await mount(tester);

      expect(headline, findsNothing);
    });
  });
}
