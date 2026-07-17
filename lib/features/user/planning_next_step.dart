import '../../core/router/app_routes.dart';
import '../../data/models/event_draft.dart';
import '../../data/models/venue_type.dart';

/// The next unfinished step of the plan-your-event flow for an in-progress
/// [EventDraft]: the hint to surface on the home "Continue planning" card and
/// the route that card should open when tapped.
///
/// Kept as a pure, standalone function (rather than buried in the home screen)
/// so the hint and its destination come out of ONE cascade — they can never
/// drift apart — and so the routing can be unit-tested without pumping the
/// widget tree.
class PlanningStep {
  const PlanningStep({required this.hint, required this.route});

  /// Short call-to-action, e.g. "Pick a banquet venue to finish".
  final String hint;

  /// Route to push when the user taps Continue. For the "everything is
  /// planned" case this is [AppRoutes.userHome] — the caller appends the
  /// `scrollTo=restaurants` nonce so the home list scrolls into view.
  final String route;
}

/// Resolve the next step from [d]. The order mirrors the real screen flow:
/// steps 1–5 (session, date, time, location, package) all live on the
/// event-details screen, then the venue branch, then browsing restaurants.
PlanningStep planningNextStep(EventDraft d) {
  final isPrivate = d.venueType == VenueType.privateProperty;
  final venueStepDone = isPrivate
      ? (d.propertyDraft?.isComplete ?? false)
      : d.banquetVenueId != null;

  // ── Steps 1–5: all captured on the event-details screen ──
  if (d.session == null) {
    return const PlanningStep(
      hint: 'Pick the session to start',
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
  if (d.location == null || d.location!.trim().isEmpty) {
    return const PlanningStep(
      hint: 'Add the event address',
      route: AppRoutes.eventDetails,
    );
  }
  if (d.tierId == null) {
    return const PlanningStep(
      hint: 'Pick a tier that fits your budget',
      route: AppRoutes.eventDetails,
    );
  }

  // ── Step 6: the venue branch ──
  if (d.venueType == null) {
    // Haven't chosen hall vs private yet — send them to the venue-type
    // screen. (The old copy jumped straight to "Pick a banquet venue", which
    // was premature since no branch had been chosen.)
    return const PlanningStep(
      hint: 'Choose your venue type',
      route: AppRoutes.eventVenueType,
    );
  }
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

  // ── Everything planned — go browse restaurants / add dishes ──
  return const PlanningStep(
    hint: 'Add dishes to finalise the menu',
    route: AppRoutes.userHome,
  );
}
