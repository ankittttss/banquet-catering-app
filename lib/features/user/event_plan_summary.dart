import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_routes.dart';
import '../../data/models/event_draft.dart';
import '../../data/models/event_tier.dart';
import '../../data/models/venue_type.dart';
import '../../shared/providers/banquet_providers.dart';
import '../../shared/providers/event_tier_providers.dart';
import 'planning_next_step.dart';

/// State of one validated section of the plan (package, venue).
enum EventPlanCheck {
  /// Not relevant to this draft (e.g. venue check on a private-property plan).
  notApplicable,

  /// A live lookup is still in flight — never treat as done.
  checking,

  /// The lookup failed; the customer can retry. Never treat as done.
  error,

  /// The lookup succeeded and the answer is bad (missing/deactivated tier,
  /// inactive/deleted/too-small venue).
  attention,

  /// Validated good.
  ok,
}

/// Overall readiness of the event plan.
///
/// CRITICAL: [ready] requires ALL THREE of — the shared cascade reporting
/// complete, the selected tier resolving against the LIVE active tier list,
/// and (for banquet plans) the live venue check reporting exactly
/// [VenueCheckState.valid]. A structurally complete draft whose tier was
/// deactivated, or whose hall shrank or was removed, is NOT ready.
enum EventPlanReadiness {
  /// Nothing meaningful planned yet — surfaces "Plan an event".
  notStarted,

  /// The shared cascade still wants something.
  incomplete,

  /// A live validation is in flight.
  checking,

  /// A live validation came back bad, or failed outright.
  needsAttention,

  /// Everything verified.
  ready,
}

/// Read-only view of the customer's in-progress event, shared by the home
/// card, the Event Plan page and (Phase 1b) Cart/Checkout so no two surfaces
/// can disagree about what is planned or how complete it is.
class EventPlanSummary {
  const EventPlanSummary({
    required this.readiness,
    required this.hasMeaningfulDraft,
    required this.title,
    required this.cardSubtitle,
    required this.eventName,
    required this.occasionText,
    required this.sessionText,
    required this.dateText,
    required this.timeText,
    required this.guestsText,
    required this.locationText,
    required this.packageCheck,
    required this.packageText,
    required this.packageRangeText,
    required this.venueCheck,
    required this.venueText,
    required this.venueCapacityText,
    required this.propertyText,
    required this.addonCount,
    required this.isPrivateProperty,
    required this.fraction,
    required this.statusMessage,
    required this.actionHint,
    required this.actionRoute,
  });

  final EventPlanReadiness readiness;
  final bool hasMeaningfulDraft;

  /// Headline for compact surfaces (home card): the customer's own name when
  /// set, else a composed label.
  final String title;

  /// "Wed, 20 Aug · 7:00 PM" — the one-line subtitle compact surfaces show.
  final String cardSubtitle;

  /// The customer's own event name, or null when they never set one. Kept
  /// separate from [occasionText] so the UI never mislabels a name as an
  /// occasion.
  final String? eventName;

  /// Occasion derived from the draft's own category slug, or null.
  final String? occasionText;

  final String? sessionText;

  /// Date only ("Wed, 20 Aug").
  final String dateText;

  /// "7:00 PM – 10:00 PM", or null when times are unset.
  final String? timeText;

  final String guestsText;

  /// Confirmed event address, or a prompt when unset.
  final String locationText;

  final EventPlanCheck packageCheck;

  /// Package label, or the honest state ("Checking your package…").
  final String packageText;

  /// "₹250–400 per guest" for a resolved package, else null.
  final String? packageRangeText;

  final EventPlanCheck venueCheck;

  /// Banquet hall label, or the honest state. Empty for private property.
  final String venueText;

  /// Live capacity of a validated hall ("Up to 500 guests"), else null.
  final String? venueCapacityText;

  /// Private-property description. Empty for banquet.
  final String propertyText;

  final int addonCount;
  final bool isPrivateProperty;

