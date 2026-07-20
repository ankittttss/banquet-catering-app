import '../../core/router/app_routes.dart';
import '../../data/models/event_draft.dart';
import 'planning_next_step.dart';

/// A reason checkout is blocked, plus where to send the customer to fix it.
class CheckoutGap {
  const CheckoutGap({required this.message, required this.route});
  final String message;
  final String route;
}

/// The first missing piece of the planning workflow, or null when the order
/// may proceed.
///
/// A thin wrapper over [planningNextStep] — THE shared cascade (name,
/// session, date, times, IST schedule validity, location, confirmed
/// coordinates, guest range, tier, venue branch) — so checkout, the
/// event-details Continue gate and the home card can never disagree.
/// place_order enforces the same rules server-side for direct RPC callers.
CheckoutGap? checkoutPlanningGap(EventDraft draft, {DateTime? now}) {
  final step = planningNextStep(draft, now: now);
  if (step.route == AppRoutes.userHome) return null; // planning complete
  return CheckoutGap(message: step.hint, route: step.route);
}
