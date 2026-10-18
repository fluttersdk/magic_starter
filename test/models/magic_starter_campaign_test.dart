import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';
import 'package:magic_starter/magic_starter.dart';

/// The `data` object of the wire body of `GET /billing/campaign`, exactly as
/// the backend package serializes it, as a copy a case can edit.
Map<String, dynamic> _data() {
  final String raw = File(
    '${Directory.current.path}/test/fixtures/wire/billing-campaign.json',
  ).readAsStringSync();

  return Map<String, dynamic>.of(
    (jsonDecode(raw) as Map<String, dynamic>)['data'] as Map<String, dynamic>,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MagicApp.reset();
    Magic.flush();
  });

  tearDown(() {
    MagicApp.reset();
    Magic.flush();
  });

  group('MagicStarterCampaign', () {
    test('decodes the wire fixture', () {
      final MagicStarterCampaign campaign = MagicStarterCampaign.fromMap(
        _data(),
      );

      expect(campaign.id, 'camp-1');
      expect(campaign.startsAt, DateTime.utc(2026, 11, 1));
      expect(campaign.endsAt, DateTime.utc(2026, 11, 8));
      expect(campaign.products, <String>['pro_monthly', 'pro_annual']);
      expect(campaign.discount.type, MagicStarterCampaignDiscountType.percent);
      expect(campaign.discount.value, 20);
      expect(campaign.discount.currency, isNull);
      expect(campaign.discount.currencyOptions, isEmpty);
      expect(campaign.coversProduct('pro_annual'), isTrue);
      expect(campaign.coversProduct('business_annual'), isFalse);
    });

    test('decodes an amount discount with its currency', () {
      final Map<String, dynamic> data = _data();
      data['discount'] = <String, dynamic>{
        'type': 'amount',
        'value': 500,
        'currency': 'USD',
      };

      final MagicStarterCampaign campaign = MagicStarterCampaign.fromMap(data);

      expect(campaign.discount.type, MagicStarterCampaignDiscountType.amount);
      expect(campaign.discount.value, 500);
      expect(campaign.discount.currency, 'USD');
      expect(campaign.discount.currencyOptions, isEmpty);
    });

    test('decodes the per-currency amounts of an amount discount', () {
      final Map<String, dynamic> data = _data();
      data['discount'] = <String, dynamic>{
        'type': 'amount',
        'value': 500,
        'currency': 'usd',
        'currency_options': <String, dynamic>{'try': 15000, 'eur': 450},
      };

      final MagicStarterCampaignDiscount discount =
          MagicStarterCampaign.fromMap(data).discount;

      expect(discount.currencyOptions, <String, num>{'try': 15000, 'eur': 450});
      expect(discount.amountIn('TRY'), 15000);
      expect(discount.amountIn('usd'), isNull);
    });

    test('ends at its end, whatever the clock says about its start', () {
      final MagicStarterCampaign campaign = MagicStarterCampaign.fromMap(
        _data(),
      );

      expect(campaign.hasEndedAt(DateTime.utc(2026, 10, 31, 23, 59)), isFalse);
      expect(campaign.hasEndedAt(DateTime.utc(2026, 11, 7, 23, 59)), isFalse);
      expect(campaign.hasEndedAt(DateTime.utc(2026, 11, 8)), isTrue);
    });

    test('picks the reader locale, then the default, then any copy', () {
      final MagicStarterCampaign campaign = MagicStarterCampaign.fromMap(
        _data(),
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

      final Map<String, dynamic> data = _data();
      data['headline'] = <String, String>{'de': 'Nur diese Woche'};
      data['body'] = <String, String>{};
      final MagicStarterCampaign onlyGerman = MagicStarterCampaign.fromMap(
        data,
      );

      expect(onlyGerman.headlineFor('fr'), 'Nur diese Woche');
      expect(onlyGerman.bodyFor('fr'), '');
    });
  });
}