  /// 0..1 planning progress. Only reaches 1.0 when [readiness] is
  /// [EventPlanReadiness.ready] — a full bar can never contradict the hint.
  final double fraction;

  /// Describes the CONDITION of the plan ("Everything is set — add dishes to
  /// finalise the menu."). Shown on the Event Plan page, where the customer is
  /// already looking at the plan itself.
  final String statusMessage;

  /// Describes what TAPPING does, and where it goes. Deliberately separate
  /// from [statusMessage]: a ready plan's condition is "add dishes", but the
  /// home card actually opens the Event Plan page — promising one and doing
  /// the other is the mismatch these two fields exist to prevent.
  final String actionHint;
  final String actionRoute;

  bool get isReady => readiness == EventPlanReadiness.ready;

  /// True while a live check is running or has failed — the UI should show a
  /// neutral/retry affordance rather than a success state.
  bool get isUnverified =>
      readiness == EventPlanReadiness.checking ||
      readiness == EventPlanReadiness.needsAttention;
}

/// Whether the customer has started planning in any meaningful way. Drives
/// "Plan an event" vs. the Event Plan entry point.
bool hasMeaningfulDraft(EventDraft d) =>
    (d.eventName?.trim().isNotEmpty ?? false) ||
    // An occasion alone is planning state: session/guest seeding may be
    // unavailable, and a restored legacy draft can carry only the category.
    (d.categorySlug?.trim().isNotEmpty ?? false) ||
    d.session != null ||
    d.date != null ||
    (d.location?.trim().isNotEmpty ?? false) ||
    d.tierId != null ||
    d.venueType != null ||
    d.banquetVenueId != null ||
    d.propertyDraft != null;

/// Build the shared summary.
///
/// Pure over its inputs (including the two AsyncValues) so every readiness
/// rule is unit-testable without a container. It deliberately REUSES
/// [planningNextStep], [resolveSelectedTier] and [VenueCheck] rather than
/// re-deriving any of them.
///
/// Callers that know a lookup is unnecessary (no tier chosen, private-property
/// plan, …) may pass a placeholder AsyncValue: the corresponding branch
/// short-circuits before the value is read. See `eventPlanSummaryProvider`.
EventPlanSummary buildEventPlanSummary({
  required EventDraft draft,
  required AsyncValue<List<EventTier>> tiers,
  required AsyncValue<VenueCheck> venueCheck,
  required int addonCount,
  DateTime? now,
}) {
  final started = hasMeaningfulDraft(draft);
  final step = planningNextStep(draft, now: now);
  final cascadeComplete = step.route == AppRoutes.userHome;
  final isPrivate = draft.venueType == VenueType.privateProperty;

  // ── Package: resolve against the LIVE active tier list ──
  final (packageState, packageLabel, packageRange) =
      _packageCheck(draft, tiers);

  // ── Venue: only meaningful for a banquet plan with a hall chosen ──
  final (venueState, venueLabel, venueCapacity) =
      _venueCheck(draft, venueCheck);

  // ── Readiness: cascade AND package AND venue must all be good ──
  final EventPlanReadiness readiness;
  if (!started) {
    readiness = EventPlanReadiness.notStarted;
  } else if (!cascadeComplete) {
    readiness = EventPlanReadiness.incomplete;
  } else if (packageState == EventPlanCheck.checking ||
      venueState == EventPlanCheck.checking) {
    readiness = EventPlanReadiness.checking;
  } else if (packageState == EventPlanCheck.error ||
      venueState == EventPlanCheck.error ||
      packageState == EventPlanCheck.attention ||
      venueState == EventPlanCheck.attention) {
    readiness = EventPlanReadiness.needsAttention;
  } else {
    readiness = EventPlanReadiness.ready;
  }

  // Status + action follow the SAME priority as readiness, so a card that
  // says "Needs attention" can never tap through to "add dishes".
  final (status, actionHint, actionRoute) = _statusAndAction(
    step: step,
    cascadeComplete: cascadeComplete,
    package: packageState,
    venue: venueState,
  );

  // Progress. The final step is full readiness (not merely "a venue id
  // exists"), so a full bar can never contradict the hint — the exact
  // mismatch an over-capacity hall used to produce.
  final steps = <bool>[
    draft.session != null,
    draft.date != null,
    draft.startTime != null && draft.endTime != null,
    (draft.location?.trim().isNotEmpty ?? false) && draft.hasEventCoords,
    draft.tierId != null,
    readiness == EventPlanReadiness.ready,
  ];
  final fraction = steps.where((e) => e).length / steps.length;

  final name = draft.eventName?.trim();
  return EventPlanSummary(
    readiness: readiness,
    hasMeaningfulDraft: started,
    title: composeEventTitle(draft),
    cardSubtitle: composeEventDate(draft),
    eventName: (name == null || name.isEmpty) ? null : name,
    occasionText: _occasionText(draft),
    sessionText: draft.session,
    dateText: _dateOnly(draft),
    timeText: _timeRange(draft),
    guestsText: '${draft.guestCount} guests',
    // The ADDRESS on purpose. Elsewhere a booked hall is shown by name
    // (EventDraft.eventLocationLabel), but this page already devotes a whole
    // "Banquet venue" section to that name — repeating it here would say the
    // same thing twice and drop the address entirely.
    locationText: (draft.location?.trim().isNotEmpty ?? false)
        ? draft.location!.trim()
        : 'Event location not set',
    packageCheck: packageState,
    packageText: packageLabel,
    packageRangeText: packageRange,
    venueCheck: venueState,
    venueText: venueLabel,
    venueCapacityText: venueCapacity,
    propertyText: isPrivate ? _propertyText(draft) : '',
    addonCount: addonCount,
    isPrivateProperty: isPrivate,
    fraction: fraction,
    statusMessage: status,
    actionHint: actionHint,
    actionRoute: actionRoute,
  );
}

