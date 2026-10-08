import 'package:flutter/foundation.dart';
import 'package:magic_payments/magic_payments.dart';

/// One price the web rail charges for a product, in one currency.
///
/// [amountMinor] is in the currency's minor unit (cents, kurus), for
/// arithmetic; [display] is the producer's own formatted string, for rendering.
typedef MagicStarterWebPrice = ({int amountMinor, String display});

/// One sellable product in a catalogue tier row: the thing a purchase names.
///
/// A tier is not a price. `pro` sold monthly and again at a discounted annual
/// rate is ONE tier and TWO products, and both rails purchase by the product's
/// [key] (`pro_annual`) rather than by a (tier, cycle) pair a call could send
/// half of. This is the decoded form of one entry in a `GET /billing/plans`
/// row's `products` list.
///
/// [type] and [cycle] decode to `null` for a word this build does not know,
/// never to a guessed member: reading an unknown cycle as monthly is a claim
/// about what a customer is charged.
@immutable
class MagicStarterProduct {
  /// The vendor's catalogue key (e.g. `'pro_annual'`), the value a purchase,
  /// a checkout and a swap send.
  final String key;

  /// What the product sells, or `null` for a type this build does not know.
  final ProductType? type;

  /// The tier id this product belongs to (e.g. `'pro'`).
  final String tier;

  /// How often a subscription product charges, or `null` for a one-off
  /// product and for a cycle this build does not know.
  final BillingCycle? cycle;

  /// The web rail's prices, keyed by ISO 4217 currency code (`'USD'`). Empty
  /// when the producer prices the product for no web currency.
  final Map<String, MagicStarterWebPrice> webPrices;

  const MagicStarterProduct({
    required this.key,
    required this.type,
    required this.tier,
    required this.cycle,
    this.webPrices = const {},
  });

  /// Decodes one `products` entry of a catalogue tier row.
  ///
  /// Tolerant for the same reason [MagicStarterPlan.fromMap] is: a malformed
  /// price entry is dropped and its siblings survive, and a `prices.web` sent
  /// as a JSON `[]` (PHP's encoding of an empty object) decodes empty.
  factory MagicStarterProduct.fromMap(Map<String, dynamic> map) {
    final Object? prices = map['prices'];
    final BillingCycle? cycle = BillingCycle.fromWire(map['cycle'] as String?);

    return MagicStarterProduct(
      key: (map['key'] as String?) ?? '',
      type: ProductType.fromWire(map['type'] as String?),
      tier: (map['tier'] as String?) ?? '',
      cycle: cycle,
      webPrices: _webPricesFromWire(prices is Map ? prices['web'] : null),
    );
  }

  /// Decodes `prices.web`, keeping only entries that carry both an integer
  /// amount and a display string.
  static Map<String, MagicStarterWebPrice> _webPricesFromWire(Object? raw) {
    if (raw is! Map) return const {};

    final Map<String, MagicStarterWebPrice> prices = {};
    for (final MapEntry<Object?, Object?>(:key, :value) in raw.entries) {
      if (key is! String || value is! Map) continue;

      final Object? amount = value['amount_minor'];
      final Object? display = value['display'];
      if (amount is! num || display is! String) continue;

      prices[key] = (amountMinor: amount.toInt(), display: display);
    }

    return prices;
  }
}
