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
  });
}
