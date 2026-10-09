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
/// The typed fields ([id], [name], [tagline], [features], [recommended],
/// [cycles], [products]) are the ones every billing screen needs regardless
/// of which product is selling the plan. A tier carries NO price of its own:
/// a price belongs to a product, so [products] is typed because both rails
/// purchase by its keys and price by its entries, which makes it the payment
/// contract's shape rather than the vendor's. Everything else on a catalogue
/// entry, such as an `ai_line` sales pitch, a `responder_add_on` note, or a
/// `limits` map of in-product caps, is the vendor's OWN product and stays in
/// [raw] rather than becoming a typed field here.
///
/// This follows the same line `magic_payments`' `BillingEntitlement` already
/// draws (`raw: map` alongside typed fields, see
/// `magic_payments/lib/src/models/billing_entitlement.dart`), and the reason
/// is the same one `BillingService.getPlans()` gives for returning its rows
/// undecoded: "a tier's own fields are the vendor's product, not the
/// framework's" (`magic_payments/lib/src/contracts/billing_service.dart:34-43`).
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

  /// Gating and headline feature bullets, in the vendor's own order.
  final List<String> features;

  /// Whether this tier is visually highlighted as the recommended choice.
  final bool recommended;

  /// The cycles the WEB rail sells this tier on: the producer lists a cycle
  /// only when a sellable product on it has a card-rail price, so a cycle
  /// absent here would be refused by checkout. Empty for a tier the web does
  /// not sell (a free tier, a custom tier, a tier priced in a store only).
  final List<BillingCycle> cycles;

  /// Every subscription product of this tier, in the producer's order,
  /// INCLUDING ones no longer sold ([MagicStarterProduct.sellable] `false`),
  /// which are listed so a held one can still be ranked. Read
  /// [sellableProducts] for anything that may be offered.
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
    required this.features,
    required this.recommended,
    this.cycles = const [],
    this.products = const [],
    required this.raw,
  });

  /// Decodes a [MagicStarterPlan] from one plan catalogue entry (a
  /// `GET /billing/plans` row, served verbatim by the backend).
  ///
  /// Decoding is tolerant on purpose, since a catalogue is consumer-owned and
  /// this package cannot demand a shape from it:
  ///
  /// 1. [id], [name] and [tagline] fall back to an empty string rather than
  ///    throwing; an empty [id] fails a lookup cleanly instead of crashing the
  ///    billing screen mid-render.
  /// 2. [cycles] keeps only the words this build knows, never a guess, since
  ///    offering an unknown cycle as monthly is a claim about a charge.
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
    final Object? rawCycles = map['cycles'];
    final Object? rawProducts = map['products'];

    return MagicStarterPlan(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      tagline: (map['tagline'] as String?) ?? '',
      features: rawFeatures is List
          ? rawFeatures.whereType<String>().toList()
          : const [],
      recommended: (map['recommended'] as bool?) ?? false,
      cycles: rawCycles is List
          ? rawCycles
                .whereType<String>()
                .map(BillingCycle.fromWire)
                .whereType<BillingCycle>()
                .toList()
          : const [],
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

  /// The subscription products this tier still sells, in the producer's order:
  /// the only ones any purchase, checkout or price read may name.
  List<MagicStarterProduct> get sellableProducts {
    return products
        .where(
          (MagicStarterProduct product) =>
              product.sellable &&
              product.type == ProductType.subscription &&
              product.cycle != null,
        )
        .toList();
  }

  /// The subscription product a customer selecting this tier on [cycle] buys,
  /// or `null` when the tier sells no subscription at all.
  ///
  /// The sellable product on [cycle] when the tier has one. Otherwise the
  /// tier's first sellable product, because a tier sold monthly only is still
  /// sellable while a screen-wide toggle sits on annual: refusing it would hide
  /// a tier the vendor sells because of a toggle position, and naming the
  /// product it really has sells it at the cycle that product charges. A
  /// grandfathered product is never the answer, whatever its cycle.
  MagicStarterProduct? productFor(BillingCycle cycle) {
    return _pick(sellableProducts, cycle);
  }

  /// The product the WEB rail sells on [cycle], on the same terms as
  /// [productFor] but only among the products on one of [cycles].
  ///
  /// `null` for a tier the web does not sell, including one priced in a store
  /// only: a web button for it would be refused by checkout after the customer
  /// had committed to buy.
  MagicStarterProduct? webProductFor(BillingCycle cycle) {
    return _pick(
      sellableProducts.where(
        (MagicStarterProduct product) => cycles.contains(product.cycle),
      ),
      cycle,
    );
  }

  /// The sellable products of this tier that have an id in [store], in the
  /// producer's order: the only ones that store can complete a purchase of.
  ///
  /// A sellable product the producer registered in the other store only, or in
  /// none, is absent. Offering it would show a figure and a button whose
  /// purchase fails with `productUnavailable` after the customer committed to
  /// buy. Empty for a [store] that is no store ([ManageVia.portal],
  /// [ManageVia.none]).
  List<MagicStarterProduct> storeProducts(ManageVia store) {
    return sellableProducts
        .where(
          (MagicStarterProduct product) => _storeId(product, store) != null,
        )
        .toList();
  }

  /// The product a customer selecting this tier on [cycle] buys in [store], on
  /// the same terms as [productFor] but only among [storeProducts], or `null`
  /// when the store carries nothing of this tier.
  ///
  /// A cycle the store cannot sell falls back to the tier's first product it
  /// can, for the reason [productFor] gives, and never to a product the store
  /// has no id for.
  MagicStarterProduct? storeProductFor(BillingCycle cycle, ManageVia store) {
    return _pick(storeProducts(store), cycle);
  }

  /// [product]'s id in [store], or `null` when that store does not carry it.
  ///
  /// Exhaustive with no `default`, so a new [ManageVia] is a compile error here
  /// rather than a rail that silently sells nothing.
  static String? _storeId(MagicStarterProduct product, ManageVia store) {
    return switch (store) {
      ManageVia.appStore => product.storeIds.appStore,
      ManageVia.playStore => product.storeIds.play,
      ManageVia.portal || ManageVia.none => null,
    };
  }

  /// The candidate on [cycle], else the first candidate, else `null`.
  static MagicStarterProduct? _pick(
    Iterable<MagicStarterProduct> candidates,
    BillingCycle cycle,
  ) {
    return candidates
            .where((MagicStarterProduct product) => product.cycle == cycle)
            .firstOrNull ??
        candidates.firstOrNull;
  }
}
