import '../../core/router/app_routes.dart';
import '../../data/models/event_draft.dart';
import 'planning_next_step.dart';

/// A reason checkout is blocked, plus where to send the customer to fix it.
class CheckoutGap {
  const CheckoutGap({required this.message, required this.route});
  final String message;
  final String route;
}

/// The first missing piece of the REAL planning workflow, or null when the
/// order may proceed. Pure — unit-tested, and the checkout screen uses it
/// for both the visible banner and the place-order gate, so they can't
/// drift.
///
/// Checkout no longer backfills anything: no default session/times, and the
/// saved home address is NEVER turned into the event location. The address
/// may prefill Event Details (it already does), but the customer must walk
/// the actual flow. Requirements (mirrored server-side in place_order,
/// phase42):
///  • event name + date
///  • session and start/end time — really chosen, not defaulted
///  • event location with CONFIRMED coordinates
///  • a package/tier
///  • venue type chosen; banquet hall → a venue selected,
///    private property → property details complete
CheckoutGap? checkoutPlanningGap(EventDraft draft) {
  if (draft.eventName?.trim().isEmpty ?? true) {
    return const CheckoutGap(
      message: 'Name your event before placing the order.',
      route: AppRoutes.eventDetails,
    );
  }
  // planningNextStep is the SAME cascade the "Continue planning" card uses:
  // session → date → times → location → tier → venue branch. Only when it
  // says "browse restaurants" (route == userHome) is planning complete.
  final step = planningNextStep(draft);
  if (step.route != AppRoutes.userHome) {
    return CheckoutGap(
      message: 'Finish planning your event first: ${step.hint}',
      route: step.route,
    );
  }
  if (!draft.hasEventCoords) {
    return const CheckoutGap(
      message: 'Confirm your event location — pick it from the address '
          'suggestions on the event details page.',
      route: AppRoutes.eventDetails,
    );
  }
  return null;
}
