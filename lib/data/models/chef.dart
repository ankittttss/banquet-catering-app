/// Chef bookable for a free site recce on a private-property event.
class Chef {
  const Chef({
    required this.id,
    required this.name,
    required this.rating,
    required this.headline,
    required this.tags,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final double rating;
  /// One-line resume — "14 yrs · ex-Taj · 320 events".
  final String headline;
  /// Specialty chips shown under the headline.
  final List<String> tags;
  final String? avatarUrl;
}

/// A recce day shown in the horizontal date row.
class RecceDay {
  const RecceDay({
    required this.date,
    required this.slotsAvailable,
    required this.slots,
  });

  final DateTime date;
  /// 0 when the day is full, otherwise the count of open slots.
  final int slotsAvailable;
  /// All time slots offered on this day, in display order. Use
  /// [isBooked] to grey out the ones already taken.
  final List<RecceSlot> slots;

  bool get isFull => slotsAvailable == 0;
}

class RecceSlot {
  const RecceSlot({
    required this.label,
    required this.hour,
    required this.minute,
    this.isBooked = false,
  });

  final String label;
  final int hour;
  final int minute;
  final bool isBooked;
}

/// What the user has currently picked for the recce booking.
class ReccePick {
  const ReccePick({
    this.chefId,
    this.day,
    this.slotLabel,
  });

  final String? chefId;
  final DateTime? day;
  final String? slotLabel;

  bool get isComplete =>
      chefId != null && day != null && slotLabel != null;

  ReccePick copyWith({
    String? chefId,
    DateTime? day,
    String? slotLabel,
  }) =>
      ReccePick(
        chefId: chefId ?? this.chefId,
        day: day ?? this.day,
        slotLabel: slotLabel ?? this.slotLabel,
      );
}
