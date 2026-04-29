enum EventAssignmentRole {
  manager('manager', 'Manager'),
  serviceBoy('service_boy', 'Service Boy');

  const EventAssignmentRole(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static EventAssignmentRole fromString(String? v) {
    for (final r in values) {
      if (r.dbValue == v) return r;
    }
    return EventAssignmentRole.serviceBoy;
  }
}

class EventAssignment {
  const EventAssignment({
    required this.id,
    required this.eventId,
    required this.profileId,
    required this.roleOnEvent,
    required this.assignedAt,
    this.assignedBy,
    this.checkedInAt,
    this.checkedOutAt,
    this.notes,
    this.eventDate,
    this.eventLocation,
    this.eventSession,
    this.eventGuestCount,
    this.profileName,
  });

  final String id;
  final String eventId;
  final String profileId;
  final EventAssignmentRole roleOnEvent;
  final String? assignedBy;
  final DateTime assignedAt;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final String? notes;

  // Denormalised helpers fetched via join — nullable.
  final DateTime? eventDate;
  final String? eventLocation;
  final String? eventSession;
  final int? eventGuestCount;
  final String? profileName;

  bool get isCheckedIn => checkedInAt != null && checkedOutAt == null;

  factory EventAssignment.fromMap(Map<String, dynamic> map) {
    final event = map['events'];
    // PostgREST embeds under either `assignee` (new, disambiguated via the
    // event_assignments_profile_id_fkey constraint) or `profiles` (legacy).
    final profile = map['assignee'] ?? map['profiles'];
    return EventAssignment(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      profileId: map['profile_id'] as String,
      roleOnEvent:
          EventAssignmentRole.fromString(map['role_on_event'] as String?),
      assignedBy: map['assigned_by'] as String?,
      assignedAt: DateTime.parse(map['assigned_at'] as String),
      checkedInAt: _parse(map['checked_in_at']),
      checkedOutAt: _parse(map['checked_out_at']),
      notes: map['notes'] as String?,
      eventDate: event is Map && event['event_date'] is String
          ? DateTime.tryParse(event['event_date'] as String)
          : null,
      eventLocation: event is Map ? event['location'] as String? : null,
      eventSession: event is Map ? event['session'] as String? : null,
      eventGuestCount:
          event is Map ? (event['guest_count'] as num?)?.toInt() : null,
      profileName: profile is Map ? profile['name'] as String? : null,
    );
  }

  static DateTime? _parse(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.tryParse(raw) : null;
}
