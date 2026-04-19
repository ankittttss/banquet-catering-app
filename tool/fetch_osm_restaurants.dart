// ============================================================================
// fetch_osm_restaurants.dart
//
// Pulls real restaurants across India from OpenStreetMap (via the free
// Overpass API) and upserts them into your Supabase `restaurants` table.
//
// Usage:
//   # Option A — env vars (recommended; matches upload_menu_images.mjs)
//   $env:SUPABASE_URL="https://<project>.supabase.co"
//   $env:SUPABASE_SERVICE_ROLE_KEY="<key>"
//   dart run tool/fetch_osm_restaurants.dart
//
//   # Option B — pass flags
//   dart run tool/fetch_osm_restaurants.dart \
//     --supabase-url=https://<project>.supabase.co \
//     --service-role=<SERVICE_ROLE_KEY>
//
// Optional flags:
//   [--per-city=80]       # max OSM rows per city (default 80)
//   [--radius-km=12]      # search radius around each city center
//   [--dry-run]           # print the upsert payload without writing
//
// The service_role key is available in Supabase → Project Settings → API.
// NEVER commit it or paste it into client apps — it bypasses RLS.
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

const _overpass = 'https://overpass-api.de/api/interpreter';

/// 34 major Indian cities with their approximate centers.
const _cities = <Map<String, Object>>[
  {'name': 'Mumbai',           'lat': 19.0760, 'lng': 72.8777},
  {'name': 'Delhi',            'lat': 28.6139, 'lng': 77.2090},
  {'name': 'Bengaluru',        'lat': 12.9716, 'lng': 77.5946},
  {'name': 'Hyderabad',        'lat': 17.3850, 'lng': 78.4867},
  {'name': 'Chennai',          'lat': 13.0827, 'lng': 80.2707},
  {'name': 'Kolkata',          'lat': 22.5726, 'lng': 88.3639},
  {'name': 'Ahmedabad',        'lat': 23.0225, 'lng': 72.5714},
  {'name': 'Pune',             'lat': 18.5204, 'lng': 73.8567},
  {'name': 'Jaipur',           'lat': 26.9124, 'lng': 75.7873},
  {'name': 'Lucknow',          'lat': 26.8467, 'lng': 80.9462},
  {'name': 'Surat',            'lat': 21.1702, 'lng': 72.8311},
  {'name': 'Kanpur',           'lat': 26.4499, 'lng': 80.3319},
  {'name': 'Nagpur',           'lat': 21.1458, 'lng': 79.0882},
  {'name': 'Indore',           'lat': 22.7196, 'lng': 75.8577},
  {'name': 'Bhopal',           'lat': 23.2599, 'lng': 77.4126},
  {'name': 'Visakhapatnam',    'lat': 17.6868, 'lng': 83.2185},
  {'name': 'Patna',            'lat': 25.5941, 'lng': 85.1376},
  {'name': 'Ludhiana',         'lat': 30.9010, 'lng': 75.8573},
  {'name': 'Agra',             'lat': 27.1767, 'lng': 78.0081},
  {'name': 'Nashik',           'lat': 19.9975, 'lng': 73.7898},
  {'name': 'Vadodara',         'lat': 22.3072, 'lng': 73.1812},
  {'name': 'Meerut',           'lat': 28.9845, 'lng': 77.7064},
  {'name': 'Rajkot',           'lat': 22.3039, 'lng': 70.8022},
  {'name': 'Varanasi',         'lat': 25.3176, 'lng': 82.9739},
  {'name': 'Amritsar',         'lat': 31.6340, 'lng': 74.8723},
  {'name': 'Allahabad',        'lat': 25.4358, 'lng': 81.8463},
  {'name': 'Ranchi',           'lat': 23.3441, 'lng': 85.3096},
  {'name': 'Coimbatore',       'lat': 11.0168, 'lng': 76.9558},
  {'name': 'Jodhpur',          'lat': 26.2389, 'lng': 73.0243},
  {'name': 'Chandigarh',       'lat': 30.7333, 'lng': 76.7794},
  {'name': 'Guwahati',         'lat': 26.1445, 'lng': 91.7362},
  {'name': 'Thiruvananthapuram','lat': 8.5241, 'lng': 76.9366},
  {'name': 'Mysuru',           'lat': 12.2958, 'lng': 76.6394},
  {'name': 'Goa',              'lat': 15.2993, 'lng': 74.1240},
];

