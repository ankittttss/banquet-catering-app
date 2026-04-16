import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/menu_item.dart';

class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  void add(MenuItem item) {
    final idx = state.indexWhere((c) => c.item.id == item.id);
    if (idx == -1) {
      state = [...state, CartItem(item: item, qty: 1)];
    } else {
      final updated = [...state];
      updated[idx] = updated[idx].copyWith(qty: updated[idx].qty + 1);
      state = updated;
    }
  }

  void remove(MenuItem item) {
    final idx = state.indexWhere((c) => c.item.id == item.id);
    if (idx == -1) return;
    final current = state[idx];
    final updated = [...state];
    if (current.qty <= 1) {
      updated.removeAt(idx);
    } else {
      updated[idx] = current.copyWith(qty: current.qty - 1);
    }
    state = updated;
  }

  void clear() => state = const [];

  int qtyOf(String itemId) {
    final found = state.firstWhere(
      (c) => c.item.id == itemId,
      orElse: () => CartItem(
        item: const MenuItem(
          id: '',
          restaurantId: '',
          categoryId: '',
          name: '',
          price: 0,
        ),
      ),
    );
    return found.item.id.isEmpty ? 0 : found.qty;
  }
}

final cartProvider =
    NotifierProvider<CartController, List<CartItem>>(CartController.new);

final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold<int>(0, (s, c) => s + c.qty);
});

final cartFoodTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold<double>(0, (s, c) => s + c.lineTotal);
});
