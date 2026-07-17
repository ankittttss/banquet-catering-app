import '../models/cart_item.dart';
import '../models/event_draft.dart';

/// Pure builders for the `place_order` RPC payloads — separated from the
/// repository so booking persistence can be unit-tested without Supabase.
///
/// Everything the customer chose during planning goes to the server:
/// category, venue type, coordinates, private-property details and add-on
/// selections (all previously dropped), alongside the core event fields.

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Map<String, dynamic> orderEventPayload(EventDraft e) => {
      if (e.eventName != null && e.eventName!.trim().isNotEmpty)
        'name': e.eventName!.trim(),
      'event_date': e.date!.toIso8601String().substring(0, 10),
      'location': e.location,
      'session': e.session,
      'start_time': _hhmm(e.startTime!),
      'end_time': _hhmm(e.endTime!),
      'guest_count': e.guestCount,
      if (e.tierId != null) 'tier_id': e.tierId,
      if (e.banquetVenueId != null) 'banquet_venue_id': e.banquetVenueId,
      if (e.categorySlug != null) 'category_slug': e.categorySlug,
      if (e.venueType != null) 'venue_type': e.venueType!.dbValue,
      if (e.eventLatitude != null) 'event_latitude': e.eventLatitude,
      if (e.eventLongitude != null) 'event_longitude': e.eventLongitude,
      if (e.propertyDraft != null)
        'property_details': e.propertyDraft!.toJson(),
      if (e.addonQuantities.isNotEmpty) 'addon_selections': e.addonQuantities,
    };

List<Map<String, dynamic>> orderItemsPayload(List<CartItem> cart) => [
      for (final c in cart)
        {
          'menu_item_id': c.item.id,
          'qty_per_guest': c.qty,
          'portion_multiplier': c.portion.multiplier,
          'portion': c.portion.name,
          'spice': c.spice.name,
          if (c.notes.trim().isNotEmpty) 'notes': c.notes.trim(),
        },
    ];
