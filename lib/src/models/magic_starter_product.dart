import 'package:flutter/foundation.dart';
import 'package:magic_payments/magic_payments.dart';

/// One price the web rail charges for a product, in one currency.
///
/// [amountMinor] is in the currency's minor unit (cents, kurus), for
/// arithmetic; [display] is the producer's own formatted string, for rendering.
typedef MagicStarterWebPrice = ({int amountMinor, String display});

/// The store product ids a catalogue product is sold as, one per store, each
/// `null` when that store does not carry it.
///
/// [play] is Google Play's `subscriptionId:basePlanId`. These are what a store
/// receipt names, so they are how a held store subscription is placed on a tier;
/// a purchase still names the catalogue key, never one of these.
typedef MagicStarterStoreIds = ({String? appStore, String? play});

/// One product in a catalogue tier row: the thing a purchase names.
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
///
/// A row lists every subscription product of its tier, including ones no
/// longer sold ([sellable] `false`): a customer may still HOLD a grandfathered
/// product, and the client has to be able to rank it. Nothing may offer one.
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

  /// Whether the product is still for sale. `false` is a grandfathered
  /// product, kept in the row only so a customer holding it can be ranked;
  /// no purchase, checkout or price read may name it.
  final bool sellable;

  /// The store product ids this product is sold as.
  final MagicStarterStoreIds storeIds;

  /// The web rail's prices, keyed by ISO 4217 currency code (`'USD'`), in the
  /// producer's order. Empty when the producer prices the product for no web
  /// currency.
  final Map<String, MagicStarterWebPrice> webPrices;

  /// The free days a purchase of this product starts with, `0` for none.
  ///
  /// The producer answers it for THIS caller: `0` also means a trial this
  /// customer has already used, so a positive value is an offer that can be
  /// advertised and `0` is never a claim that the product has no trial at all.
  /// A web (Stripe) trial takes a card up front. An absent, negative or
  /// non-integer `trial_days` decodes to `0`.
  final int trialDays;

  const MagicStarterProduct({
    required this.key,
    required this.type,
    required this.tier,
    required this.cycle,
    this.sellable = true,
    this.storeIds = (appStore: null, play: null),
    this.webPrices = const {},
    this.trialDays = 0,
  });

  /// Decodes one `products` entry of a catalogue tier row.
  ///
  /// Tolerant for the same reason [MagicStarterPlan.fromMap] is: a malformed
  /// price entry is dropped and its siblings survive, and a `prices.web` sent
  /// as a JSON `[]` (PHP's encoding of an empty object) decodes empty.
  ///
  /// An absent `sellable` reads as `true`, because a producer that predates the
  /// flag listed only what it sold. A store id that is not a non-empty string
  /// names no store product. `trial_days` is read only as a non-negative
  /// integer; anything else is no trial rather than a guessed number of days.
  factory MagicStarterProduct.fromMap(Map<String, dynamic> map) {
    final Object? prices = map['prices'];
    final Object? storeIds = map['store_ids'];
    final Object? trialDays = map['trial_days'];
    final BillingCycle? cycle = BillingCycle.fromWire(map['cycle'] as String?);

    return MagicStarterProduct(
      key: (map['key'] as String?) ?? '',
      type: ProductType.fromWire(map['type'] as String?),
      tier: (map['tier'] as String?) ?? '',
      cycle: cycle,
      sellable: map['sellable'] != false,
      storeIds: (
        appStore: _storeId(storeIds is Map ? storeIds['app_store'] : null),
        play: _storeId(storeIds is Map ? storeIds['play'] : null),
      ),
      webPrices: _webPricesFromWire(prices is Map ? prices['web'] : null),
      trialDays: trialDays is int && trialDays > 0 ? trialDays : 0,
    );
  }

  /// A store id from the wire, or `null` for anything that cannot name one.
  static String? _storeId(Object? raw) {
    return raw is String && raw.isNotEmpty ? raw : null;
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
