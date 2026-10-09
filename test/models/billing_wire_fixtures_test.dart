// Decodes the PRODUCER's own bytes. Both files under `test/fixtures/wire/` are
// copied verbatim from magic-starter-laravel's `tests/Fixtures/wire/`, where the
// backend's own suite writes them from a real response. A map typed here would
// agree with whatever these decoders happen to read; the producer's output
// cannot, so a field renamed on one side fails here instead of on a customer's
// billing screen.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_payments/magic_payments.dart';
import 'package:magic_starter/magic_starter.dart';

/// Reads one producer fixture and unwraps its `data` envelope.
Object? _wire(String name) {
  final File file = File('${Directory.current.path}/test/fixtures/wire/$name');
  final Map<String, dynamic> body =
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  return body['data'];
}

void main() {
  group('billing.json (GET /billing)', () {
    test('decodes into the entitlement the producer meant', () {
      final BillingEntitlement entitlement = BillingEntitlement.fromMap(
        _wire('billing.json')! as Map<String, dynamic>,
      );

      expect(entitlement.plan, 'pro');
      expect(entitlement.planStatus, PlanStatus.active);
      expect(entitlement.subscribed, isTrue);
      expect(entitlement.renews, isTrue);
      expect(entitlement.cycle, BillingCycle.annual);
      expect(entitlement.provider, BillingProvider.stripe);
      expect(entitlement.productId, 'price_pro_annual');
      expect(entitlement.productKey, 'pro_annual');
      expect(entitlement.manageVia, ManageVia.portal);
      expect(entitlement.manageUrl, isNull);
      expect(entitlement.currentPeriodEnd, DateTime.utc(2027));
      expect(entitlement.owned, isEmpty);
      expect(entitlement.balances, isEmpty);
      expect(entitlement.allowances['seats'], <String, dynamic>{
        'used': 3,
        'limit': 10,
      });
    });
  });

  group('billing-plans.json (GET /billing/plans)', () {
    late List<MagicStarterPlan> plans;

    setUp(() {
      plans = (_wire('billing-plans.json')! as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(MagicStarterPlan.fromMap)
          .toList();
    });

    test('keeps the tier rows in the producer order', () {
      expect(plans.map((MagicStarterPlan plan) => plan.id), <String>[
        'free',
        'pro',
        'business',
      ]);
    });

    test('decodes every product a tier row carries, sellable or not', () {
      final MagicStarterPlan pro = plans[1];

      expect(pro.products, hasLength(3));

      final MagicStarterProduct monthly = pro.products[0];
      expect(monthly.key, 'pro_monthly');
      expect(monthly.type, ProductType.subscription);
      expect(monthly.tier, 'pro');
      expect(monthly.cycle, BillingCycle.monthly);
      expect(monthly.sellable, isTrue);
      expect(monthly.storeIds.appStore, 'com.example.pro.monthly');
      expect(monthly.storeIds.play, 'pro:monthly');
      expect(monthly.webPrices['USD']?.amountMinor, 2900);
      expect(monthly.webPrices['USD']?.display, '29.00 USD');
      expect(monthly.webPrices['TRY']?.amountMinor, 99900);
      expect(monthly.webPrices['TRY']?.display, '999.00 TRY');

      final MagicStarterProduct annual = pro.products[1];
      expect(annual.key, 'pro_annual');
      expect(annual.cycle, BillingCycle.annual);
      expect(annual.sellable, isTrue);
      expect(annual.storeIds.appStore, isNull);
      expect(annual.storeIds.play, isNull);
      expect(annual.webPrices.keys, <String>['USD']);

      final MagicStarterProduct grandfathered = pro.products[2];
      expect(grandfathered.key, 'pro_monthly_2025');
      expect(grandfathered.sellable, isFalse);
      expect(grandfathered.storeIds.appStore, 'com.example.pro.monthly.2025');
      expect(grandfathered.storeIds.play, 'pro:monthly-2025');
    });

    test('decodes the cycles the web rail sells each tier on', () {
      expect(plans[0].cycles, isEmpty);
      expect(plans[1].cycles, <BillingCycle>[
        BillingCycle.monthly,
        BillingCycle.annual,
      ]);
      // Business is priced in a store only, so the web rail sells it on nothing.
      expect(plans[2].cycles, isEmpty);
    });

    test('a tier with no products and a product with no web price both '
        'decode empty rather than failing', () {
      expect(plans.first.products, isEmpty);

      final MagicStarterProduct business = plans[2].products.single;
      expect(business.key, 'business_monthly');
      expect(business.webPrices, isEmpty);
      expect(business.storeIds.appStore, 'com.example.business.monthly');
      expect(business.storeIds.play, isNull);
    });

    test('resolves the product a (tier, cycle) selection buys', () {
      expect(plans[1].productFor(BillingCycle.annual)?.key, 'pro_annual');
      expect(plans[1].productFor(BillingCycle.monthly)?.key, 'pro_monthly');
      // Business sells monthly only, so an Annual toggle still buys the one
      // product the tier has rather than nothing at all.
      expect(plans[2].productFor(BillingCycle.annual)?.key, 'business_monthly');
      expect(plans.first.productFor(BillingCycle.annual), isNull);
    });

    test('the web rail sells only the cycles the row lists', () {
      expect(plans[1].webProductFor(BillingCycle.annual)?.key, 'pro_annual');
      expect(plans[1].webProductFor(BillingCycle.monthly)?.key, 'pro_monthly');
      // A store-only product has no web cycle, so the web sells nothing.
      expect(plans[2].webProductFor(BillingCycle.monthly), isNull);
      expect(plans.first.webProductFor(BillingCycle.monthly), isNull);
    });

    test('a grandfathered product is never the one a selection buys', () {
      final MagicStarterPlan pro = plans[1];

      expect(
        pro.sellableProducts.map((MagicStarterProduct product) => product.key),
        <String>['pro_monthly', 'pro_annual'],
      );
      expect(pro.productFor(BillingCycle.monthly)?.key, 'pro_monthly');
    });
  });
}
