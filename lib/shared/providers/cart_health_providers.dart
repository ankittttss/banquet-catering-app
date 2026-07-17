import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/geo.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/restaurant.dart';
import 'cart_providers.dart';
import 'repositories_providers.dart';
import 'search_results_providers.dart';

/// Live validation of the persisted cart against the CURRENT catalog state.
/// The cart snapshots items at add-time, so between sessions a restaurant
/// can be suspended, a dish turned off, or the customer's address changed —
/// these providers surface that instead of silently billing wrong totals.

String _restaurantIdsKey(List<CartItem> cart) {
  final ids = cart.map((l) => l.item.restaurantId).toSet().toList()..sort();
  return ids.join(',');
}

String _itemIdsKey(List<CartItem> cart) {
  final ids = cart.map((l) => l.item.id).toSet().toList()..sort();
  return ids.join(',');
}

/// Cart restaurants resolved BY ID in any lifecycle state — real names and
/// real delivery charges even when a restaurant is outside the nearby/tier
/// scope (the old path silently zeroed its delivery fee to "FREE").
///
/// Keyed on the id SET (not the cart list), so quantity taps don't refetch.
final cartRestaurantsProvider =
    FutureProvider.autoDispose<Map<String, Restaurant>>((ref) async {
  final key = ref.watch(cartProvider.select(_restaurantIdsKey));
  if (key.isEmpty) return const {};
  final list = await ref
      .read(menuRepositoryProvider)
      .fetchRestaurantsByIds(key.split(',').toSet());
  return {for (final r in list) r.id: r};
});

/// Cart item ids that are no longer orderable (turned off or deleted).
final _unavailableCartItemIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) {
  final key = ref.watch(cartProvider.select(_itemIdsKey));
  if (key.isEmpty) return Future.value(const <String>{});
  return ref
      .read(menuRepositoryProvider)
      .fetchUnavailableItemIds(key.split(',').toSet());
});

enum CartLineIssue {
  /// Restaurant suspended/archived/deleted since the item was added.
  restaurantUnavailable,

  /// The dish itself was turned off or deleted.
  itemUnavailable,

  /// Restaurant is live but can't serve the customer's current location.
  outOfRange,
}

class CartHealth {
  const CartHealth({required this.issues, required this.ready});

  /// Cart line signature → its issue. Empty when the cart is clean.
  final Map<String, CartLineIssue> issues;

  /// False while the catalog checks are still in flight — the UI shows no
  /// warnings and does NOT block; the checkout guard re-verifies anyway.
  final bool ready;

  bool get hasBlockingIssue => issues.isNotEmpty;
  CartLineIssue? issueFor(CartItem line) => issues[line.signature];

  static const empty = CartHealth(issues: {}, ready: true);
}

/// Synchronous combine of the async checks above — cheap to watch from every
/// cart row.
final cartHealthProvider = Provider.autoDispose<CartHealth>((ref) {
  final cart = ref.watch(cartProvider);
  if (cart.isEmpty) return CartHealth.empty;

  final restaurants = ref.watch(cartRestaurantsProvider).valueOrNull;
  final unavailableItems =
      ref.watch(_unavailableCartItemIdsProvider).valueOrNull;
  if (restaurants == null || unavailableItems == null) {
    return const CartHealth(issues: {}, ready: false);
  }

  final coords = ref.watch(customerCoordsProvider);
  final issues = <String, CartLineIssue>{};
  for (final line in cart) {
    final r = restaurants[line.item.restaurantId];
    if (r == null || r.status != RestaurantStatus.published) {
      issues[line.signature] = CartLineIssue.restaurantUnavailable;
    } else if (unavailableItems.contains(line.item.id)) {
      issues[line.signature] = CartLineIssue.itemUnavailable;
    } else if (serviceabilityOf(
          r,
          customerLat: coords.lat,
          customerLng: coords.lng,
        ) ==
        Serviceability.outOfRange) {
      issues[line.signature] = CartLineIssue.outOfRange;
    }
  }
  return CartHealth(issues: issues, ready: true);
});