/// (statusMessage, actionHint, actionRoute) — live validation OUTRANKS the
/// structural cascade once the cascade itself is satisfied.
///
/// For every unfinished state the condition and the action are the same thing
/// ("Choose a suitable venue" both describes the problem and says what tapping
/// does), so status and action hint match. Only the READY state separates
/// them: the plan's condition is "add dishes", but tapping opens the plan —
/// promising one and doing the other is the mismatch this split prevents.
(String, String, String) _statusAndAction({
  required PlanningStep step,
  required bool cascadeComplete,
  required EventPlanCheck package,
  required EventPlanCheck venue,
}) {
  if (!cascadeComplete) return (step.hint, step.hint, step.route);

  if (package == EventPlanCheck.checking) {
    const m = 'Checking your package…';
    return (m, m, AppRoutes.eventPlan);
  }
  if (package == EventPlanCheck.error) {
    const m = "Couldn't verify your package — retry";
    return (m, m, AppRoutes.eventPlan);
  }
  if (package == EventPlanCheck.attention) {
    const m = 'Choose an available package';
    return (m, m, AppRoutes.eventDetails);
  }
  if (venue == EventPlanCheck.checking) {
    const m = 'Checking your venue…';
    return (m, m, AppRoutes.eventPlan);
  }
  if (venue == EventPlanCheck.error) {
    const m = "Couldn't verify your venue — retry";
    return (m, m, AppRoutes.eventPlan);
  }
  if (venue == EventPlanCheck.attention) {
    const m = 'Choose a suitable venue';
    return (m, m, AppRoutes.eventVenueType);
  }
  return (
    'Everything is set — add dishes to finalise the menu.',
    'View your complete event plan',
    AppRoutes.eventPlan,
  );
}

