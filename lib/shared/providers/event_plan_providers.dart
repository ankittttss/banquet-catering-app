import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/event_tier.dart';
import '../../data/models/venue_type.dart';
import '../../features/user/event_plan_summary.dart';
import 'addon_providers.dart';
import 'banquet_providers.dart';
import 'event_providers.dart';
import 'event_tier_providers.dart';

/// Placeholders for lookups this draft does not need. The matching branch in
/// [buildEventPlanSummary] short-circuits before reading them, so they are
/// never interpreted as real answers.
const _skippedTiers = AsyncValue<List<EventTier>>.data(<EventTier>[]);
const _skippedVenue =
    AsyncValue<VenueCheck>.data(VenueCheck(VenueCheckState.none));

/// THE shared event summary — one completion verdict for the home card, the
/// Event Plan page and (Phase 1b) Cart/Checkout.
///
/// It combines the three authorities rather than re-deriving any of them:
///   • [planningNextStep] via [buildEventPlanSummary] — structural completeness
///   • [eventTiersProvider] + [resolveSelectedTier] — the package still exists
///     and is active
///   • [selectedBanquetVenueCheckProvider] — the hall is still active and fits
///
/// While either live check is loading or errored the summary reports
/// "checking"/"needs attention" — never ready.
///
/// Dependencies are watched CONDITIONALLY so an untouched draft (or a plan that
/// cannot possibly need a lookup) costs nothing: Riverpod only subscribes to
/// what `ref.watch` actually runs on a given build.
final eventPlanSummaryProvider = Provider<EventPlanSummary>((ref) {
  final draft = ref.watch(eventDraftProvider);

  // Nothing planned → "Plan an event". No tier, venue or add-on work at all.
  if (!hasMeaningfulDraft(draft)) {
    return buildEventPlanSummary(
      draft: draft,
      tiers: _skippedTiers,
      venueCheck: _skippedVenue,
      addonCount: 0,
    );
  }

  final isPrivate = draft.venueType == VenueType.privateProperty;
  // Only fetch the tier list when there is a selection to validate.
  final needsTier = draft.tierId != null;
  // Only fetch the hall by id for a banquet plan that actually has one.
  final needsVenue =
      draft.venueType == VenueType.banquetHall && draft.banquetVenueId != null;

  return buildEventPlanSummary(
    draft: draft,
    tiers: needsTier ? ref.watch(eventTiersProvider) : _skippedTiers,
    venueCheck: needsVenue
        ? ref.watch(selectedBanquetVenueCheckProvider)
        : _skippedVenue,
    // Add-ons only appear on private-property summaries.
    addonCount: isPrivate ? ref.watch(addonsCountProvider) : 0,
  );
});
