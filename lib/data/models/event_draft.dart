import 'private_property.dart';
import 'venue_type.dart';

/// Client-side draft of an event — not persisted until the order is placed.
class EventDraft {
  const EventDraft({
    this.eventName,
    this.categorySlug,
    this.date,
    this.location,
    this.eventLatitude,
    this.eventLongitude,
    this.session,
    this.startTime,
    this.endTime,
    this.guestCount = 50,
    this.tierId,
    this.tierCode,
    this.banquetVenueId,
    this.banquetVenueName,
    this.banquetVenueCapacity,
    this.serviceBoyCount,
    this.venueType,
    this.propertyDraft,
    this.addonQuantities = const {},
  });

  /// Customer-chosen display name for the event, e.g. "Aanya's Sangeet".
  /// Optional — when null the UI falls back to a composed label like
  /// "Dinner for 150".
  final String? eventName;

  /// Slug of the occasion picked on the home grid / plan screen (e.g.
  /// "wedding", "birthday"). Drives the pre-selected occasion chip and
  /// persists the choice through the whole plan flow.
  final String? categorySlug;

  final DateTime? date;
  final String? location;

  /// Coordinates of the event location. When present, the restaurant list is
  /// sorted nearest-first to *these* coordinates rather than the user's saved
  /// home/work address.
  final double? eventLatitude;
  final double? eventLongitude;

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

  /// Capacity of the selected banquet venue, captured at selection time.
  /// Null when unknown (the venue row had no capacity). This lets the shared
  /// planning cascade detect — offline, without a fetch — that a later
  /// guest-count increase pushed the party past the hall it fits, so Home,
  /// Event Details and Checkout all stop treating that stale hall as a done
  /// step. `place_order` re-checks LIVE capacity as the final authority.
  final int? banquetVenueCapacity;

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

  /// Suggested staffing level — 1 service boy per 10 guests (rounded up),
  /// floor of 1. e.g. 25 guests → 3, 100 guests → 10, 150 guests → 15.
  int get suggestedServiceBoys => ((guestCount + 9) ~/ 10).clamp(1, 999);

  /// Effective service boy count used for billing.
  int get effectiveServiceBoyCount => serviceBoyCount ?? suggestedServiceBoys;

  /// True when the event location carries usable coordinates.
  bool get hasEventCoords => eventLatitude != null && eventLongitude != null;

  /// How the event location should be NAMED in the UI.
  ///
  /// A booked banquet hall is known by its name, not its street address —
  /// "Grand Palace" means something to the customer in a way that
  /// "Plot 42, Survey No. 118/A…" does not. A private property has no such
  /// name, so its address stays the label.
  ///
  /// Display only: [location] + coordinates remain the routing/serviceability
  /// truth everywhere, and the address is still shown as supporting detail.
  String? get eventLocationLabel {
    final venue = banquetVenueName?.trim();
    if (venue != null && venue.isNotEmpty) return venue;
    final addr = location?.trim();
    return (addr != null && addr.isNotEmpty) ? addr : null;
  }

