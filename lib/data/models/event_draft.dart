import 'chef.dart';
import 'private_property.dart';
import 'venue_type.dart';

/// Client-side draft of an event — not persisted until the order is placed.
class EventDraft {
  const EventDraft({
    this.eventName,
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
    this.venueType,
    this.propertyDraft,
    this.addonQuantities = const {},
    this.recce,
  });

  /// Customer-chosen display name for the event, e.g. "Aanya's Sangeet".
  /// Optional — when null the UI falls back to a composed label like
  /// "Dinner for 150".
  final String? eventName;

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
  /// suggestedServiceBoys (1 per 10 guests, min 1).
  final int? serviceBoyCount;

  /// Hall vs private property. Drives which sub-flow the user enters after
  /// step 1 of plan-your-event.
  final VenueType? venueType;

  /// Filled when [venueType] is [VenueType.privateProperty].
  final PrivatePropertyDraft? propertyDraft;

  /// Addon id → quantity. Empty when the user hasn't customised anything.
  final Map<String, int> addonQuantities;

  /// Optional free site-recce booking. Only meaningful on the private-
  /// property path.
  final ReccePick? recce;

  /// Suggested staffing level — 1 service boy per 10 guests (rounded up),
  /// floor of 1. e.g. 25 guests → 3, 100 guests → 10, 150 guests → 15.
  int get suggestedServiceBoys =>
      ((guestCount + 9) ~/ 10).clamp(1, 999);

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
    String? eventName,
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
    VenueType? venueType,
    PrivatePropertyDraft? propertyDraft,
    Map<String, int>? addonQuantities,
    ReccePick? recce,
  }) =>
      EventDraft(
        eventName: eventName ?? this.eventName,
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
        venueType: venueType ?? this.venueType,
        propertyDraft: propertyDraft ?? this.propertyDraft,
        addonQuantities: addonQuantities ?? this.addonQuantities,
        recce: recce ?? this.recce,
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

  /// Snapshot of the draft for persistence in `shared_preferences`. Bumps
  /// the schema version so old payloads can be discarded cleanly if the
  /// model evolves.
  Map<String, dynamic> toJson() => {
        'v': 1,
        if (eventName != null) 'eventName': eventName,
        if (date != null) 'date': date!.toIso8601String(),
        if (location != null) 'location': location,
        if (session != null) 'session': session,
        if (startTime != null) 'startTime': startTime!.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        'guestCount': guestCount,
        if (tierId != null) 'tierId': tierId,
        if (tierCode != null) 'tierCode': tierCode,
        if (banquetVenueId != null) 'banquetVenueId': banquetVenueId,
        if (banquetVenueName != null) 'banquetVenueName': banquetVenueName,
        if (serviceBoyCount != null) 'serviceBoyCount': serviceBoyCount,
        if (venueType != null) 'venueType': venueType!.dbValue,
        if (propertyDraft != null) 'propertyDraft': propertyDraft!.toJson(),
        if (addonQuantities.isNotEmpty) 'addonQuantities': addonQuantities,
        if (recce != null) 'recce': recce!.toJson(),
      };

  factory EventDraft.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) {
      final v = json[key];
      return v is String ? DateTime.tryParse(v) : null;
    }
    final qty = (json['addonQuantities'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ) ??
        const <String, int>{};
    return EventDraft(
      eventName: json['eventName'] as String?,
      date: parse('date'),
      location: json['location'] as String?,
      session: json['session'] as String?,
      startTime: parse('startTime'),
      endTime: parse('endTime'),
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 50,
      tierId: json['tierId'] as String?,
      tierCode: json['tierCode'] as String?,
      banquetVenueId: json['banquetVenueId'] as String?,
      banquetVenueName: json['banquetVenueName'] as String?,
      serviceBoyCount: (json['serviceBoyCount'] as num?)?.toInt(),
      venueType: VenueType.fromDbValue(json['venueType'] as String?),
      propertyDraft: json['propertyDraft'] is Map<String, dynamic>
          ? PrivatePropertyDraft.fromJson(
              json['propertyDraft'] as Map<String, dynamic>,
            )
          : null,
      addonQuantities: qty,
      recce: json['recce'] is Map<String, dynamic>
          ? ReccePick.fromJson(json['recce'] as Map<String, dynamic>)
          : null,
    );
  }
}
