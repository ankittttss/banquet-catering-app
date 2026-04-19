class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicle,
    required this.vehicleNumber,
    required this.rating,
    required this.totalDeliveries,
    required this.isOnline,
    this.avatarHex,
    this.activeAssignmentId,
  });

  final String id;
  final String name;
  final String phone;
  final String vehicle; // e.g. "Honda Activa"
  final String vehicleNumber; // e.g. "TS 09 AB 1234"
  final double rating;
  final int totalDeliveries;
  final bool isOnline;
  final String? avatarHex;
  final String? activeAssignmentId;

  DriverProfile copyWith({
    bool? isOnline,
    String? activeAssignmentId,
  }) {
    return DriverProfile(
      id: id,
      name: name,
      phone: phone,
      vehicle: vehicle,
      vehicleNumber: vehicleNumber,
      rating: rating,
      totalDeliveries: totalDeliveries,
      isOnline: isOnline ?? this.isOnline,
      avatarHex: avatarHex,
      activeAssignmentId: activeAssignmentId ?? this.activeAssignmentId,
    );
  }

  factory DriverProfile.fromMap(Map<String, dynamic> map) {
    return DriverProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      vehicle: map['vehicle'] as String? ?? '',
      vehicleNumber: map['vehicle_number'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      totalDeliveries: (map['total_deliveries'] as num?)?.toInt() ?? 0,
      isOnline: map['is_online'] as bool? ?? false,
      avatarHex: map['avatar_hex'] as String?,
      activeAssignmentId: map['active_assignment_id'] as String?,
    );
  }
}
