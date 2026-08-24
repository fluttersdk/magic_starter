import 'package:flutter/foundation.dart';

/// A billing tier from a consumer app's plan catalogue, typed where the
/// package can honestly name a field and left in [raw] where it cannot.
///
/// The eight typed fields ([id], [name], [tagline], [monthly], [annual],
/// [currency], [features], [recommended]) are the ones every billing screen
/// needs regardless of which product is selling the plan. Everything else on
/// a catalogue entry, such as an `ai_line` sales pitch, a `responder_add_on`
/// note, or a `limits` map of in-product caps, is the vendor's OWN product
/// and stays in [raw] rather than becoming a typed field here.
///
/// This follows the same line `magic_payments`' `BillingEntitlement` already
/// draws (`raw: map` alongside typed fields, see
/// `magic_payments/lib/src/models/billing_entitlement.dart`), and the reason
/// is the same one `BillingService.getPlans()` gives for returning its rows
/// undecoded: "a tier's own fields are the vendor's product, not the
/// framework's" (`magic_payments/lib/src/contracts/billing_service.dart:34-43`).
///
/// [currency] is named because the wire always carries one, but this package
/// renders only the `usd` symbol (`$`); any other currency code falls back to
/// the raw string rather than a formatting table this package does not own.
///
/// ```dart
/// final plan = MagicStarterPlan.fromMap(catalogueRow);
/// final aiLine = plan.raw['ai_line'] as String?;
/// ```
@immutable
class MagicStarterPlan {
  /// Stable machine identifier (e.g. `'free'`, `'pro'`, `'business'`).
  final String id;

  /// Human-readable tier name.
  final String name;

  /// Short positioning tagline.
  final String tagline;

  /// Monthly price in the tier's [currency]; `null` means "contact us"
  /// (an Enterprise-style custom tier with no fixed price).
  final int? monthly;

  /// Effective price per month when billed annually; `null` for the same
  /// custom-tier reason as [monthly].
  final int? annual;

  /// The wire currency code (e.g. `'usd'`). See the class docblock: this
  /// package renders only the `usd` symbol and falls back to this raw code
  /// for any other currency.
  final String currency;

  /// Gating and headline feature bullets, in the vendor's own order.
  final List<String> features;

  /// Whether this tier is visually highlighted as the recommended choice.
  final bool recommended;

  /// The full catalogue entry, verbatim. Holds every field this class does
  /// not name, including `ai_line`, `responder_add_on` and `limits`; a
  /// consumer's plan slot renders from this map for the fields the package
  /// never looked at.
  final Map<String, dynamic> raw;

  const MagicStarterPlan({
    required this.id,
    required this.name,
    required this.tagline,
    required this.monthly,
    required this.annual,
    required this.currency,
    required this.features,
    required this.recommended,
    required this.raw,
  });

  /// Decodes a [MagicStarterPlan] from one plan catalogue entry (a
  /// `GET /billing/plans` row, served verbatim by the backend).
  ///
  /// Decoding is tolerant on purpose, since a catalogue is consumer-owned and
  /// this package cannot demand a shape from it:
  ///
  /// 1. [id], [name], [tagline] and [currency] fall back to an empty string
  ///    rather than throwing; an empty [id] fails a lookup cleanly instead of
  ///    crashing the billing screen mid-render.
  /// 2. [monthly] and [annual] read as `num` and coerce to `int`, since JSON
  ///    can hand back a double for a whole number.
  /// 3. [features] defaults to an empty list, and only its `String` elements
  ///    survive; a malformed entry does not crash the bullet list.
  /// 4. [recommended] defaults to `false`, the same non-claim every other
  ///    tolerant default in this package makes.
  /// 5. [raw] keeps the WHOLE incoming map, not a filtered copy of the
  ///    leftovers: this is where `ai_line`, `responder_add_on` and `limits`
  ///    live, and a consumer's slot reads them straight from here.
  factory MagicStarterPlan.fromMap(Map<String, dynamic> map) {
    final Object? rawFeatures = map['features'];

    return MagicStarterPlan(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      tagline: (map['tagline'] as String?) ?? '',
      monthly: (map['monthly'] as num?)?.toInt(),
      annual: (map['annual'] as num?)?.toInt(),
      currency: (map['currency'] as String?) ?? '',
      features: rawFeatures is List
          ? rawFeatures.whereType<String>().toList()
          : const [],
      recommended: (map['recommended'] as bool?) ?? false,
      raw: map,
    );
  }
}
