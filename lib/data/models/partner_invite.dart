class PartnerInvite {
  const PartnerInvite({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.vehicleNumber,
    required this.createdAt,
    this.consumedAt,
  });

  final String id;
  final String email;
  final String name;
  final String phone;
  final String vehicle;
  final String vehicleNumber;
  final DateTime createdAt;
  final DateTime? consumedAt;

  bool get isConsumed => consumedAt != null;

  factory PartnerInvite.fromMap(Map<String, dynamic> map) {
    return PartnerInvite(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      vehicle: map['vehicle'] as String? ?? '',
      vehicleNumber: map['vehicle_number'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      consumedAt: map['consumed_at'] == null
          ? null
          : DateTime.parse(map['consumed_at'] as String),
    );
  }
}
