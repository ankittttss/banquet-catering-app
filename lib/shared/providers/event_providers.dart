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
  void reset() => state = const EventDraft();
}

final eventDraftProvider =
    NotifierProvider<EventDraftController, EventDraft>(
  EventDraftController.new,
);
