import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/menu_item.dart';

/// Customization payload for adding a new cart line.
class CartCustomization {
  const CartCustomization({
    this.portion = Portion.regular,
    this.spice = SpiceLevel.medium,
    this.notes = '',
  });
  final Portion portion;
  final SpiceLevel spice;
  final String notes;
}

const _kCartStorageKey = 'dawat.cart.v1';

/// Notifier that holds the cart and transparently persists it to
/// [SharedPreferences] so state survives navigation and app restarts.
class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    _loadFromStorage();
    return const [];
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartStorageKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      state = list.map(_itemFromJson).toList(growable: false);
    } catch (_) {
      // Best-effort: a corrupt cache should not crash the app.
      state = const [];
    }
  }

  Future<void> _persist(List<CartItem> next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kCartStorageKey,
        jsonEncode(next.map(_itemToJson).toList()),
      );
    } catch (_) {
      // Ignore — next mutation will try again.
    }
  }

  void _update(List<CartItem> next) {
    state = next;
    _persist(next);
  }

  void add(MenuItem item, {CartCustomization? customization}) {
    final c = customization ?? const CartCustomization();
    final line = CartItem(
      item: item,
      portion: c.portion,
      spice: c.spice,
      notes: c.notes,
    );
    final idx = state.indexWhere((x) => x.signature == line.signature);
    if (idx == -1) {
      _update([...state, line]);
    } else {
      final next = [...state];
      next[idx] = next[idx].copyWith(qty: next[idx].qty + 1);
      _update(next);
    }
  }

  void remove(MenuItem item) {
    final idx = state.indexWhere(
      (x) => x.item.id == item.id && x.portion == Portion.regular,
    );
    if (idx == -1) return;
    final current = state[idx];
    final next = [...state];
    if (current.qty <= 1) {
      next.removeAt(idx);
    } else {
      next[idx] = current.copyWith(qty: current.qty - 1);
    }
    _update(next);
  }

  void removeLine(String signature) {
    _update(
      state.where((x) => x.signature != signature).toList(growable: false),
    );
  }

  void bumpLine(String signature, int delta) {
    final idx = state.indexWhere((x) => x.signature == signature);
    if (idx == -1) return;
    final current = state[idx];
    final newQty = current.qty + delta;
    final next = [...state];
    if (newQty <= 0) {
      next.removeAt(idx);
    } else {
      next[idx] = current.copyWith(qty: newQty);
    }
    _update(next);
  }

  void clear() => _update(const []);
}

// ---------------------------------------------------------------------------
// Serialization — keep the stored JSON shape explicit.
// ---------------------------------------------------------------------------

Map<String, dynamic> _itemToJson(CartItem c) => {
      'menu_item': {
        'id': c.item.id,
        'restaurant_id': c.item.restaurantId,
        'category_id': c.item.categoryId,
        'name': c.item.name,
        'price': c.item.price,
        'description': c.item.description,
        'image_url': c.item.imageUrl,
        'is_veg': c.item.isVeg,
        'is_available': c.item.isAvailable,
      },
      'qty': c.qty,
      'portion': c.portion.name,
      'spice': c.spice.name,
      'notes': c.notes,
    };

CartItem _itemFromJson(Map<String, dynamic> m) {
  final mi = m['menu_item'] as Map<String, dynamic>;
  return CartItem(
    item: MenuItem.fromMap({
      'id': mi['id'],
      'restaurant_id': mi['restaurant_id'],
      'category_id': mi['category_id'],
      'name': mi['name'],
      'price': mi['price'],
      'description': mi['description'],
      'image_url': mi['image_url'],
      'is_veg': mi['is_veg'],
      'is_available': mi['is_available'],
    }),
    qty: (m['qty'] as num).toInt(),
    portion: Portion.values.firstWhere(
      (p) => p.name == m['portion'],
      orElse: () => Portion.regular,
    ),
    spice: SpiceLevel.values.firstWhere(
      (s) => s.name == m['spice'],
      orElse: () => SpiceLevel.medium,
    ),
    notes: (m['notes'] ?? '') as String,
  );
}

// ---------------------------------------------------------------------------

final cartProvider =
    NotifierProvider<CartController, List<CartItem>>(CartController.new);

final cartCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider).fold<int>(0, (s, c) => s + c.qty),
);

/// Per-guest food total — sum of line totals *before* guest-count scaling.
/// Kept as the default "food cost" seen by callers that haven't been updated
/// to scale by guest count yet.
final cartFoodTotalProvider = Provider<double>(
  (ref) => ref.watch(cartProvider).fold<double>(0, (s, c) => s + c.lineTotal),
);

/// Grouped cart — one entry per restaurant, preserving line order within each
/// group. Empty list when the cart is empty. Used by the cart screen to render
/// the multi-vendor breakdown and by the order-placement path to build
/// `order_vendor_lots` rows.
class CartVendorGroup {
  const CartVendorGroup({
    required this.restaurantId,
    required this.lines,
  });
  final String restaurantId;
  final List<CartItem> lines;

  double get perGuestSubtotal =>
      lines.fold<double>(0, (s, c) => s + c.perGuestLineCost);

  double billedSubtotal(int guestCount) =>
      lines.fold<double>(0, (s, c) => s + c.billedLineTotal(guestCount));

  int get lineCount => lines.length;
}

final cartVendorGroupsProvider = Provider<List<CartVendorGroup>>((ref) {
  final cart = ref.watch(cartProvider);
  if (cart.isEmpty) return const [];

  // Preserve the order in which each restaurant first appears in the cart.
  final order = <String>[];
  final byId = <String, List<CartItem>>{};
  for (final line in cart) {
    final rid = line.item.restaurantId;
    if (!byId.containsKey(rid)) {
      order.add(rid);
      byId[rid] = <CartItem>[];
    }
    byId[rid]!.add(line);
  }

  return [
    for (final rid in order)
      CartVendorGroup(restaurantId: rid, lines: byId[rid]!),
  ];
});

/// True when the cart has items from 2+ restaurants. Drives UI copy ("N
/// vendors") and any checkout flow that needs to show a split invoice.
final cartIsMultiVendorProvider = Provider<bool>(
  (ref) => ref.watch(cartVendorGroupsProvider).length >= 2,
);
