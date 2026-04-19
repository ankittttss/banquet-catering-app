// ============================================================================
// generate_menu_items.dart
//
// Generates realistic menu_items rows for every restaurant that doesn't
// already have any. Picks items from cuisine-matched templates and skews
// pricing with a seeded random so re-runs stay stable.
//
// Usage:
//   $env:SUPABASE_URL="https://<project>.supabase.co"
//   $env:SUPABASE_SERVICE_ROLE_KEY="<key>"
//   dart run tool/generate_menu_items.dart
//
// Flags:
//   [--dry-run]   # just print what would be inserted
//   [--limit=N]   # only process the first N restaurants (default: all)
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

// ─────────────────────────── Menu template bank ──────────────────────────
// Every item knows: what cuisine-tags it fits, category, base price, veg flag.
// During generation we filter by cuisine overlap first; fallbacks ensure
// every restaurant ends up with a full menu.

class _Item {
  const _Item(
    this.category,
    this.name,
    this.description,
    this.basePrice,
    this.isVeg, {
    this.tags = const [],
  });
  final String category; // matches menu_categories.name
  final String name;
  final String description;
  final int basePrice; // ₹
  final bool isVeg;
  final List<String> tags;
}

const _bank = <_Item>[
  // ── Welcome Drinks ──
  _Item('Welcome Drinks', 'Masala Lemonade', 'Fresh lime with cumin & black salt', 80, true),
  _Item('Welcome Drinks', 'Rose Sharbat', 'Chilled rose milk with pistachios', 90, true),
  _Item('Welcome Drinks', 'Aam Panna', 'Raw mango cooler, served seasonally', 85, true),
  _Item('Welcome Drinks', 'Jaljeera', 'Tangy cumin-mint cooler', 70, true),
  _Item('Welcome Drinks', 'Buttermilk (Chaas)', 'Spiced yoghurt drink, served chilled', 60, true),
  _Item('Welcome Drinks', 'Sol Kadhi', 'Kokum & coconut milk refresher', 100, true, tags: ['coastal']),
  _Item('Welcome Drinks', 'Filter Coffee', 'Degree-roasted South Indian coffee', 60, true, tags: ['south']),
  _Item('Welcome Drinks', 'Masala Chai', 'Spiced milk tea', 50, true),
  _Item('Welcome Drinks', 'Thandai', 'Almond & saffron cold drink', 110, true, tags: ['north']),

  // ── Starters ──
  _Item('Starters', 'Paneer Tikka', 'Cottage cheese charred in tandoor', 220, true),
  _Item('Starters', 'Hara Bhara Kebab', 'Spinach, peas & potato patties', 180, true),
  _Item('Starters', 'Veg Manchurian Dry', 'Crispy vegetable dumplings, soy-garlic glaze', 200, true, tags: ['chinese']),
  _Item('Starters', 'Crispy Corn', 'Seasoned sweet-corn crunch', 190, true),
  _Item('Starters', 'Gobi 65', 'Batter-fried cauliflower, curry-leaf tempered', 200, true, tags: ['south']),
  _Item('Starters', 'Dahi Kebab', 'Hung curd croquettes, melt-in-mouth', 210, true),
  _Item('Starters', 'Samosa Chaat', 'Crushed samosa with chutneys & yoghurt', 140, true, tags: ['street']),
  _Item('Starters', 'Chicken Tikka', 'Marinated chicken, smoky tandoor', 280, false),
  _Item('Starters', 'Murg Malai Kebab', 'Cream-marinated chicken, mild spices', 280, false),
  _Item('Starters', 'Mutton Seekh Kebab', 'Minced lamb skewers, smoked', 340, false),
  _Item('Starters', 'Tandoori Prawns', 'Marinated prawns, charcoal-grilled', 420, false, tags: ['coastal']),
  _Item('Starters', 'Fish Amritsari', 'Gram-flour battered fish fry', 340, false, tags: ['north']),
  _Item('Starters', 'Chilli Chicken Dry', 'Indo-Chinese wok-tossed chicken', 280, false, tags: ['chinese']),

  // ── Main Course ──
  _Item('Main Course', 'Dal Makhani', 'Slow-cooked black lentils, butter & cream', 200, true, tags: ['north']),
  _Item('Main Course', 'Paneer Butter Masala', 'Cottage cheese in tomato-cashew gravy', 240, true, tags: ['north']),
  _Item('Main Course', 'Kadai Paneer', 'Peppery capsicum & paneer masala', 240, true),
  _Item('Main Course', 'Aloo Gobi', 'Cumin-tempered potato & cauliflower', 180, true),
  _Item('Main Course', 'Chole Bhature', 'Punjabi chickpeas with fluffy fried bread', 180, true, tags: ['north']),
  _Item('Main Course', 'Veg Biryani', 'Fragrant basmati, mixed vegetables, saffron', 220, true, tags: ['biryani']),
  _Item('Main Course', 'Hyderabadi Veg Dum Biryani', 'Layered dum biryani with vegetables', 240, true, tags: ['biryani']),
  _Item('Main Course', 'Mushroom Masala', 'Button mushrooms in rich onion gravy', 230, true),
  _Item('Main Course', 'South Indian Thali', 'Rice, sambhar, rasam, poriyal, curd, papad', 220, true, tags: ['south']),
  _Item('Main Course', 'Idli Sambhar', 'Steamed rice cakes with lentil stew', 140, true, tags: ['south']),
  _Item('Main Course', 'Masala Dosa', 'Crispy crepe, potato masala, coconut chutney', 180, true, tags: ['south']),
  _Item('Main Course', 'Rajma Chawal', 'Kidney-bean curry over steamed rice', 180, true, tags: ['north']),
  _Item('Main Course', 'Dal Baati Churma', 'Baked wheat dumplings, dal, sweet churma', 260, true, tags: ['rajasthani']),
  _Item('Main Course', 'Gatte Ki Sabzi', 'Gram-flour dumplings in yoghurt gravy', 230, true, tags: ['rajasthani']),
  _Item('Main Course', 'Veg Hakka Noodles', 'Stir-fried noodles, soy-ginger', 180, true, tags: ['chinese']),
  _Item('Main Course', 'Veg Fried Rice', 'Burnt-garlic fried rice with vegetables', 180, true, tags: ['chinese']),
  _Item('Main Course', 'Butter Chicken', 'Classic makhani gravy, boneless chicken', 320, false, tags: ['north']),
  _Item('Main Course', 'Chicken Biryani', 'Hyderabadi dum-style, long-grain rice', 280, false, tags: ['biryani']),
  _Item('Main Course', 'Mutton Rogan Josh', 'Kashmiri lamb, red-chilli gravy', 380, false, tags: ['north']),
  _Item('Main Course', 'Andhra Chicken Curry', 'Fiery coconut-chilli curry', 300, false, tags: ['south']),
  _Item('Main Course', 'Goan Fish Curry', 'Tangy coconut curry, steamed rice', 340, false, tags: ['coastal']),
  _Item('Main Course', 'Laal Maas', 'Rajasthani red-chilli mutton curry', 400, false, tags: ['rajasthani']),

  // ── Desserts ──
  _Item('Desserts', 'Gulab Jamun', 'Saffron-soaked milk dumplings, served warm', 90, true),
  _Item('Desserts', 'Rasmalai', 'Flattened cheese in cardamom-saffron milk', 120, true),
  _Item('Desserts', 'Gajar Halwa', 'Ghee-slow-cooked carrot pudding', 130, true, tags: ['north']),
  _Item('Desserts', 'Kulfi Falooda', 'Saffron kulfi with vermicelli', 140, true),
  _Item('Desserts', 'Phirni', 'Ground-rice pudding, rose-saffron', 120, true),
  _Item('Desserts', 'Double Ka Meetha', 'Hyderabadi bread-pudding', 130, true, tags: ['biryani']),
  _Item('Desserts', 'Payasam', 'South Indian rice & jaggery pudding', 120, true, tags: ['south']),
  _Item('Desserts', 'Ghewar', 'Rajasthani disc sweet, rabri-topped', 150, true, tags: ['rajasthani']),
  _Item('Desserts', 'Moong Dal Halwa', 'Slow-cooked lentil halwa, saffron', 150, true),

  // ── Additional ──
  _Item('Additional', 'Pickle & Papad Platter', 'Assorted pickles, roasted papads', 60, true),
  _Item('Additional', 'Raita', 'Whisked yoghurt, cucumber, mint', 80, true),
  _Item('Additional', 'Butter Naan (Set of 2)', 'Clay-oven bread, brushed with butter', 90, true),
  _Item('Additional', 'Lachha Paratha (2)', 'Flaky whole-wheat bread', 100, true),
  _Item('Additional', 'Boondi Raita', 'Fried chickpea pearls in yoghurt', 90, true),
  _Item('Additional', 'Green Salad', 'Cucumber, tomato, onion, lemon', 70, true),
  _Item('Additional', 'Jeera Rice', 'Basmati tempered with cumin', 130, true),
  _Item('Additional', 'Steamed Rice', 'Long-grain basmati', 100, true),
];

