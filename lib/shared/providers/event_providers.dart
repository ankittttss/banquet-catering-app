import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/event_draft.dart';

/// Holds the in-progress event the user is planning. Lives until checkout.
class EventDraftController extends Notifier<EventDraft> {
  @override
  EventDraft build() => const EventDraft();

  void setDate(DateTime d) => state = state.copyWith(date: d);
  void setLocation(String v) => state = state.copyWith(location: v);
  void setSession(String v) => state = state.copyWith(session: v);
  void setStartTime(DateTime v) => state = state.copyWith(startTime: v);
  void setEndTime(DateTime v) => state = state.copyWith(endTime: v);
  void setGuestCount(int v) {
    // Update guest count, then auto-raise the explicit serviceBoyCount if
    // the user had previously chosen one that's now below the new minimum.
    // A null override (i.e. still tracking the suggestion) needs no work —
    // effectiveServiceBoyCount falls back to suggestedServiceBoys.
    final next = state.copyWith(guestCount: v);
    final min = next.suggestedServiceBoys;
    if (state.serviceBoyCount != null && state.serviceBoyCount! < min) {
      state = next.copyWith(serviceBoyCount: min);
    } else {
      state = next;
    }
  }
  void setTier({required String tierId, required String tierCode}) =>
      state = state.copyWith(tierId: tierId, tierCode: tierCode);
  void setBanquetVenue({required String venueId, required String venueName}) =>
      state = state.copyWith(
        banquetVenueId: venueId,
        banquetVenueName: venueName,
      );
  void setServiceBoyCount(int v) =>
      state = state.copyWith(
        serviceBoyCount: v.clamp(state.suggestedServiceBoys, 999),
      );
  void bumpServiceBoyCount(int delta) {
    // Floor at the recommended minimum — the minus button cannot drop the
    // count below suggestedServiceBoys (1 per ~20 guests, min 1).
    final min = state.suggestedServiceBoys;
    final next = (state.effectiveServiceBoyCount + delta).clamp(min, 999);
    state = state.copyWith(serviceBoyCount: next);
  }
  void reset() => state = const EventDraft();
}

final eventDraftProvider =
    NotifierProvider<EventDraftController, EventDraft>(
  EventDraftController.new,
);
