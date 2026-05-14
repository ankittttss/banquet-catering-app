import 'dart:convert';

import 'package:flutter/foundation.dart';
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
/// On Android we also fall back to Nominatim if Photon ever returns an
/// empty list — some free CDN edges are flaky from Indian carriers and
/// having a second source gets the user moving.
class PhotonGeocoder {
  PhotonGeocoder({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://photon.komoot.io';

  // Free OSM services frown on missing UAs and some carriers' edges
  // mis-route requests with the default Dart/x.y.z agent. A descriptive
  // header keeps the requests well-behaved.
  static const Map<String, String> _headers = {
    'User-Agent': 'Dawat/1.0 (dawat-app; contact: support@dawat.app)',
    'Accept': 'application/json',
  };

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
    try {
      final photon = await _searchPhoton(q, lat, lng, limit, lang);
      if (photon.isNotEmpty) return photon;
    } catch (e, st) {
      debugPrint('Photon search failed: $e\n$st');
    }
    try {
      return await _searchNominatim(q, limit);
    } catch (e, st) {
      debugPrint('Nominatim search failed: $e\n$st');
      return const [];
    }
  }

  Future<List<GeocodeResult>> _searchPhoton(
    String q,
    double? lat,
    double? lng,
    int limit,
    String lang,
  ) async {
    final params = <String, String>{
      'q': q,
      'limit': '$limit',
      'lang': lang,
    };
    if (lat != null && lng != null) {
      params['lat'] = '$lat';
      params['lon'] = '$lng';
    }
    final uri =
        Uri.parse('$_base/api/').replace(queryParameters: params);
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? const [];
    return features
        .whereType<Map<String, dynamic>>()
        .map(_parseFeature)
        .toList(growable: false);
  }

  Future<List<GeocodeResult>> _searchNominatim(
    String q,
    int limit,
  ) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': q,
        'format': 'json',
        'addressdetails': '1',
        'limit': '$limit',
        'countrycodes': 'in',
      },
    );
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return const [];
    final raw = jsonDecode(res.body) as List<dynamic>;
    return raw.whereType<Map<String, dynamic>>().map((m) {
      final addr =
          (m['address'] as Map?)?.cast<String, dynamic>() ?? const {};
      final lat = double.tryParse('${m['lat']}') ?? 0;
      final lon = double.tryParse('${m['lon']}') ?? 0;
      final name = _firstNonEmpty([
        addr['amenity'] as String?,
        addr['road'] as String?,
        addr['neighbourhood'] as String?,
        addr['suburb'] as String?,
      ]) ?? (m['display_name'] as String? ?? '').split(',').first.trim();
      final city = _firstNonEmpty([
        addr['city'] as String?,
        addr['town'] as String?,
        addr['village'] as String?,
        addr['county'] as String?,
      ]) ?? '';
      final state = addr['state'] as String? ?? '';
      final country = addr['country'] as String? ?? '';
      final full = [name, city, state, country]
          .where((s) => s.isNotEmpty)
          .toSet()
          .join(', ');
      final short = [name, city]
          .where((s) => s.isNotEmpty)
          .toSet()
          .join(', ');
      return GeocodeResult(
        name: name,
        displayAddress: full.isEmpty
            ? (m['display_name'] as String? ?? '')
            : full,
        latitude: lat,
        longitude: lon,
        shortLabel: short.isEmpty ? name : short,
      );
    }).toList(growable: false);
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
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
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 6));
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
