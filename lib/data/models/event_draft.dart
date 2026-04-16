/// Client-side draft of an event — not persisted until the order is placed.
class EventDraft {
  const EventDraft({
    this.date,
    this.location,
    this.session,
    this.startTime,
    this.endTime,
    this.guestCount = 50,
  });

  final DateTime? date;
  final String? location;
  final String? session; // 'Lunch' | 'Dinner' | 'High Tea'
  final DateTime? startTime;
  final DateTime? endTime;
  final int guestCount;

  bool get isComplete =>
      date != null &&
      (location != null && location!.trim().isNotEmpty) &&
      session != null &&
      startTime != null &&
      endTime != null &&
      guestCount > 0;

  EventDraft copyWith({
    DateTime? date,
    String? location,
    String? session,
    DateTime? startTime,
    DateTime? endTime,
    int? guestCount,
  }) =>
      EventDraft(
        date: date ?? this.date,
        location: location ?? this.location,
        session: session ?? this.session,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        guestCount: guestCount ?? this.guestCount,
      );

  Map<String, dynamic> toInsertMap(String userId) => {
        'user_id': userId,
        'event_date': date!.toIso8601String().substring(0, 10),
        'location': location,
        'session': session,
        'start_time':
            '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
        'end_time':
            '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
        'guest_count': guestCount,
      };
}