  /// The address line that supports [eventLocationLabel]. Null when it would
  /// just repeat the label (private property, where the label IS the address).
  String? get eventLocationDetail {
    final venue = banquetVenueName?.trim();
    if (venue == null || venue.isEmpty) return null;
    final addr = location?.trim();
    return (addr != null && addr.isNotEmpty && addr != venue) ? addr : null;
  }

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
    String? categorySlug,
    DateTime? date,
    String? location,
    double? eventLatitude,
    double? eventLongitude,
    String? session,
    DateTime? startTime,
    DateTime? endTime,
    int? guestCount,
    String? tierId,
    String? tierCode,
    String? banquetVenueId,
    String? banquetVenueName,
    int? banquetVenueCapacity,
    int? serviceBoyCount,
    VenueType? venueType,
    PrivatePropertyDraft? propertyDraft,
    Map<String, int>? addonQuantities,
  }) =>
      EventDraft(
        eventName: eventName ?? this.eventName,
        categorySlug: categorySlug ?? this.categorySlug,
        date: date ?? this.date,
        location: location ?? this.location,
        eventLatitude: eventLatitude ?? this.eventLatitude,
        eventLongitude: eventLongitude ?? this.eventLongitude,
        session: session ?? this.session,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        guestCount: guestCount ?? this.guestCount,
        tierId: tierId ?? this.tierId,
        tierCode: tierCode ?? this.tierCode,
        banquetVenueId: banquetVenueId ?? this.banquetVenueId,
        banquetVenueName: banquetVenueName ?? this.banquetVenueName,
        banquetVenueCapacity: banquetVenueCapacity ?? this.banquetVenueCapacity,
        serviceBoyCount: serviceBoyCount ?? this.serviceBoyCount,
        venueType: venueType ?? this.venueType,
        propertyDraft: propertyDraft ?? this.propertyDraft,
        addonQuantities: addonQuantities ?? this.addonQuantities,
      );

  // NOTE: the old toInsertMap (direct events-table insert) was replaced by
  // orderEventPayload (lib/data/repositories/order_payloads.dart), which
  // feeds the transactional place_order RPC and persists the FULL booking
  // (category, venue type, coordinates, property details, add-ons).

  /// Snapshot of the draft for persistence in `shared_preferences`. Bumps
  /// the schema version so old payloads can be discarded cleanly if the
  /// model evolves.
  Map<String, dynamic> toJson() => {
        'v': 1,
        if (eventName != null) 'eventName': eventName,
        if (categorySlug != null) 'categorySlug': categorySlug,
        if (date != null) 'date': date!.toIso8601String(),
        if (location != null) 'location': location,
        if (eventLatitude != null) 'eventLatitude': eventLatitude,
        if (eventLongitude != null) 'eventLongitude': eventLongitude,
        if (session != null) 'session': session,
        if (startTime != null) 'startTime': startTime!.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        'guestCount': guestCount,
        if (tierId != null) 'tierId': tierId,
        if (tierCode != null) 'tierCode': tierCode,
        if (banquetVenueId != null) 'banquetVenueId': banquetVenueId,
        if (banquetVenueName != null) 'banquetVenueName': banquetVenueName,
        if (banquetVenueCapacity != null)
          'banquetVenueCapacity': banquetVenueCapacity,
        if (serviceBoyCount != null) 'serviceBoyCount': serviceBoyCount,
        if (venueType != null) 'venueType': venueType!.dbValue,
        if (propertyDraft != null) 'propertyDraft': propertyDraft!.toJson(),
        if (addonQuantities.isNotEmpty) 'addonQuantities': addonQuantities,
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
      categorySlug: json['categorySlug'] as String?,
      date: parse('date'),
      location: json['location'] as String?,
      eventLatitude: (json['eventLatitude'] as num?)?.toDouble(),
      eventLongitude: (json['eventLongitude'] as num?)?.toDouble(),
      session: json['session'] as String?,
      startTime: parse('startTime'),
      endTime: parse('endTime'),
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 50,
      tierId: json['tierId'] as String?,
      tierCode: json['tierCode'] as String?,
      banquetVenueId: json['banquetVenueId'] as String?,
      banquetVenueName: json['banquetVenueName'] as String?,
      banquetVenueCapacity: (json['banquetVenueCapacity'] as num?)?.toInt(),
      serviceBoyCount: (json['serviceBoyCount'] as num?)?.toInt(),
      venueType: VenueType.fromDbValue(json['venueType'] as String?),
      propertyDraft: json['propertyDraft'] is Map<String, dynamic>
          ? PrivatePropertyDraft.fromJson(
              json['propertyDraft'] as Map<String, dynamic>,
            )
          : null,
      addonQuantities: qty,
    );
  }
}
