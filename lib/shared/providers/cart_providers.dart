import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/menu_item.dart';

/// Shape of a cart customization. Mirrors the fields on [CartItem] but allows
/// the caller to supply only what's set (the controller falls back to
/// defaults for anything omitted).
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

class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  /// Add one unit of [item] with default (or provided) customization.
  /// If a matching customization line already exists, bumps its quantity.
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
      state = [...state, line];
    } else {
      final next = [...state];
      next[idx] = next[idx].copyWith(qty: next[idx].qty + 1);
      state = next;
    }
  }

  /// Remove one unit of the **default** customization line for [item].
  /// Customized lines should be removed from the cart screen via [removeLine].
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
    state = next;
  }

  /// Remove an exact cart line (used from the cart screen).
  void removeLine(String signature) {
    state = state
        .where((x) => x.signature != signature)
        .toList(growable: false);
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
    state = next;
  }

  void clear() => state = const [];
}

final cartProvider =
    NotifierProvider<CartController, List<CartItem>>(CartController.new);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold<int>(0, (s, c) => s + c.qty);
});

final cartFoodTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold<double>(0, (s, c) => s + c.lineTotal);
});
