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
  void setGuestCount(int v) => state = state.copyWith(guestCount: v);
  void setTier({required String tierId, required String tierCode}) =>
      state = state.copyWith(tierId: tierId, tierCode: tierCode);
  void setBanquetVenue({required String venueId, required String venueName}) =>
      state = state.copyWith(
        banquetVenueId: venueId,
        banquetVenueName: venueName,
      );
  void setServiceBoyCount(int v) =>
      state = state.copyWith(serviceBoyCount: v.clamp(0, 999));
  void bumpServiceBoyCount(int delta) {
    final next = (state.effectiveServiceBoyCount + delta).clamp(0, 999);
    state = state.copyWith(serviceBoyCount: next);
  }
  void reset() => state = const EventDraft();
}

final eventDraftProvider =
    NotifierProvider<EventDraftController, EventDraft>(
  EventDraftController.new,
);
