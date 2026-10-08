import 'package:flutter/foundation.dart';
import 'package:magic_payments/magic_payments.dart';

import 'magic_starter_product.dart';

// Re-exported because [MagicStarterPlan.products] hands one out: an adopter
// reading that list has to be able to NAME its element type through the same
// import that gave them the plan.
export 'magic_starter_product.dart';

/// A billing tier from a consumer app's plan catalogue, typed where the
/// package can honestly name a field and left in [raw] where it cannot.
///
/// The nine typed fields ([id], [name], [tagline], [monthly], [annual],
/// [currency], [features], [recommended], [products]) are the ones every
/// billing screen needs regardless of which product is selling the plan.
/// [products] is typed because both rails purchase by its keys, so it is the
/// payment contract's shape rather than the vendor's. Everything else on
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

  /// The products this tier sells, in the producer's order: what a purchase
  /// actually names. Empty for a tier nobody can buy (a free or a custom tier).
  final List<MagicStarterProduct> products;

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
    this.products = const [],
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
  /// 5. [products] keeps only entries with a non-empty key, since a product
  ///    nothing can name is a product nothing can buy.
  /// 6. [raw] keeps the WHOLE incoming map, not a filtered copy of the
  ///    leftovers: this is where `ai_line`, `responder_add_on` and `limits`
  ///    live, and a consumer's slot reads them straight from here.
  factory MagicStarterPlan.fromMap(Map<String, dynamic> map) {
    final Object? rawFeatures = map['features'];
    final Object? rawProducts = map['products'];

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
      products: rawProducts is List
          ? rawProducts
                .whereType<Map<String, dynamic>>()
                .map(MagicStarterProduct.fromMap)
                .where((MagicStarterProduct product) => product.key.isNotEmpty)
                .toList()
          : const [],
      raw: map,
    );
  }

  /// The subscription product a customer selecting this tier on [cycle] buys,
  /// or `null` when the tier sells no subscription at all.
  ///
  /// The product on [cycle] when the tier has one. Otherwise the tier's first
  /// subscription product, because a tier sold monthly only is still sellable
  /// while a screen-wide toggle sits on annual: refusing it would hide a tier
  /// the vendor sells because of a toggle position, and naming the product it
  /// really has sells it at the cycle that product charges.
  MagicStarterProduct? productFor(BillingCycle cycle) {
    final Iterable<MagicStarterProduct> subscriptions = products.where(
      (MagicStarterProduct product) =>
          product.type == ProductType.subscription && product.cycle != null,
    );

    return subscriptions
            .where((MagicStarterProduct product) => product.cycle == cycle)
            .firstOrNull ??
        subscriptions.firstOrNull;
  }
}
