/// Porter booking (external courier) — one per vendor lot or per order.
class PorterBooking {
  const PorterBooking({
    required this.id,
    required this.orderId,
    this.vendorLotId,
    this.porterBookingId,
    this.porterTrackingUrl,
    this.porterStatus,
    this.pickupEtaMinutes,
    this.porterFare,
    this.deliveryOtp,
  });

  final String id;
  final String orderId;
  final String? vendorLotId;
  final String? porterBookingId;
  final String? porterTrackingUrl;
  final String? porterStatus;
  final int? pickupEtaMinutes;
  final double? porterFare;
  final String? deliveryOtp;

  factory PorterBooking.fromMap(Map<String, dynamic> map) => PorterBooking(
        id: map['id'] as String,
        orderId: map['order_id'] as String,
        vendorLotId: map['vendor_lot_id'] as String?,
        porterBookingId: map['porter_booking_id'] as String?,
        porterTrackingUrl: map['porter_tracking_url'] as String?,
        porterStatus: map['porter_status'] as String?,
        pickupEtaMinutes: (map['pickup_eta_minutes'] as num?)?.toInt(),
        porterFare: (map['porter_fare'] as num?)?.toDouble(),
        deliveryOtp: map['delivery_otp'] as String?,
      );
}
