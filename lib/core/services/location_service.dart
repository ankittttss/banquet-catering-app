import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ResolvedAddress {
  ResolvedAddress({
    required this.lat,
    required this.lng,
    this.line1,
    this.line2,
    this.city,
  });

  final double lat;
  final double lng;
  final String? line1;
  final String? line2;
  final String? city;
}

/// Lightweight autocomplete result from Nominatim. Display name is the
/// pre-formatted user-facing label; the structured fields are useful for
/// pre-filling individual form inputs.
class AddressSuggestion {
  const AddressSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
    this.line1,
    this.landmark,
    this.cityPincode,
  });

  final String displayName;
  final double lat;
  final double lng;
  final String? line1;
  final String? landmark;
  final String? cityPincode;
}

/// Reasons location lookup can fail in a way the UI should react to.
enum LocationError {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unknown,
}

class LocationException implements Exception {
  LocationException(this.kind, [this.cause]);
  final LocationError kind;
  final Object? cause;
  @override
  String toString() => 'LocationException($kind${cause == null ? '' : ': $cause'})';
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<ResolvedAddress> currentAddress() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw LocationException(LocationError.serviceDisabled);
    }
    final permission = await _ensurePermission();
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(LocationError.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw LocationException(LocationError.permissionDenied);
    }
    final pos = await Geolocator.getCurrentPosition();
    return _reverse(pos.latitude, pos.longitude);
  }

  /// Nominatim forward-geocode for address autocomplete. Free, no key,
  /// but rate-limited — only call after the user pauses typing (debounce
  /// at the call site, ~300 ms).
  Future<List<AddressSuggestion>> searchSuggestions(
    String query, {
    String? countryCode = 'in',
    int limit = 6,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': q,
          'format': 'json',
          'addressdetails': '1',
          'limit': '$limit',
          if (countryCode != null) 'countrycodes': countryCode,
        },
      );
      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'Dawat/1.0 (dawat-app)',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode != 200) return const [];
      final raw = jsonDecode(res.body) as List<dynamic>;
      return raw.map<AddressSuggestion>((e) {
        final m = e as Map<String, dynamic>;
        final addr =
            (m['address'] as Map<String, dynamic>?) ?? const {};
        final line1 = _firstNonEmpty([
          addr['amenity'] as String?,
          addr['road'] as String?,
          addr['neighbourhood'] as String?,
          addr['hamlet'] as String?,
        ]);
        final landmark = _firstNonEmpty([
          addr['suburb'] as String?,
          addr['locality'] as String?,
          addr['quarter'] as String?,
        ]);
        final city = _firstNonEmpty([
          addr['city'] as String?,
          addr['town'] as String?,
          addr['village'] as String?,
        ]);
        final postcode = addr['postcode'] as String?;
        final cityLine = [city, postcode]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');
        return AddressSuggestion(
          displayName: (m['display_name'] as String?) ?? q,
          lat: double.tryParse('${m['lat']}') ?? 0,
          lng: double.tryParse('${m['lon']}') ?? 0,
          line1: line1,
          landmark: landmark,
          cityPincode: cityLine.isEmpty ? null : cityLine,
        );
      }).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<LocationPermission> _ensurePermission() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p;
  }

  Future<ResolvedAddress> _reverse(double lat, double lng) async {
    if (kIsWeb) return _reverseViaNominatim(lat, lng);
    return _reverseViaPlatform(lat, lng);
  }

  Future<ResolvedAddress> _reverseViaPlatform(
      double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        return ResolvedAddress(lat: lat, lng: lng);
      }
      final p = placemarks.first;
      final line1 = _join([p.name, p.street]);
      final line2 = _join([p.subLocality, p.locality]);
      return ResolvedAddress(
        lat: lat,
        lng: lng,
        line1: line1.isEmpty ? null : line1,
        line2: line2.isEmpty ? null : line2,
        city: (p.locality?.isNotEmpty ?? false)
            ? p.locality
            : p.administrativeArea,
      );
    } catch (_) {
      return ResolvedAddress(lat: lat, lng: lng);
    }
  }

  Future<ResolvedAddress> _reverseViaNominatim(
      double lat, double lng) async {
    try {
      final res = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?lat=$lat&lon=$lng&format=json&addressdetails=1',
        ),
        headers: const {
          'User-Agent': 'Foodly/1.0 (foodly-app)',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode != 200) {
        return ResolvedAddress(lat: lat, lng: lng);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr =
          (data['address'] as Map<String, dynamic>?) ?? const {};
      final line1 = _firstNonEmpty([
        addr['road'] as String?,
        addr['neighbourhood'] as String?,
        addr['hamlet'] as String?,
        addr['amenity'] as String?,
      ]);
      final line2 = _firstNonEmpty([
        addr['suburb'] as String?,
        addr['locality'] as String?,
        addr['quarter'] as String?,
      ]);
      final city = _firstNonEmpty([
        addr['city'] as String?,
        addr['town'] as String?,
        addr['village'] as String?,
        addr['state_district'] as String?,
        addr['state'] as String?,
      ]);
      return ResolvedAddress(
        lat: lat,
        lng: lng,
        line1: line1,
        line2: line2,
        city: city,
      );
    } catch (_) {
      return ResolvedAddress(lat: lat, lng: lng);
    }
  }

  String _join(Iterable<String?> parts) {
    return parts
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .join(', ');
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }
}
