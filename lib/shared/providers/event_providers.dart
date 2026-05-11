import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chef.dart';
import '../../data/models/event_draft.dart';
import '../../data/models/private_property.dart';
import '../../data/models/venue_type.dart';

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

  /// Switch between hall and private-property branches. Selecting one
  /// invalidates the data for the other path so we don't carry stale
  /// banquet venue / property fields across user changes.
  void setVenueType(VenueType type) {
    final s = state;
    if (type == VenueType.banquetHall) {
      state = EventDraft(
        date: s.date,
        location: s.location,
        session: s.session,
        startTime: s.startTime,
        endTime: s.endTime,
        guestCount: s.guestCount,
        tierId: s.tierId,
        tierCode: s.tierCode,
        banquetVenueId: s.banquetVenueId,
        banquetVenueName: s.banquetVenueName,
        serviceBoyCount: s.serviceBoyCount,
        venueType: type,
        propertyDraft: null,
        addonQuantities: const {},
        recce: null,
      );
    } else {
      state = EventDraft(
        date: s.date,
        location: s.location,
        session: s.session,
        startTime: s.startTime,
        endTime: s.endTime,
        guestCount: s.guestCount,
        tierId: s.tierId,
        tierCode: s.tierCode,
        banquetVenueId: null,
        banquetVenueName: null,
        serviceBoyCount: s.serviceBoyCount,
        venueType: type,
        propertyDraft:
            s.propertyDraft ?? const PrivatePropertyDraft(),
        addonQuantities: s.addonQuantities,
        recce: s.recce,
      );
    }
  }

  void setPropertyType(PropertyType type) {
    final current = state.propertyDraft ?? const PrivatePropertyDraft();
    state = state.copyWith(propertyDraft: current.copyWith(type: type));
  }

  void setPropertyAddress({
    String? line1,
    String? landmark,
    String? cityPincode,
  }) {
    final current = state.propertyDraft ?? const PrivatePropertyDraft();
    state = state.copyWith(
      propertyDraft: current.copyWith(
        addressLine1: line1,
        landmark: landmark,
        cityPincode: cityPincode,
      ),
    );
  }

  void setAddonQuantity(String addonId, int qty) {
    final next = Map<String, int>.from(state.addonQuantities);
    if (qty <= 0) {
      next.remove(addonId);
    } else {
      next[addonId] = qty;
    }
    state = state.copyWith(addonQuantities: next);
  }

  void bumpAddon(String addonId, int delta, {int min = 0, int max = 9999}) {
    final current = state.addonQuantities[addonId] ?? 0;
    setAddonQuantity(addonId, (current + delta).clamp(min, max));
  }

  /// Replace the current selection with the bundle's quantities. Merges
  /// with what the user already had so we never silently drop a manually
  /// adjusted line.
  void applyAddonBundle(Map<String, int> bundleQuantities) {
    final next = Map<String, int>.from(state.addonQuantities);
    bundleQuantities.forEach((id, qty) {
      final existing = next[id] ?? 0;
      // Pick the larger of the two so re-applying a bundle never reduces
      // a count the user already bumped up.
      next[id] = existing > qty ? existing : qty;
    });
    state = state.copyWith(addonQuantities: next);
  }

  void setRecceChef(String chefId) {
    final current = state.recce ?? const ReccePick();
    state = state.copyWith(recce: current.copyWith(chefId: chefId));
  }

  void setRecceDay(DateTime day) {
    final current = state.recce ?? const ReccePick();
    // Picking a new day always clears the slot — slots are day-specific.
    state = state.copyWith(
      recce: ReccePick(
        chefId: current.chefId,
        day: day,
      ),
    );
  }

  void setRecceSlot(String slotLabel) {
    final current = state.recce ?? const ReccePick();
    state = state.copyWith(recce: current.copyWith(slotLabel: slotLabel));
  }

  void clearRecce() => state = state.copyWith(recce: const ReccePick());

  void reset() => state = const EventDraft();
}

final eventDraftProvider =
    NotifierProvider<EventDraftController, EventDraft>(
  EventDraftController.new,
);
