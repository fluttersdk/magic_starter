import 'package:flutter_test/flutter_test.dart';
import 'package:magic_starter/magic_starter.dart';

void main() {
  group('MagicStarterProduct.fromMap', () {
    test('an unknown type or cycle decodes to null, never to a guess', () {
      final MagicStarterProduct product = MagicStarterProduct.fromMap(
        <String, dynamic>{
          'key': 'pro_weekly',
          'type': 'rental',
          'tier': 'pro',
          'cycle': 'weekly',
        },
      );

      expect(product.key, 'pro_weekly');
      expect(product.type, isNull);
      expect(product.cycle, isNull);
    });

    test('prices sent as an empty JSON list (PHP\'s empty object) decode '
        'empty', () {
      final MagicStarterProduct product = MagicStarterProduct.fromMap(
        <String, dynamic>{
          'key': 'pro_monthly',
          'type': 'subscription',
          'tier': 'pro',
          'cycle': 'monthly',
          'prices': <String, dynamic>{'web': <dynamic>[]},
        },
      );

      expect(product.webPrices, isEmpty);
    });

    test('a malformed price entry is dropped, its siblings survive', () {
      final MagicStarterProduct product = MagicStarterProduct.fromMap(
        <String, dynamic>{
          'key': 'pro_monthly',
          'type': 'subscription',
          'tier': 'pro',
          'cycle': 'monthly',
          'prices': <String, dynamic>{
            'web': <String, dynamic>{
              'USD': <String, dynamic>{
                'amount_minor': 2900,
                'display': '29.00 USD',
              },
              'EUR': 'not a price',
            },
          },
        },
      );

      expect(product.webPrices.keys, <String>['USD']);
    });

    test('a product without a sellable flag is sellable, and without store ids '
        'names none', () {
      final MagicStarterProduct product =
          MagicStarterProduct.fromMap(<String, dynamic>{
            'key': 'pro_monthly',
            'type': 'subscription',
            'tier': 'pro',
            'cycle': 'monthly',
          });

      expect(product.sellable, isTrue);
      expect(product.storeIds.appStore, isNull);
      expect(product.storeIds.play, isNull);
    });

    test('an empty or non-string store id names no store product', () {
      final MagicStarterProduct product = MagicStarterProduct.fromMap(
        <String, dynamic>{
          'key': 'pro_monthly',
          'type': 'subscription',
          'tier': 'pro',
          'cycle': 'monthly',
          'sellable': false,
          'store_ids': <String, dynamic>{'app_store': '', 'play': 42},
        },
      );

      expect(product.sellable, isFalse);
      expect(product.storeIds.appStore, isNull);
      expect(product.storeIds.play, isNull);
    });
  });

  group('MagicStarterProduct.trialDays', () {
    MagicStarterProduct decode(Object? trialDays, {bool present = true}) {
      return MagicStarterProduct.fromMap(<String, dynamic>{
        'key': 'pro_monthly',
        'type': 'subscription',
        'tier': 'pro',
        'cycle': 'monthly',
        if (present) 'trial_days': trialDays,
      });
    }

    test('a whole number of days decodes as sent', () {
      expect(decode(14).trialDays, 14);
    });

    test('an absent trial_days is no trial', () {
      expect(decode(null, present: false).trialDays, 0);
    });

    test('a negative, fractional or non-numeric value is no trial', () {
      expect(decode(-7).trialDays, 0);
      expect(decode(7.5).trialDays, 0);
      expect(decode('14').trialDays, 0);
      expect(decode(null).trialDays, 0);
      expect(decode(true).trialDays, 0);
    });
  });

  group('MagicStarterPlan.products', () {
    test('a row without a products key decodes to no products', () {
      final MagicStarterPlan plan = MagicStarterPlan.fromMap(<String, dynamic>{
        'id': 'pro',
        'name': 'Pro',
      });

      expect(plan.products, isEmpty);
      expect(plan.productFor(BillingCycle.monthly), isNull);
    });

    test('a product without a key is dropped, because nothing can buy it', () {
      final MagicStarterPlan plan = MagicStarterPlan.fromMap(<String, dynamic>{
        'id': 'pro',
        'name': 'Pro',
        'products': <dynamic>[
          <String, dynamic>{
            'type': 'subscription',
            'tier': 'pro',
            'cycle': 'monthly',
          },
          <String, dynamic>{
            'key': 'pro_annual',
            'type': 'subscription',
            'tier': 'pro',
            'cycle': 'annual',
          },
        ],
      });

      expect(
        plan.products.map((MagicStarterProduct product) => product.key),
        <String>['pro_annual'],
      );
    });

    test('productFor ignores a one-off product when resolving a cycle', () {
      final MagicStarterPlan plan = MagicStarterPlan.fromMap(<String, dynamic>{
        'id': 'pro',
        'name': 'Pro',
        'products': <dynamic>[
          <String, dynamic>{
            'key': 'pro_lifetime',
            'type': 'non_consumable',
            'tier': 'pro',
          },
          <String, dynamic>{
            'key': 'pro_monthly',
            'type': 'subscription',
            'tier': 'pro',
            'cycle': 'monthly',
          },
        ],
      });

      expect(plan.productFor(BillingCycle.annual)?.key, 'pro_monthly');
    });

    test('productFor never names a product the tier no longer sells', () {
      // The grandfathered product comes FIRST and matches the cycle, so a
      // resolver that read every product would hand it to a purchase.
      final MagicStarterPlan plan = MagicStarterPlan.fromMap(<String, dynamic>{
        'id': 'pro',
        'name': 'Pro',
        'cycles': <String>['monthly'],
        'products': <dynamic>[
          <String, dynamic>{
            'key': 'pro_monthly_2025',
            'type': 'subscription',
            'tier': 'pro',
            'cycle': 'monthly',
            'sellable': false,
          },
          <String, dynamic>{
            'key': 'pro_annual',
            'type': 'subscription',
            'tier': 'pro',
            'cycle': 'annual',
          },
        ],
      });

      expect(plan.productFor(BillingCycle.monthly)?.key, 'pro_annual');
      expect(plan.webProductFor(BillingCycle.monthly), isNull);
      expect(plan.products, hasLength(2));
    });

    test('a tier selling nothing any more resolves no product at all', () {
      final MagicStarterPlan plan = MagicStarterPlan.fromMap(<String, dynamic>{
        'id': 'legacy',
        'name': 'Legacy',
        'products': <dynamic>[
          <String, dynamic>{
            'key': 'legacy_monthly',
            'type': 'subscription',
            'tier': 'legacy',
            'cycle': 'monthly',
            'sellable': false,
          },
        ],
      });

      expect(plan.sellableProducts, isEmpty);
      expect(plan.productFor(BillingCycle.monthly), isNull);
    });
  });
}
