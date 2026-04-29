class BanquetVenue {
  const BanquetVenue({
    required this.id,
    required this.ownerProfileId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.capacity,
    this.isActive = true,
  });

  final String id;
  final String ownerProfileId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int? capacity;
  final bool isActive;

  factory BanquetVenue.fromMap(Map<String, dynamic> map) => BanquetVenue(
        id: map['id'] as String,
        ownerProfileId: map['owner_profile_id'] as String,
        name: map['name'] as String,
        address: map['address'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        capacity: (map['capacity'] as num?)?.toInt(),
        isActive: (map['is_active'] as bool?) ?? true,
      );
}

enum BanquetEventStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined'),
  cancelled('cancelled', 'Cancelled'),
  completed('completed', 'Completed');

  const BanquetEventStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static BanquetEventStatus fromString(String? v) {
    for (final s in values) {
      if (s.dbValue == v) return s;
    }
    return BanquetEventStatus.pending;
  }
}

/// Event as seen from a banquet operator's inbox.
class BanquetInboxEvent {
  const BanquetInboxEvent({
    required this.id,
    required this.banquetVenueId,
    required this.eventDate,
    required this.session,
    required this.guestCount,
    required this.status,
    this.location,
    this.notes,
    this.startTime,
    this.endTime,
  });

  final String id;
  final String banquetVenueId;
  final DateTime eventDate;
  final String session;
  final int guestCount;
  final BanquetEventStatus status;
  final String? location;
  final String? notes;
  final String? startTime;
  final String? endTime;

  factory BanquetInboxEvent.fromMap(Map<String, dynamic> map) =>
      BanquetInboxEvent(
        id: map['id'] as String,
        banquetVenueId: map['banquet_venue_id'] as String,
        eventDate: DateTime.parse(map['event_date'] as String),
        session: (map['session'] as String?) ?? '',
        guestCount: (map['guest_count'] as num?)?.toInt() ?? 0,
        status: BanquetEventStatus.fromString(map['banquet_status'] as String?),
        location: map['location'] as String?,
        notes: map['banquet_notes'] as String?,
        startTime: map['start_time'] as String?,
        endTime: map['end_time'] as String?,
      );
}

class BanquetInventoryItem {
  const BanquetInventoryItem({
    required this.id,
    required this.venueId,
    required this.itemType,
    required this.label,
    required this.unitPrice,
    this.perGuest = true,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String venueId;
  final String itemType;
  final String label;
  final double unitPrice;
  final bool perGuest;
  final bool isActive;
  final int sortOrder;

  factory BanquetInventoryItem.fromMap(Map<String, dynamic> map) =>
      BanquetInventoryItem(
        id: map['id'] as String,
        venueId: map['venue_id'] as String,
        itemType: map['item_type'] as String,
        label: map['label'] as String,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        perGuest: (map['per_guest'] as bool?) ?? true,
        isActive: (map['is_active'] as bool?) ?? true,
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}