// Cuisine-tag detection from the free-form `cuisines_display` field.
List<String> _detectTags(String cuisinesDisplay) {
  final lower = cuisinesDisplay.toLowerCase();
  final tags = <String>{};
  if (lower.contains('north') || lower.contains('mughlai') || lower.contains('punjabi')) {
    tags.add('north');
  }
  if (lower.contains('south') || lower.contains('thali') || lower.contains('andhra') ||
      lower.contains('kerala') || lower.contains('tamil')) {
    tags.add('south');
  }
  if (lower.contains('biryani') || lower.contains('tandoor')) {
    tags.add('biryani');
  }
  if (lower.contains('chinese') || lower.contains('noodle') || lower.contains('manchurian')) {
    tags.add('chinese');
  }
  if (lower.contains('coastal') || lower.contains('sea')) {
    tags.add('coastal');
  }
  if (lower.contains('rajasthani') || lower.contains('marwari')) {
    tags.add('rajasthani');
  }
  if (lower.contains('street') || lower.contains('chaat')) {
    tags.add('street');
  }
  return tags.toList();
}

// Per-category target counts (tuneable).
const _targetCounts = {
  'Welcome Drinks': 3,
  'Starters': 5,
  'Main Course': 7,
  'Desserts': 3,
  'Additional': 3,
};

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final supabaseUrl = ((opts['supabase-url'] ??
              Platform.environment['SUPABASE_URL']) ??
          '')
      .trim();
  final serviceRole = ((opts['service-role'] ??
              Platform.environment['SUPABASE_SERVICE_ROLE_KEY']) ??
          '')
      .trim();
  final dryRun = opts.containsKey('dry-run');
  final limit = int.tryParse(opts['limit'] ?? '');

  if (supabaseUrl.isEmpty || serviceRole.isEmpty) {
    stderr.writeln(
      'Error: missing Supabase credentials.\n'
      'Set env SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY, or pass --supabase-url / --service-role.',
    );
    exit(1);
  }

  final hdrs = {
    'apikey': serviceRole,
    'Authorization': 'Bearer $serviceRole',
    'Content-Type': 'application/json',
  };

  // 1. Fetch categories (id + name).
  print('→ Fetching categories …');
  final catRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/menu_categories?select=id,name'),
    headers: hdrs,
  );
  if (catRes.statusCode != 200) {
    stderr.writeln('Categories fetch failed: HTTP ${catRes.statusCode} ${catRes.body}');
    exit(2);
  }
  final categories = <String, String>{
    for (final c in (jsonDecode(catRes.body) as List))
      (c as Map)['name'] as String: c['id'] as String,
  };
  if (categories.length < 5) {
    stderr.writeln('Expected 5 menu_categories but found ${categories.length}. '
        'Run schema.sql first.');
    exit(3);
  }
  print('  found ${categories.length} categories.');

  // 2. Fetch restaurants (paginated — PostgREST defaults to 1000-row pages).
  print('→ Fetching restaurants …');
  final restaurants = <Map<String, dynamic>>[];
  const pageSize = 1000;
  for (var offset = 0;; offset += pageSize) {
    final rRes = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/restaurants'
          '?select=id,name,cuisines_display,is_pure_veg&is_active=eq.true'),
      headers: {
        ...hdrs,
        'Range': '$offset-${offset + pageSize - 1}',
        'Prefer': 'count=exact',
      },
    );
    if (rRes.statusCode != 200 && rRes.statusCode != 206) {
      stderr.writeln(
          'Restaurants fetch failed: HTTP ${rRes.statusCode} ${rRes.body}');
      exit(2);
    }
    final page = (jsonDecode(rRes.body) as List).cast<Map<String, dynamic>>();
    restaurants.addAll(page);
    if (page.length < pageSize) break;
  }
  print('  fetched ${restaurants.length} active restaurants.');

  print('→ Fetching existing menu_items restaurant ids …');
  final haveMenu = <String>{};
  for (var offset = 0;; offset += pageSize) {
    final miRes = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/menu_items?select=restaurant_id'),
      headers: {
        ...hdrs,
        'Range': '$offset-${offset + pageSize - 1}',
      },
    );
    final page = jsonDecode(miRes.body) as List;
    for (final m in page) {
      haveMenu.add((m as Map)['restaurant_id'] as String);
    }
    if (page.length < pageSize) break;
  }

  final pending =
      restaurants.where((r) => !haveMenu.contains(r['id'])).toList();
  var targets = pending;
  if (limit != null && targets.length > limit) {
    targets = targets.take(limit).toList();
  }
  print('→ ${targets.length} restaurants will get menus '
      '(${haveMenu.length} already have some; ${pending.length} pending total).');

  if (targets.isEmpty) {
    print('Nothing to do.');
    return;
  }

  // 3. Build the rows to insert.
  final rows = <Map<String, dynamic>>[];
  for (final r in targets) {
    final id = r['id'] as String;
    final cuisines = (r['cuisines_display'] as String?) ?? '';
    final pureVeg = (r['is_pure_veg'] as bool?) ?? false;
    final rnd = Random(id.hashCode);
    final wantTags = _detectTags(cuisines);

    for (final entry in _targetCounts.entries) {
      final category = entry.key;
      final needed = entry.value;
      // Eligible: in this category + veg-respecting.
      final pool = _bank
          .where((i) => i.category == category)
          .where((i) => !pureVeg || i.isVeg)
          .toList();
      // Rank: items with overlapping tags first, then by seeded shuffle.
      pool.shuffle(rnd);
      pool.sort((a, b) {
        final aHit = a.tags.any(wantTags.contains) ? 1 : 0;
        final bHit = b.tags.any(wantTags.contains) ? 1 : 0;
        return bHit - aHit;
      });
      for (final item in pool.take(needed)) {
        final priceJitter = 0.85 + rnd.nextDouble() * 0.3; // 0.85..1.15
        final price = (item.basePrice * priceJitter).round();
        rows.add({
          'restaurant_id': id,
          'category_id': categories[category],
          'name': item.name,
          'description': item.description,
          'price': price,
          'is_veg': item.isVeg,
          'is_available': true,
        });
      }
    }
  }

  print('→ Generated ${rows.length} menu_items rows '
      '(avg ${(rows.length / targets.length).toStringAsFixed(1)} per restaurant).');

  if (dryRun) {
    print(const JsonEncoder.withIndent('  ')
        .convert(rows.take(6).toList()));
    return;
  }

  // 4. Batch upload.
  const chunkSize = 300;
  final url = Uri.parse('$supabaseUrl/rest/v1/menu_items');
  for (var i = 0; i < rows.length; i += chunkSize) {
    final chunk = rows.sublist(i, min(i + chunkSize, rows.length));
    final res = await http.post(
      url,
      headers: {...hdrs, 'Prefer': 'return=minimal'},
      body: jsonEncode(chunk),
    );
    if (res.statusCode >= 400) {
      stderr.writeln('Chunk failed: HTTP ${res.statusCode} ${res.body}');
      exit(4);
    }
    print('  inserted ${chunk.length} (${i + chunk.length}/${rows.length})');
  }
  print('✓ Done.');
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (final a in args) {
    if (!a.startsWith('--')) continue;
    final eq = a.indexOf('=');
    if (eq == -1) {
      map[a.substring(2)] = 'true';
    } else {
      map[a.substring(2, eq)] = a.substring(eq + 1);
    }
  }
  return map;
}
