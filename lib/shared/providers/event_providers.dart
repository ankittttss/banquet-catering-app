import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/chef.dart';
import '../../data/models/event_draft.dart';
import '../../data/models/private_property.dart';
import '../../data/models/venue_type.dart';

const _draftPrefsKey = 'dawat.event_draft.v1';

/// Holds the in-progress event the user is planning. Lives until checkout.
class EventDraftController extends Notifier<EventDraft> {
  Timer? _persistDebounce;

  @override
  EventDraft build() {
    // Hydrate from disk on first build so a force-quit mid-flow doesn't
    // wipe the draft. The initial state stays empty until the async read
    // completes, then we replace it (Riverpod re-renders subscribers).
    _hydrate();
    // Persist on every state change. listenSelf fires synchronously after
    // any assignment to `state`, so callers don't need to remember.
    listenSelf((_, __) => _schedulePersist());
    ref.onDispose(() {
      _persistDebounce?.cancel();
    });
    return const EventDraft();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      // Discard payloads from a different schema version.
      if ((json['v'] as num?)?.toInt() != 1) {
        await prefs.remove(_draftPrefsKey);
        return;
      }
      // Don't clobber a draft the user has already started typing into
      // during the same session (rare but possible if hydrate races a
      // first-frame interaction).
      if (state != const EventDraft()) return;
      state = EventDraft.fromJson(json);
    } catch (e, st) {
      debugPrint('EventDraftController.hydrate failed: $e\n$st');
    }
  }

  /// Debounced write to shared_preferences. The debounce keeps a noisy
  /// slider drag from hammering disk while still flushing within ~250 ms
  /// of the last edit.
  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (state == const EventDraft()) {
          await prefs.remove(_draftPrefsKey);
          return;
        }
        await prefs.setString(_draftPrefsKey, jsonEncode(state.toJson()));
      } catch (e, st) {
        debugPrint('EventDraftController.persist failed: $e\n$st');
      }
    });
  }

  void setEventName(String? name) {
    final trimmed = name?.trim();
    // Treat empty string as "clear it" so the home draft card falls back
    // to the composed title.
    if (trimmed == null || trimmed.isEmpty) {
      // copyWith with eventName == null keeps the existing value, so to
      // actually clear we have to rebuild manually.
      final s = state;
      state = EventDraft(
        eventName: null,
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
        venueType: s.venueType,
        propertyDraft: s.propertyDraft,
        addonQuantities: s.addonQuantities,
        recce: s.recce,
      );
      return;
    }
    state = state.copyWith(eventName: trimmed);
  }

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