// Cuisine emoji + display string for when OSM doesn't carry a cuisine tag.
const _defaultCuisines = [
  ('North Indian · Mughlai',     '🍛'),
  ('South Indian · Thali',       '🥘'),
  ('Biryani · Tandoor',          '🍗'),
  ('Multi-cuisine · Buffet',     '🍽️'),
  ('Chinese · Indo-Chinese',     '🥡'),
  ('Pure Veg · Sattvik',         '🪷'),
  ('Coastal · Seafood',          '🦐'),
  ('Street Food · Chaat',        '🌯'),
  ('Continental · Desserts',     '🍰'),
  ('Rajasthani · Thali',         '🪔'),
];

const _tags = [
  'Bestseller',
  'Event Special',
  'Wedding Pick',
  'Pure Veg',
  'Tandoor Special',
  'Trending',
  null, null, null, // empty more often
];

const _bgHexes = [
  '#FFF3E0', '#EDE7F6', '#E8F5E9', '#FFF8E1',
  '#FFEBEE', '#E3F2FD', '#FCE4EC', '#F1F8E9',
];

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

  if (supabaseUrl.isEmpty || serviceRole.isEmpty) {
    stderr.writeln(
      'Error: missing Supabase credentials.\n'
      'Provide them one of two ways:\n'
      '  1) Env vars:  SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY\n'
      '  2) Flags:     --supabase-url=... --service-role=...\n\n'
      'The service_role key is in Supabase → Project Settings → API.',
    );
    exit(1);
  }
  final perCity = int.tryParse('${opts['per-city'] ?? 80}') ?? 80;
  final radiusKm = double.tryParse('${opts['radius-km'] ?? 12}') ?? 12;
  final dryRun = opts.containsKey('dry-run');

  print(
    '→ Pulling up to $perCity restaurants per city (radius ${radiusKm.toStringAsFixed(0)} km) '
    'across ${_cities.length} cities.',
  );

  final all = <Map<String, dynamic>>[];
  final seen = <String>{}; // name|lat|lng dedupe

  for (var i = 0; i < _cities.length; i++) {
    final c = _cities[i];
    final cityName = c['name'] as String;
    final lat = c['lat'] as double;
    final lng = c['lng'] as double;
    stdout.write('[${i + 1}/${_cities.length}] $cityName … ');
    try {
      final rows = await _fetchCity(cityName, lat, lng, perCity, radiusKm);
      var kept = 0;
      for (final r in rows) {
        final key =
            '${r['name']?.toString().trim().toLowerCase()}|'
            '${(r['latitude'] as double).toStringAsFixed(4)}|'
            '${(r['longitude'] as double).toStringAsFixed(4)}';
        if (seen.add(key)) {
          all.add(r);
          kept++;
        }
      }
      print('kept $kept.');
    } catch (e) {
      print('skipped ($e).');
    }
    // Be polite to Overpass — the public server is aggressive about
    // throttling, so keep at least 1.5 s between requests.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
  }

  print('\n→ Total unique restaurants: ${all.length}');

  if (dryRun) {
    print('Dry run — first 3 rows:');
    for (final r in all.take(3)) {
      print(const JsonEncoder.withIndent('  ').convert(r));
    }
    return;
  }

  await _batchUpsert(supabaseUrl, serviceRole, all);
  print('✓ Upsert complete.');
}

/// Overpass's public server throttles bursty clients hard. Retry a few times
/// on 429 / 5xx with exponential backoff so transient errors don't kill the
/// whole run.
Future<http.Response> _postOverpassWithRetry(String query) async {
  const maxAttempts = 4;
  Object? lastErr;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final res = await http.post(
        Uri.parse(_overpass),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'dawat-catering-app/1.0 (osm-seeder)',
        },
        body: {'data': query},
      ).timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) return res;
      if (res.statusCode == 429 ||
          (res.statusCode >= 500 && res.statusCode < 600)) {
        lastErr = StateError('HTTP ${res.statusCode}');
      } else {
        return res; // other status — caller decides
      }
    } catch (e) {
      lastErr = e;
    }
    final delay = Duration(seconds: 2 * attempt);
    await Future<void>.delayed(delay);
  }
  throw lastErr ?? StateError('Overpass retry limit reached');
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

