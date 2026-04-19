import '../../../core/supabase/supabase_client.dart';
import '../../models/delivery_assignment.dart';
import '../../models/driver_profile.dart';
import '../delivery_repository.dart';

class SupabaseDeliveryRepository implements DeliveryRepository {
  @override
  Future<DriverProfile?> fetchDriver(String driverId) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', driverId)
        .maybeSingle();
    if (row == null) return null;
    return _driverFromProfileRow(row);
  }

  @override
  Stream<DriverProfile> streamDriver(String driverId) {
    return supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .map((rows) {
      if (rows.isEmpty) {
        throw StateError('Driver profile not found: $driverId');
      }
      return _driverFromProfileRow(rows.first);
    });
  }

  @override
  Future<void> setOnline(String driverId, bool online) async {
    await supabase
        .from('profiles')
        .update({'is_online': online}).eq('id', driverId);
  }

  @override
  Stream<List<DeliveryAssignment>> streamOffers() {
    return supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('status', 'offered')
        .order('offered_at')
        .map((rows) =>
            rows.map(_assignmentFromRow).toList(growable: false));
  }

  @override
  Stream<DeliveryAssignment?> streamActive(String driverId) {
    return supabase
        .from('deliveries')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('offered_at', ascending: false)
        .map((rows) {
      final active = rows.where((r) {
        final s = r['status'] as String?;
        return s == 'accepted' || s == 'picked_up';
      }).toList();
      if (active.isEmpty) return null;
      return _assignmentFromRow(active.first);
    });
  }

  @override
  Future<List<DeliveryAssignment>> fetchHistory(String driverId) async {
    final rows = await supabase
        .from('deliveries')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', ['delivered', 'cancelled'])
        .order('delivered_at', ascending: false, nullsFirst: false)
        .order('offered_at', ascending: false);
    return rows.map(_assignmentFromRow).toList(growable: false);
  }

  @override
  Future<void> acceptOffer(String assignmentId, String driverId) async {
    await supabase.from('deliveries').update({
      'driver_id': driverId,
      'status': 'accepted',
      'accepted_at': DateTime.now().toIso8601String(),
    }).eq('id', assignmentId);
  }

  @override
  Future<void> declineOffer(String assignmentId, String driverId) async {
    // No per-driver decline tracking yet — left as a no-op so the offer
    // remains available to other online drivers.
  }

  @override
  Future<void> markPickedUp(String assignmentId) async {
    await supabase.from('deliveries').update({
      'status': 'picked_up',
      'picked_up_at': DateTime.now().toIso8601String(),
    }).eq('id', assignmentId);
  }

  @override
  Future<void> markDelivered(String assignmentId,
      {required String otp}) async {
    final row = await supabase
        .from('deliveries')
        .select('delivery_otp')
        .eq('id', assignmentId)
        .single();
    if (row['delivery_otp'] != otp) {
      throw StateError('Invalid OTP');
    }
    await supabase.from('deliveries').update({
      'status': 'delivered',
      'delivered_at': DateTime.now().toIso8601String(),
    }).eq('id', assignmentId);

    // Bump the driver's total_deliveries counter.
    final drv = await supabase
        .from('deliveries')
        .select('driver_id')
        .eq('id', assignmentId)
        .single();
    final driverId = drv['driver_id'] as String?;
    if (driverId != null) {
      final profile = await supabase
          .from('profiles')
          .select('total_deliveries')
          .eq('id', driverId)
          .single();
      final current = (profile['total_deliveries'] as num?)?.toInt() ?? 0;
      await supabase.from('profiles').update(
          {'total_deliveries': current + 1}).eq('id', driverId);
    }
  }

  @override
  Future<List<DriverProfile>> fetchAvailableDrivers() async {
    final rows = await supabase
        .from('profiles')
        .select()
        .eq('role', 'delivery')
        .eq('is_online', true);
    return rows
        .map(_driverFromProfileRow)
        .where((d) => d.activeAssignmentId == null)
        .toList(growable: false);
  }

  @override
  Future<void> assignDriverToOrder({
    required String orderId,
    required String driverId,
    required DeliveryAssignment draft,
  }) async {
    // Prefer the auto-dispatched offer row (status='offered', no driver yet)
    // so we don't create duplicate deliveries for the same order.
    final existing = await supabase
        .from('deliveries')
        .select('id, status')
        .eq('order_id', orderId)
        .order('offered_at', ascending: false)
        .limit(1)
        .maybeSingle();

    String assignmentId;
    if (existing != null) {
      assignmentId = existing['id'] as String;
    } else {
      assignmentId = await broadcastOffer(draft);
    }
    await acceptOffer(assignmentId, driverId);
  }

  @override
  Future<String> broadcastOffer(DeliveryAssignment draft) async {
    final row = await supabase.from('deliveries').insert({
      'order_id': draft.orderId,
      'driver_id': draft.driverId,
      'status': draft.status.dbValue,
      'pickup_address': draft.pickupAddress,
      'drop_address': draft.dropAddress,
      'distance_km': draft.distanceKm,
      'earning_amount': draft.earningAmount,
      'item_count': draft.itemCount,
      'restaurant_name': draft.restaurantName,
      'customer_name': draft.customerName,
      'customer_phone': draft.customerPhone,
      'event_label': draft.eventLabel,
      'guest_count': draft.guestCount,
      'delivery_otp': draft.deliveryOtp,
      'eta_minutes': draft.etaMinutes,
    }).select().single();
    return row['id'] as String;
  }

  // ---------- mapping helpers ---------------------------------------------

  DriverProfile _driverFromProfileRow(Map<String, dynamic> row) {
    return DriverProfile(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? '',
      phone: (row['phone'] as String?) ?? '',
      vehicle: (row['vehicle'] as String?) ?? '',
      vehicleNumber: (row['vehicle_number'] as String?) ?? '',
      rating: (row['rating'] as num?)?.toDouble() ?? 5.0,
      totalDeliveries:
          (row['total_deliveries'] as num?)?.toInt() ?? 0,
      isOnline: row['is_online'] as bool? ?? false,
      avatarHex: row['avatar_hex'] as String?,
    );
  }

  DeliveryAssignment _assignmentFromRow(Map<String, dynamic> row) {
    DateTime? ts(String k) {
      final v = row[k];
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    return DeliveryAssignment(
      id: row['id'] as String,
      orderId: row['order_id'] as String,
      status: DeliveryStatus.fromString(row['status'] as String?),
      offeredAt:
          ts('offered_at') ?? DateTime.now(),
      pickupAddress: (row['pickup_address'] as String?) ?? '',
      dropAddress: (row['drop_address'] as String?) ?? '',
      distanceKm: (row['distance_km'] as num?)?.toDouble() ?? 0,
      earningAmount:
          (row['earning_amount'] as num?)?.toDouble() ?? 0,
      itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
      restaurantName: (row['restaurant_name'] as String?) ?? '',
      customerName: (row['customer_name'] as String?) ?? '',
      customerPhone: (row['customer_phone'] as String?) ?? '',
      eventLabel: (row['event_label'] as String?) ?? '',
      guestCount: (row['guest_count'] as num?)?.toInt() ?? 0,
      deliveryOtp: (row['delivery_otp'] as String?) ?? '',
      driverId: row['driver_id'] as String?,
      acceptedAt: ts('accepted_at'),
      pickedUpAt: ts('picked_up_at'),
      deliveredAt: ts('delivered_at'),
      etaMinutes: (row['eta_minutes'] as num?)?.toInt(),
    );
  }
}
