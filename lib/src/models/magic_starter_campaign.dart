import 'package:flutter/foundation.dart';

import '../configuration/magic_starter_config.dart';

/// How a campaign's discount is expressed.
enum MagicStarterCampaignDiscountType {
  /// A share of the price: [MagicStarterCampaignDiscount.value] is the percent.
  percent,

  /// A fixed sum: [MagicStarterCampaignDiscount.value] is in the minor unit of
  /// [MagicStarterCampaignDiscount.currency].
  amount,
}

/// What a campaign takes off, as the backend snapshotted it from the Stripe
/// coupon behind the promotion code.
@immutable
class MagicStarterCampaignDiscount {
  /// Whether [value] is a percent or an amount.
  final MagicStarterCampaignDiscountType type;

  /// The percent, or the amount in the minor unit (cents, kurus) of [currency].
  final num value;

  /// The ISO 4217 code of an [MagicStarterCampaignDiscountType.amount]
  /// discount, `null` for a percent.
  final String? currency;

  const MagicStarterCampaignDiscount({
    required this.type,
    required this.value,
    this.currency,
  });

  /// Decodes the wire object `{"type": "percent"|"amount", "value", "currency"}`.
  ///
  /// Throws an [ArgumentError] for a type this build does not know, so a
  /// client older than the backend shows no campaign rather than a wrong
  /// discount.
  factory MagicStarterCampaignDiscount.fromMap(Map<String, dynamic> map) {
    return MagicStarterCampaignDiscount(
      type: MagicStarterCampaignDiscountType.values.byName(
        map['type'] as String,
      ),
      value: map['value'] as num,
      currency: map['currency'] as String?,
    );
  }
}

/// The time-boxed offer `GET /billing/campaign` answers for the current team.
///
/// Wire shape: `{"id", "starts_at", "ends_at", "products": [keys], "discount":
/// {...}, "headline": {locale: text}, "body": {locale: text}}`. The backend
/// answers `{"data": null}` instead when nothing applies to the caller, so a
/// campaign that exists here is already one this caller is the audience of.
@immutable
class MagicStarterCampaign {
  /// The campaign's identity; what a dismissal is remembered against.
  final String id;

  /// When the offer opens.
  final DateTime startsAt;

  /// When the offer closes.
  final DateTime endsAt;

  /// The catalogue product keys the offer applies to.
  final List<String> products;

  /// What the offer takes off those products.
  final MagicStarterCampaignDiscount discount;

  /// The headline per language code.
  final Map<String, String> headline;

  /// The supporting copy per language code.
  final Map<String, String> body;

  const MagicStarterCampaign({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.products,
    required this.discount,
    required this.headline,
    required this.body,
  });

  /// Decodes the `data` object of the wire body.
  factory MagicStarterCampaign.fromMap(Map<String, dynamic> map) {
    return MagicStarterCampaign(
      id: map['id'] as String,
      startsAt: DateTime.parse(map['starts_at'] as String),
      endsAt: DateTime.parse(map['ends_at'] as String),
      products: (map['products'] as List<dynamic>).cast<String>(),
      discount: MagicStarterCampaignDiscount.fromMap(
        map['discount'] as Map<String, dynamic>,
      ),
      headline: _copy(map['headline']),
      body: _copy(map['body']),
    );
  }

  /// Whether the catalogue product [key] is part of the offer.
  bool coversProduct(String key) => products.contains(key);

  /// The headline for a reader whose language is [languageCode]; see
  /// [_pick].
  String headlineFor(String languageCode) => _pick(headline, languageCode);

  /// The supporting copy for a reader whose language is [languageCode]; see
  /// [_pick].
  String bodyFor(String languageCode) => _pick(body, languageCode);

  /// Keeps the entries whose value is a string; the backend fills every locale
  /// it supports, so a stray non-string is not copy.
  static Map<String, String> _copy(Object? raw) {
    return <String, String>{
      for (final MapEntry<String, dynamic> entry
          in (raw as Map<String, dynamic>).entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
  }

  /// The exact code's non-empty copy, else
  /// [MagicStarterConfig.defaultLocale]'s, else the first non-empty one, else
  /// `''`. Never throws.
  static String _pick(Map<String, String> copy, String languageCode) {
    // 1. The reader's own language.
    final String? exact = copy[languageCode];
    if (exact != null && exact.isNotEmpty) return exact;

    // 2. The app's default language.
    final String? fallback = copy[MagicStarterConfig.defaultLocale()];
    if (fallback != null && fallback.isNotEmpty) return fallback;

    // 3. Anything the backend did send.
    for (final String value in copy.values) {
      if (value.isNotEmpty) return value;
    }

    return '';
  }
}
