import '../../core/router/app_routes.dart';
import '../../data/models/event_draft.dart';
import '../../data/models/venue_type.dart';

/// Guest range the product supports. Used consistently by the guest
/// selector, the shared validation cascade, and mirrored by the server's
/// place_order validation — one range, three enforcement points.
const int kGuestMin = 5;
const int kGuestMax = 5000;

/// "Now" on the business clock — Asia/Kolkata (IST, UTC+5:30, no DST).
///
/// The client NEVER trusts the device's local timezone for schedule rules:
/// a phone set to any timezone still validates against IST, exactly like
/// the server (`now() at time zone 'Asia/Kolkata'` in place_order).
///
/// CRITICAL representation detail: the value is rebuilt through the default
/// constructor so it is a timezone-NEUTRAL wall-clock DateTime (isUtc ==
/// false), matching how the draft stores its date/start/end (plain
/// wall-clock DateTimes). `isAfter`/`isBefore` compare epoch instants — a
/// utc-flagged "IST" value against a local-flagged draft time would apply
/// the device offset twice and could wrongly block a valid same-day event
/// (e.g. a 19:00 IST start judged "passed" at 13:30 IST on an IST device).
/// With BOTH sides carried as plain wall-clock values, epoch comparison is
/// wall-clock comparison, on any device timezone.
DateTime nowInIst() {
  final u = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

/// Today's date (midnight) on the IST business clock.
DateTime istToday() {
  final n = nowInIst();
  return DateTime(n.year, n.month, n.day);
}

final _uuidShape = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}'
  r'-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Whether a tier id is even structurally capable of being a real database
/// tier. Old persisted drafts can carry legacy fallback ids ('budget',
/// 'standard', 'premium') that no longer exist anywhere — the shared
/// cascade treats those as MISSING so Home, Event Details and Checkout all
/// see the draft as incomplete without needing the tier list loaded.
/// (Whether a well-shaped id is still ACTIVE is reconciled by the Event
/// Details tier picker once tiers load, and finally by place_order.)
bool isUuidShapedTierId(String id) => _uuidShape.hasMatch(id);

/// The next unfinished step of the plan-your-event flow for an in-progress
/// [EventDraft]: the hint to surface and the route that fixes it.
///
/// THE single validation cascade — Event Details' Continue gate, the home
/// "Continue planning" card and checkoutPlanningGap all consume this same
/// function, and place_order mirrors it server-side, so no two surfaces can
/// disagree about what "complete" means.
class PlanningStep {
  const PlanningStep({required this.hint, required this.route});

  /// Short call-to-action, e.g. "Pick a banquet venue to finish".
  final String hint;

  /// Route to push when the user acts on the hint. For the "everything is
  /// planned" case this is [AppRoutes.userHome] — the caller appends the
  /// `scrollTo=restaurants` nonce so the home list scrolls into view.
  final String route;
}

/// Resolve the next step from [d]. Order mirrors the real flow: the fields
/// the event-details screen owns (name, session, date, times, schedule
/// validity, location, confirmed coordinates, guests, tier), then the venue
/// branch, then browsing restaurants.
///
/// [now] is the IST business-clock instant to validate the schedule
/// against; injectable for tests, defaults to [nowInIst].
PlanningStep planningNextStep(EventDraft d, {DateTime? now}) {
  final ist = now ?? nowInIst();
  final today = DateTime(ist.year, ist.month, ist.day);

  // ── Event-details screen's own fields ──
  if (d.eventName?.trim().isEmpty ?? true) {
    return const PlanningStep(
      hint: 'Name your event to start',
      route: AppRoutes.eventDetails,
    );
  }
  if (d.session == null || d.session!.trim().isEmpty) {
    return const PlanningStep(
      hint: 'Pick a session (lunch / dinner / high tea)',
      route: AppRoutes.eventDetails,
    );
  }
  if (d.date == null) {
    return const PlanningStep(
      hint: 'Pick a date to lock pricing',
      route: AppRoutes.eventDetails,
    );
  }
  if (d.startTime == null || d.endTime == null) {
    return const PlanningStep(
      hint: 'Set the start & end time',
      route: AppRoutes.eventDetails,
    );
  }
  // Schedule validity — catches restored stale drafts and date changes that
  // silently dragged a picked time into the past.
  if (d.date!.isBefore(today)) {
    return const PlanningStep(
      hint: 'That date has passed — pick a new event date',
      route: AppRoutes.eventDetails,
    );
  }
  if (!d.endTime!.isAfter(d.startTime!)) {
    return const PlanningStep(
      hint: 'End time must be after the start time',
      route: AppRoutes.eventDetails,
    );
  }
  if (!d.startTime!.isAfter(ist)) {
    return const PlanningStep(
      hint: 'That start time has passed — pick a later time',
      route: AppRoutes.eventDetails,
    );
  }
  if (d.location == null || d.location!.trim().isEmpty) {
    return const PlanningStep(
      hint: 'Add the event address',
      route: AppRoutes.eventDetails,
    );
  }
  if (!d.hasEventCoords) {
    return const PlanningStep(
      hint: 'Confirm your event location — pick it from the address '
          'suggestions',
      route: AppRoutes.eventDetails,
    );
  }
  if (d.guestCount < kGuestMin || d.guestCount > kGuestMax) {
    return const PlanningStep(
      hint: 'Guest count must be between $kGuestMin and $kGuestMax',
      route: AppRoutes.eventDetails,
    );
  }
  if (d.tierId == null || !isUuidShapedTierId(d.tierId!)) {
    // Null OR a legacy/non-database id (old 'budget'-style drafts):
    // structurally incomplete everywhere, not just after tiers load.
    return const PlanningStep(
      hint: 'Pick a tier that fits your budget',
      route: AppRoutes.eventDetails,
    );
  }

  // ── Step 2: the venue branch ──
  if (d.venueType == null) {
    return const PlanningStep(
      hint: 'Choose your venue type',
      route: AppRoutes.eventVenueType,
    );
  }
  final isPrivate = d.venueType == VenueType.privateProperty;
  final venueStepDone = isPrivate
      ? (d.propertyDraft?.isComplete ?? false)
      : d.banquetVenueId != null;
  if (!venueStepDone) {
    return isPrivate
        ? const PlanningStep(
            hint: 'Complete your property details to finish',
            route: AppRoutes.eventProperty,
          )
        : const PlanningStep(
            hint: 'Pick a banquet venue to finish',
            route: AppRoutes.eventVenueType,
          );
  }

  // A banquet hall picked earlier stays "done" only while it still fits the
  // party. A later guest-count bump past the capacity captured at selection
  // re-opens the venue step HERE — in the ONE shared cascade — so Event
  // Details' Continue, Home's "Continue planning" and the checkout gate all
  // agree the hall must be reconfirmed, instead of routing straight past the
  // venue screen to the restaurant browser and only failing at place_order.
  // Uses the draft's captured capacity (no network read); unknown capacity is
  // never blocked, exactly like the picker query, the tap gate and the server
  // — place_order re-checks LIVE capacity as the final authority.
  if (!isPrivate &&
      d.banquetVenueCapacity != null &&
      d.guestCount > d.banquetVenueCapacity!) {
    return const PlanningStep(
      hint: 'Your banquet hall no longer fits your guest count — pick a '
          'larger venue',
      route: AppRoutes.eventVenueType,
    );
  }

  // ── Everything planned — go browse restaurants / add dishes ──
  return const PlanningStep(
    hint: 'Add dishes to finalise the menu',
    route: AppRoutes.userHome,
  );
}
