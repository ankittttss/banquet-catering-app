import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/addon.dart';
import 'event_providers.dart';

/// Stub catalogue of add-ons rented for private-property events. Values
/// mirror the design mock — when we add a Supabase table for these, this
/// provider is the single seam that swaps in a real fetch.
final addonCatalogProvider = Provider<List<Addon>>((ref) {
  return const [
    // ─── Shelter & seating ────────────────────────────────────────────
    Addon(
      id: 'mughal_pole_tent',
      group: 'SHELTER & SEATING',
      label: 'Mughal-pole tent',
      subtitle: 'Up to 200 guests · 30×40 ft',
      iconName: 'home_filled',
      iconBgHex: '#FFF1F2',
      iconHex: '#1BA672',
      unitPrice: 18000,
      unitLabel: 'unit',
      defaultQty: 1,
      recommended: true,
    ),
    Addon(
      id: 'round_dining_table',
      group: 'SHELTER & SEATING',
      label: 'Round dining table',
      subtitle: 'Seats 8 · linen included',
      iconName: 'restaurant',
      iconBgHex: '#FFF1F2',
      iconHex: '#B88300',
      unitPrice: 450,
      unitLabel: 'table',
      defaultQty: 19,
    ),
    Addon(
      id: 'cushioned_chair',
      group: 'SHELTER & SEATING',
      label: 'Cushioned chair',
      subtitle: 'Banquet style · gold trim',
      iconName: 'celebration',
      iconBgHex: '#FFF1F2',
      iconHex: '#D63384',
      unitPrice: 60,
      unitLabel: 'chair',
      defaultQty: 150,
    ),
    // ─── Kitchen & equipment ──────────────────────────────────────────
    Addon(
      id: 'live_counter_station',
      group: 'KITCHEN & EQUIPMENT',
      label: 'Live counter station',
      subtitle: 'Chef + burner + counter',
      iconName: 'set_meal',
      iconBgHex: '#FFF1F2',
      iconHex: '#E23744',
      unitPrice: 4500,
      unitLabel: 'station',
      defaultQty: 2,
    ),
    Addon(
      id: 'genset_silent_15kva',
      group: 'KITCHEN & EQUIPMENT',
      label: 'Silent genset 15 KVA',
      subtitle: 'Backup power · 4-hour run',
      iconName: 'local_fire_department',
      iconBgHex: '#FFF8E7',
      iconHex: '#E5A100',
      unitPrice: 3500,
      unitLabel: 'unit',
      defaultQty: 1,
    ),
    Addon(
      id: 'water_dispenser',
      group: 'KITCHEN & EQUIPMENT',
      label: 'Water dispenser',
      subtitle: '20-L chilled · refilled',
      iconName: 'water_drop',
      iconBgHex: '#EBF4FF',
      iconHex: '#2B6CB0',
      unitPrice: 600,
      unitLabel: 'unit',
      defaultQty: 3,
    ),
  ];
});

/// Quick-apply bundles surfaced on the Setup & equipment screen.
final addonBundlesProvider = Provider<List<AddonBundle>>((ref) {
  return const [
    AddonBundle(
      id: 'open_lawn',
      name: 'OPEN LAWN',
      description: 'Tent · 250 chairs · genset · lights',
      tintHex: '#EAFAF1',
      colorHex: '#1BA672',
      quantities: {
        'mughal_pole_tent': 1,
        'cushioned_chair': 250,
        'genset_silent_15kva': 1,
      },
    ),
    AddonBundle(
      id: 'home_dinner',
      name: 'HOME DINNER',
      description: 'Tables · servers · florals',
      tintHex: '#FFF1F2',
      colorHex: '#E23744',
      quantities: {
        'round_dining_table': 8,
        'cushioned_chair': 64,
        'water_dispenser': 2,
      },
    ),
  ];
});

/// Default add-on selection sized to the current guest count. Used to
/// seed the Setup screen the first time the user lands on it.
final defaultAddonSelectionProvider = Provider<Map<String, int>>((ref) {
  final catalog = ref.watch(addonCatalogProvider);
  final guests = ref.watch(eventDraftProvider).guestCount;
  return {
    for (final a in catalog)
      a.id: a.id == 'cushioned_chair'
          // Chairs scale per guest, rounded to nearest 5 above.
          ? ((guests + 4) ~/ 5) * 5
          : a.id == 'round_dining_table'
              // 1 table per 8 guests, rounded up.
              ? ((guests + 7) ~/ 8)
              : a.defaultQty,
  };
});

/// Running total of the currently selected add-ons in rupees.
final addonsTotalProvider = Provider<double>((ref) {
  final catalog = ref.watch(addonCatalogProvider);
  final qty = ref.watch(eventDraftProvider).addonQuantities;
  double total = 0;
  for (final a in catalog) {
    final q = qty[a.id] ?? 0;
    total += a.unitPrice * q;
  }
  return total;
});

/// Count of distinct add-ons currently selected (qty > 0).
final addonsCountProvider = Provider<int>((ref) {
  final qty = ref.watch(eventDraftProvider).addonQuantities;
  return qty.values.where((v) => v > 0).length;
});
