import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single place result from Photon geocoding.
class GeocodeResult {
  const GeocodeResult({
    required this.name,
    required this.displayAddress,
    required this.latitude,
    required this.longitude,
    required this.shortLabel,
  });

  final String name;
  final String displayAddress;
  final double latitude;
  final double longitude;
  /// e.g. "Banjara Hills, Hyderabad" — useful for compact header chips.
  final String shortLabel;
}

/// Free OSM-based geocoder (https://photon.komoot.io).
///
/// Photon has no API key and no hard rate limit for reasonable use, but we
/// still bias results toward India and debounce queries at the call site.
class PhotonGeocoder {
  PhotonGeocoder({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://photon.komoot.io';

  /// Autocomplete-style forward search. [lat]/[lng] bias results near a point.
  Future<List<GeocodeResult>> search(
    String query, {
    double? lat,
    double? lng,
    int limit = 8,
    String lang = 'en',
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final params = <String, String>{
      'q': q,
      'limit': '$limit',
      'lang': lang,
    };
    if (lat != null && lng != null) {
      params['lat'] = '$lat';
      params['lon'] = '$lng';
    }

    final uri = Uri.parse('$_base/api/').replace(queryParameters: params);
    final res = await _client.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? const [];
    return features
        .whereType<Map<String, dynamic>>()
        .map(_parseFeature)
        .toList(growable: false);
  }

  /// Reverse geocode: turn coordinates into a best-guess place name.
  Future<GeocodeResult?> reverse({
    required double latitude,
    required double longitude,
    String lang = 'en',
  }) async {
    final uri = Uri.parse('$_base/reverse').replace(queryParameters: {
      'lat': '$latitude',
      'lon': '$longitude',
      'lang': lang,
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? const [];
    if (features.isEmpty) return null;
    return _parseFeature(features.first as Map<String, dynamic>);
  }

  GeocodeResult _parseFeature(Map<String, dynamic> feature) {
    final props = (feature['properties'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final geom = (feature['geometry'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final coords = (geom['coordinates'] as List?) ?? const [];
    final lng = coords.isNotEmpty ? (coords[0] as num).toDouble() : 0.0;
    final lat = coords.length > 1 ? (coords[1] as num).toDouble() : 0.0;

    final name = (props['name'] as String?) ?? '';
    final city = (props['city'] as String?) ??
        (props['town'] as String?) ??
        (props['village'] as String?) ??
        (props['county'] as String?) ??
        '';
    final state = (props['state'] as String?) ?? '';
    final country = (props['country'] as String?) ?? '';
    final street = (props['street'] as String?) ?? '';
    final district =
        (props['district'] as String?) ?? (props['suburb'] as String?) ?? '';

    final full = [
      if (name.isNotEmpty) name,
      if (street.isNotEmpty && street != name) street,
      if (district.isNotEmpty) district,
      if (city.isNotEmpty && city != district) city,
      if (state.isNotEmpty) state,
      if (country.isNotEmpty) country,
    ].join(', ');

    final short = [
      if (district.isNotEmpty) district else if (name.isNotEmpty) name,
      if (city.isNotEmpty) city,
    ].where((e) => e.isNotEmpty).join(', ');

    return GeocodeResult(
      name: name.isNotEmpty ? name : (district.isNotEmpty ? district : city),
      displayAddress: full.isEmpty ? (name.isEmpty ? city : name) : full,
      latitude: lat,
      longitude: lng,
      shortLabel: short.isEmpty ? (full.isEmpty ? name : full) : short,
    );
  }

  void dispose() => _client.close();
}
