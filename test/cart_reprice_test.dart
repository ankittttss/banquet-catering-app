import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/data/models/cart_item.dart';
import 'package:banquet_catering_app/data/models/menu_item.dart';

MenuItem _item(double price) => MenuItem(
      id: 'i1',
      restaurantId: 'r1',
      categoryId: 'c1',
      name: 'Paneer Tikka',
      price: price,
    );

void main() {
  group('MenuItem.copyWith', () {
    test('updates price while keeping identity + other fields', () {
      final updated = _item(200).copyWith(price: 260);
      expect(updated.id, 'i1');
      expect(updated.name, 'Paneer Tikka');
      expect(updated.price, 260);
    });
  });

  group('CartItem repricing (checkout price re-check)', () {
    test('reprices the embedded item and recomputes the billed total', () {
      // Snapshot price ₹200, qty 2/guest, 50 guests → 2*200*50 = 20,000.
      final line = CartItem(item: _item(200), qty: 2);
      expect(line.billedLineTotal(50), 20000);

      // Admin raised the price to ₹260 → reprice → 2*260*50 = 26,000.
      final repriced = line.copyWith(item: line.item.copyWith(price: 260));
      expect(repriced.item.price, 260);
      expect(repriced.qty, 2);
      expect(repriced.billedLineTotal(50), 26000);
    });

    test('portion multiplier still applies after repricing', () {
      final line = CartItem(item: _item(100), portion: Portion.large); // ×1.4
      expect(line.unitPrice, closeTo(140, 0.001));
      final repriced = line.copyWith(item: line.item.copyWith(price: 150));
      expect(repriced.unitPrice, closeTo(210, 0.001)); // 150 × 1.4
    });
  });
}