Future<List<Map<String, dynamic>>> _fetchCity(
  String cityName,
  double lat,
  double lng,
  int perCity,
  double radiusKm,
) async {
  // Nodes-only query — ways+relations make Overpass's public instance 504.
  final radiusMeters = (radiusKm * 1000).round();
  final query = '''
[out:json][timeout:25];
node["amenity"="restaurant"]["name"](around:$radiusMeters,$lat,$lng);
out body $perCity;
''';

  final res = await _postOverpassWithRetry(query);
  if (res.statusCode != 200) {
    throw StateError('HTTP ${res.statusCode}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final elements = (body['elements'] as List?) ?? const [];

  final out = <Map<String, dynamic>>[];
  for (final e in elements) {
    final tags = ((e as Map)['tags'] as Map?) ?? const {};
    final name = (tags['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;

    double? itemLat;
    double? itemLng;
    if (e['type'] == 'node') {
      itemLat = (e['lat'] as num?)?.toDouble();
      itemLng = (e['lon'] as num?)?.toDouble();
    } else {
      // ways — use `center` if Overpass returned it (it doesn't by default for
      // `out body`; if missing, fall back to the city center).
      final center = e['center'] as Map?;
      itemLat = (center?['lat'] as num?)?.toDouble() ?? lat;
      itemLng = (center?['lon'] as num?)?.toDouble() ?? lng;
    }
    if (itemLat == null || itemLng == null) continue;

    final cuisineTag = (tags['cuisine'] as String?)?.replaceAll('_', ' ');
    final vegTag = tags['diet:vegetarian'] as String?;
    final isPureVeg = vegTag == 'only' || vegTag == 'yes';
    final address = _addressFrom(tags, cityName);

    // Deterministic pseudo-random values so re-runs are stable per name+city.
    final seed = (name + cityName).hashCode;
    final rnd = Random(seed);
    final cuisinePair = _defaultCuisines[rnd.nextInt(_defaultCuisines.length)];
    final cuisinesDisplay = (cuisineTag != null && cuisineTag.isNotEmpty)
        ? _titleCase(cuisineTag)
        : cuisinePair.$1;

    out.add({
      'name': name,
      'logo_url': null,
      'delivery_charge': 800 + rnd.nextInt(8) * 100, // 800..1500
      'is_active': true,
      'price_per_plate': 180 + rnd.nextInt(11) * 20, // 180..380
      'min_guests': [5, 10, 15, 20, 25, 30][rnd.nextInt(6)],
      'delivery_min_minutes': 30 + rnd.nextInt(3) * 5, // 30..40
      'delivery_max_minutes': 45 + rnd.nextInt(4) * 5, // 45..60
      'rating': (38 + rnd.nextInt(13)) / 10.0, // 3.8..5.0
      'ratings_count': 200 + rnd.nextInt(9800), // 200..10000
      'cuisines_display': cuisinesDisplay,
      'hero_bg_hex': _bgHexes[rnd.nextInt(_bgHexes.length)],
      'hero_emoji': cuisinePair.$2,
      'tag': _tags[rnd.nextInt(_tags.length)],
      'is_pure_veg': isPureVeg,
      'popularity_score': rnd.nextInt(100),
      'latitude': itemLat,
      'longitude': itemLng,
      'address': address,
    });
  }
  return out;
}

String _addressFrom(Map<dynamic, dynamic> tags, String cityFallback) {
  final parts = <String>[
    (tags['addr:housenumber'] as String?) ?? '',
    (tags['addr:street'] as String?) ?? '',
    (tags['addr:suburb'] as String?) ?? '',
    (tags['addr:city'] as String?) ?? cityFallback,
    (tags['addr:state'] as String?) ?? '',
  ].where((s) => s.trim().isNotEmpty).toList();
  if (parts.isEmpty) return cityFallback;
  return parts.join(', ');
}

String _titleCase(String s) {
  return s
      .split(RegExp(r'[\s;,]+'))
      .where((p) => p.isNotEmpty)
      .take(3)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join(' · ');
}

Future<void> _batchUpsert(
  String supabaseUrl,
  String serviceRole,
  List<Map<String, dynamic>> rows,
) async {
  // Supabase/PostgREST handles batches of a few hundred comfortably; chunk to
  // stay well under body-size limits.
  const chunkSize = 200;
  final url = Uri.parse('$supabaseUrl/rest/v1/restaurants');

  for (var i = 0; i < rows.length; i += chunkSize) {
    final chunk = rows.sublist(i, min(i + chunkSize, rows.length));
    final res = await http.post(
      url,
      headers: {
        'apikey': serviceRole,
        'Authorization': 'Bearer $serviceRole',
        'Content-Type': 'application/json',
        // Merge duplicates by name + lat/lng if we ever add a unique index;
        // without one, this just does straight insert.
        'Prefer': 'return=minimal',
      },
      body: jsonEncode(chunk),
    );
    if (res.statusCode >= 400) {
      stderr.writeln(
          '✗ Chunk ${(i ~/ chunkSize) + 1} failed: HTTP ${res.statusCode}');
      stderr.writeln(res.body);
      exit(2);
    }
    stdout.writeln(
        '  inserted ${chunk.length} (${i + chunk.length}/${rows.length})');
  }
}
