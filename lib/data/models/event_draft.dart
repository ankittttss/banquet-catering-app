/// Client-side draft of an event — not persisted until the order is placed.
class EventDraft {
  const EventDraft({
    this.date,
    this.location,
    this.session,
    this.startTime,
    this.endTime,
    this.guestCount = 50,
    this.tierId,
    this.tierCode,
    this.banquetVenueId,
    this.banquetVenueName,
    this.serviceBoyCount,
  });

  final DateTime? date;
  final String? location;
  final String? session; // 'Lunch' | 'Dinner' | 'High Tea'
  final DateTime? startTime;
  final DateTime? endTime;
  final int guestCount;

  /// Chosen event tier (Budget / Standard / Premium). Drives the restaurant
  /// picker's budget filter. Nullable while the user is still planning.
  final String? tierId;
  final String? tierCode;

  /// Banquet venue the event will be hosted at. Nullable during planning
  /// and for legacy flows; required to route the booking into a banquet's
  /// inbox.
  final String? banquetVenueId;
  final String? banquetVenueName;

  /// Customer-chosen number of service boys. When null, falls back to
  /// suggestedServiceBoys (1 per 20 guests, min 1).
  final int? serviceBoyCount;

  /// Suggested staffing level — 1 service boy per ~20 guests, min 1.
  int get suggestedServiceBoys =>
      ((guestCount + 19) ~/ 20).clamp(1, 999);

  /// Effective service boy count used for billing.
  int get effectiveServiceBoyCount =>
      serviceBoyCount ?? suggestedServiceBoys;

  bool get isComplete =>
      date != null &&
      (location != null && location!.trim().isNotEmpty) &&
      session != null &&
      startTime != null &&
      endTime != null &&
      guestCount > 0 &&
      tierId != null;

  EventDraft copyWith({
    DateTime? date,
    String? location,
    String? session,
    DateTime? startTime,
    DateTime? endTime,
    int? guestCount,
    String? tierId,
    String? tierCode,
    String? banquetVenueId,
    String? banquetVenueName,
    int? serviceBoyCount,
  }) =>
      EventDraft(
        date: date ?? this.date,
        location: location ?? this.location,
        session: session ?? this.session,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        guestCount: guestCount ?? this.guestCount,
        tierId: tierId ?? this.tierId,
        tierCode: tierCode ?? this.tierCode,
        banquetVenueId: banquetVenueId ?? this.banquetVenueId,
        banquetVenueName: banquetVenueName ?? this.banquetVenueName,
        serviceBoyCount: serviceBoyCount ?? this.serviceBoyCount,
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
        if (tierId != null) 'tier_id': tierId,
        if (banquetVenueId != null) 'banquet_venue_id': banquetVenueId,
      };
}