(EventPlanCheck, String, String?) _packageCheck(
  EventDraft draft,
  AsyncValue<List<EventTier>> tiers,
) {
  // Short-circuits BEFORE reading [tiers] — callers rely on this to skip the
  // tier lookup entirely when nothing is selected.
  if (draft.tierId == null) {
    return (EventPlanCheck.attention, 'No package selected', null);
  }
  return tiers.when(
    loading: () => (EventPlanCheck.checking, 'Checking your package…', null),
    error: (_, __) =>
        (EventPlanCheck.error, "Couldn't verify your package", null),
    data: (list) {
      final tier = resolveSelectedTier(list, draft.tierId);
      if (tier == null) {
        return (EventPlanCheck.attention, 'Package needs attention', null);
      }
      final lo = tier.perGuestMin.round();
      final hi = tier.perGuestMax.round();
      return (EventPlanCheck.ok, tier.label, '₹$lo–$hi per guest');
    },
  );
}

(EventPlanCheck, String, String?) _venueCheck(
  EventDraft draft,
  AsyncValue<VenueCheck> check,
) {
  // Both guards short-circuit BEFORE reading [check] — callers rely on this
  // to skip the by-id venue lookup.
  if (draft.venueType != VenueType.banquetHall) {
    return (EventPlanCheck.notApplicable, '', null);
  }
  if (draft.banquetVenueId == null) {
    return (EventPlanCheck.attention, 'No venue selected', null);
  }
  final name = draft.banquetVenueName ?? 'Selected venue';
  return check.when(
    loading: () => (EventPlanCheck.checking, 'Checking your venue…', null),
    error: (_, __) =>
        (EventPlanCheck.error, "Couldn't verify your venue", null),
    data: (c) {
      // ONLY `valid` satisfies a selected hall. `none` here would mean the
      // live check disagrees that a venue is selected — unverified, not good.
      if (c.state != VenueCheckState.valid) {
        return (EventPlanCheck.attention, 'Venue needs attention', null);
      }
      // Prefer the LIVE row: an admin may have renamed or resized the hall
      // since it was selected. Fall back to the draft's stored copy.
      final cap = c.venue?.capacity ?? draft.banquetVenueCapacity;
      return (
        EventPlanCheck.ok,
        c.venue?.name ?? name,
        cap == null ? null : 'Up to $cap guests',
      );
    },
  );
}

String _propertyText(EventDraft draft) {
  final p = draft.propertyDraft;
  if (p == null) return 'Property details not added';
  final type = p.type?.label;
  if (p.isComplete) {
    return type == null ? 'Property details added' : '$type · details added';
  }
  return type == null ? 'Property details incomplete' : '$type · needs details';
}

/// Humanised occasion from the draft's own category slug ("baby_shower" →
/// "Baby shower"). Derived locally so the summary needs no extra lookup.
String? _occasionText(EventDraft d) {
  final slug = d.categorySlug?.trim();
  if (slug == null || slug.isEmpty) return null;
  final words = slug
      .split(RegExp(r'[_\-\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.toLowerCase())
      .toList();
  if (words.isEmpty) return null;
  final first = words.first;
  words[0] = first[0].toUpperCase() + first.substring(1);
  return words.join(' ');
}

/// Customer-facing event title: their own name when set, else a composed one.
String composeEventTitle(EventDraft d) {
  final custom = d.eventName?.trim();
  if (custom != null && custom.isNotEmpty) return custom;
  final session = d.session;
  if (session != null) return '$session for ${d.guestCount}';
  return 'Your event for ${d.guestCount}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _clock(DateTime t) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:${t.minute.toString().padLeft(2, '0')} $ampm';
}

String _dateOnly(EventDraft d) {
  if (d.date == null) return 'Date not set';
  final dt = d.date!;
  return '${_weekdays[dt.weekday - 1]}, ${dt.day} ${_months[dt.month - 1]}';
}

String? _timeRange(EventDraft d) {
  if (d.startTime == null) return null;
  final start = _clock(d.startTime!);
  if (d.endTime == null) return start;
  return '$start – ${_clock(d.endTime!)}';
}

/// "Wed, 20 Aug · 7:00 PM" — one-line subtitle for compact surfaces.
String composeEventDate(EventDraft d) {
  final base = _dateOnly(d);
  if (d.date == null || d.startTime == null) return base;
  return '$base · ${_clock(d.startTime!)}';
}
