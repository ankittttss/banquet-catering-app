import '../../../core/supabase/supabase_client.dart';
import '../../models/order_vendor_lot.dart';
import '../../models/restaurant.dart';
import '../restaurant_ops_repository.dart';

class SupabaseRestaurantOpsRepository implements RestaurantOpsRepository {
  @override
  Future<List<Restaurant>> fetchMyRestaurants() async {
    final uid = auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('restaurant_staff')
        .select('restaurant_id, restaurants(*)')
        .eq('profile_id', uid);
    return rows
        .map<Restaurant?>((r) {
          final nested = r['restaurants'];
          if (nested is Map) {
            return Restaurant.fromMap(Map<String, dynamic>.from(nested));
          }
          return null;
        })
        .whereType<Restaurant>()
        .toList(growable: false);
  }

  @override
  Future<List<OrderVendorLot>> fetchMyLots() async {
    final rows = await supabase
        .from('order_vendor_lots')
        .select('*, restaurants(name)')
        .order('created_at', ascending: false);
    return rows.map<OrderVendorLot>((r) {
      final nested = r['restaurants'];
      final flat = Map<String, dynamic>.from(r);
      if (nested is Map && nested['name'] is String) {
        flat['restaurant_name'] = nested['name'];
      }
      return OrderVendorLot.fromMap(flat);
    }).toList(growable: false);
  }

  @override
  Stream<List<OrderVendorLot>> streamMyLots() async* {
    try {
      yield await fetchMyLots();
    } catch (_) {
      yield const [];
    }
    try {
      final stream = supabase
          .from('order_vendor_lots')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false);
      await for (final _ in stream) {
        // Re-fetch with restaurant name join — the realtime payload doesn't
        // include the join, so we can't emit it directly.
        yield await fetchMyLots();
      }
    } catch (_) {
      // Realtime unavailable — initial snapshot already surfaced.
    }
  }

  @override
  Future<void> updateLotStatus({
    required String lotId,
    required VendorLotStatus status,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'status': status.dbValue,
    };
    switch (status) {
      case VendorLotStatus.accepted:
        payload['accepted_at'] = now;
      case VendorLotStatus.readyForPickup:
        payload['ready_at'] = now;
      case VendorLotStatus.pickedUp:
        payload['picked_up_at'] = now;
      case VendorLotStatus.delivered:
        payload['delivered_at'] = now;
      default:
        break;
    }
    await supabase
        .from('order_vendor_lots')
        .update(payload)
        .eq('id', lotId);
  }
}
