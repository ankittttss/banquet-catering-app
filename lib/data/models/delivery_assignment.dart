enum DeliveryStatus {
  offered,    // broadcast to online drivers, awaiting accept
  accepted,   // driver accepted, heading to pickup
  pickedUp,   // food collected, heading to customer
  delivered,  // complete
  cancelled,  // driver abandoned or admin cancelled
  declined;   // driver declined / timed out

  static DeliveryStatus fromString(String? v) => switch (v) {
        'accepted' => DeliveryStatus.accepted,
        'picked_up' => DeliveryStatus.pickedUp,
        'delivered' => DeliveryStatus.delivered,
        'cancelled' => DeliveryStatus.cancelled,
        'declined' => DeliveryStatus.declined,
        _ => DeliveryStatus.offered,
      };

  String get dbValue => switch (this) {
        DeliveryStatus.offered => 'offered',
        DeliveryStatus.accepted => 'accepted',
        DeliveryStatus.pickedUp => 'picked_up',
        DeliveryStatus.delivered => 'delivered',
        DeliveryStatus.cancelled => 'cancelled',
        DeliveryStatus.declined => 'declined',
      };

  String get label => switch (this) {
        DeliveryStatus.offered => 'New order',
        DeliveryStatus.accepted => 'Heading to pickup',
        DeliveryStatus.pickedUp => 'Out for delivery',
        DeliveryStatus.delivered => 'Delivered',
        DeliveryStatus.cancelled => 'Cancelled',
        DeliveryStatus.declined => 'Declined',
      };
}

class DeliveryAssignment {
  const DeliveryAssignment({
    required this.id,
    required this.orderId,
    required this.status,
    required this.offeredAt,
    required this.pickupAddress,
    required this.dropAddress,
    required this.distanceKm,
    required this.earningAmount,
    required this.itemCount,
    required this.restaurantName,
    required this.customerName,
    required this.customerPhone,
    required this.eventLabel,
    required this.guestCount,
    required this.deliveryOtp,
    this.driverId,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.etaMinutes,
  });

  final String id;
  final String orderId;
  final DeliveryStatus status;
  final DateTime offeredAt;
  final String pickupAddress;
  final String dropAddress;
  final double distanceKm;
  final double earningAmount;
  final int itemCount;
  final String restaurantName;
  final String customerName;
  final String customerPhone;
  final String eventLabel; // e.g. "🎂 Birthday"
  final int guestCount;
  final String deliveryOtp; // 4-digit code
  final String? driverId;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final int? etaMinutes;

  DeliveryAssignment copyWith({
    DeliveryStatus? status,
    String? driverId,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    int? etaMinutes,
  }) {
    return DeliveryAssignment(
      id: id,
      orderId: orderId,
      status: status ?? this.status,
      offeredAt: offeredAt,
      pickupAddress: pickupAddress,
      dropAddress: dropAddress,
      distanceKm: distanceKm,
      earningAmount: earningAmount,
      itemCount: itemCount,
      restaurantName: restaurantName,
      customerName: customerName,
      customerPhone: customerPhone,
      eventLabel: eventLabel,
      guestCount: guestCount,
      deliveryOtp: deliveryOtp,
      driverId: driverId ?? this.driverId,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      etaMinutes: etaMinutes ?? this.etaMinutes,
    );
  }
}
