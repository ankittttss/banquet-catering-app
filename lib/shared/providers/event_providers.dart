import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/event_category.dart';
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
        categorySlug: s.categorySlug,
        date: s.date,
        location: s.location,
        eventLatitude: s.eventLatitude,
        eventLongitude: s.eventLongitude,
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
      );
      return;
    }
    state = state.copyWith(eventName: trimmed);
  }

  /// Apply an occasion picked on the home grid / plan screen — records the
  /// slug (so the chip shows pre-selected everywhere) and seeds its default
  /// session + guest count.
  void setCategory(EventCategory cat) {
    state = state.copyWith(
      categorySlug: cat.slug,
      session: cat.defaultSession,
    );
    setGuestCount(cat.defaultGuestCount);
  }

  /// Change the event date, re-anchoring any already-picked start/end times
  /// onto the new date (previously they silently stayed on the old date).
  void setDate(DateTime d) {
    final s = state;
    DateTime? anchor(DateTime? t) =>
        t == null ? null : DateTime(d.year, d.month, d.day, t.hour, t.minute);
    state = s.copyWith(
      date: d,
      startTime: anchor(s.startTime),
      endTime: anchor(s.endTime),
    );
  }

  /// Set the event location together with its coordinates (address search,
  /// saved-address prefill).
  ///
  /// The coordinates are set to EXACTLY the passed values — a rebuild is used
  /// (not copyWith) so that passing null lat/lng CLEARS any previously-pinned
  /// point. Otherwise the restaurant list would keep sorting around the old
  /// venue while showing the new address.
  ///
  /// Changing the location also INVALIDATES the location-dependent choices:
  /// • a previously selected banquet venue is cleared — the event no longer
  ///   happens there, so the hall must be picked again (otherwise the order
  ///   would still route to the OLD venue while restaurants are chosen
  ///   around the NEW address);
  /// • the private property's address fields are cleared (they described the
  ///   old location) — the property TYPE survives, but details must be
  ///   reconfirmed.
  /// The initial prefill is unaffected: at that point no venue or property
  /// details exist yet, so the clears are no-ops.
  void setEventLocation({
    required String address,
    double? latitude,
    double? longitude,
  }) {
    final s = state;
    final property = s.propertyDraft == null
        ? null
        : PrivatePropertyDraft(type: s.propertyDraft!.type);
    state = EventDraft(
      eventName: s.eventName,
      categorySlug: s.categorySlug,
      date: s.date,
      location: address,
      eventLatitude: latitude,
      eventLongitude: longitude,
      session: s.session,
      startTime: s.startTime,
      endTime: s.endTime,
      guestCount: s.guestCount,
      tierId: s.tierId,
      tierCode: s.tierCode,
      banquetVenueId: null,
      banquetVenueName: null,
      serviceBoyCount: s.serviceBoyCount,
      venueType: s.venueType,
      propertyDraft: property,
      addonQuantities: s.addonQuantities,
    );
  }

  void setSession(String v) => state = state.copyWith(session: v);

  /// Set the start time and keep the end time consistent: the previous
  /// duration is preserved when one exists, otherwise end defaults to
  /// start + 3h. (Previously a start-time change left the old end time in
  /// place — end could silently land BEFORE the new start.)
  void setStartTime(DateTime v) {
    final s = state;
    Duration span = const Duration(hours: 3);
    if (s.startTime != null && s.endTime != null) {
      final prev = s.endTime!.difference(s.startTime!);
      if (!prev.isNegative && prev.inMinutes > 0) span = prev;
    }
    state = s.copyWith(startTime: v, endTime: v.add(span));
  }

  /// Set the end time directly. Ignored (kept unchanged) when it wouldn't
  /// land after the current start — callers surface their own message.
  void setEndTime(DateTime v) {
    final s = state;
    if (s.startTime != null && !v.isAfter(s.startTime!)) return;
    state = s.copyWith(endTime: v);
  }

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

  /// Select a banquet venue for a hall event. The event physically happens
  /// AT the venue, so its address + coordinates become the event location —
  /// otherwise restaurants would keep being recommended near the customer's
  /// home / previously-typed address instead of the venue (the food is also
  /// delivered to the venue). A rebuild (not copyWith) is used so a venue
  /// without coordinates clears any stale pin rather than keeping the old one.
  void setBanquetVenue({
    required String venueId,
    required String venueName,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    final s = state;
    final venueLocation = (address != null && address.trim().isNotEmpty)
        ? address.trim()
        : venueName;
    state = EventDraft(
      eventName: s.eventName,
      categorySlug: s.categorySlug,
      date: s.date,
      location: venueLocation,
      eventLatitude: latitude,
      eventLongitude: longitude,
      session: s.session,
      startTime: s.startTime,
      endTime: s.endTime,
      guestCount: s.guestCount,
      tierId: s.tierId,
      tierCode: s.tierCode,
      banquetVenueId: venueId,
      banquetVenueName: venueName,
      serviceBoyCount: s.serviceBoyCount,
      venueType: s.venueType,
      propertyDraft: s.propertyDraft,
      addonQuantities: s.addonQuantities,
    );
  }

  /// Late coordinate pin for a banquet venue that was saved WITHOUT coords —
  /// a background geocode of its address calls this once the lookup lands.
  /// Ignored when the user has since picked a different venue (or cleared
  /// it), or when coordinates arrived some other way in the meantime, so a
  /// slow lookup can never stamp a stale point onto a newer draft.
  void pinVenueCoords({
    required String venueId,
    required double latitude,
    required double longitude,
  }) {
    final s = state;
    if (s.banquetVenueId != venueId || s.hasEventCoords) return;
    state = s.copyWith(eventLatitude: latitude, eventLongitude: longitude);
  }

  void setServiceBoyCount(int v) => state = state.copyWith(
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
        eventName: s.eventName,
        categorySlug: s.categorySlug,
        date: s.date,
        location: s.location,
        eventLatitude: s.eventLatitude,
        eventLongitude: s.eventLongitude,
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
      );
    } else {
      state = EventDraft(
        eventName: s.eventName,
        categorySlug: s.categorySlug,
        date: s.date,
        location: s.location,
        eventLatitude: s.eventLatitude,
        eventLongitude: s.eventLongitude,
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
        propertyDraft: s.propertyDraft ?? const PrivatePropertyDraft(),
        addonQuantities: s.addonQuantities,
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

  void reset() => state = const EventDraft();
}

final eventDraftProvider = NotifierProvider<EventDraftController, EventDraft>(
  EventDraftController.new,
);
