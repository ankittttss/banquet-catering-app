import 'dart:math' as math;

import '../../data/models/restaurant.dart';

/// How far a kitchen can serve, in km. Mirrors the `restaurants_near` RPC
/// radius that scopes the customer home feed — used ONLY to label results
/// and block ordering, never to hide a restaurant from search.
const double kServiceRadiusKm = 10;

/// Great-circle distance in km, or null when either point is incomplete.
double? haversineKm({
  required double? lat1,
  required double? lng1,
  required double? lat2,
  required double? lng2,
}) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
    return null;
  }
  const earthRadiusKm = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(a));
}

double _rad(double deg) => deg * math.pi / 180.0;

/// Whether a restaurant can serve the customer's chosen point.
enum Serviceability {
  inRange,
  outOfRange,

  /// Either side lacks coordinates — never block on unknown.
  unknown,
}

/// Distance from the customer to [r] in km: prefers the server-computed
/// [Restaurant.distanceKm] (RPC results), falls back to haversine over raw
/// coordinates. Null when not computable.
double? distanceToRestaurantKm(
  Restaurant r, {
  double? customerLat,
  double? customerLng,
}) =>
    r.distanceKm ??
    haversineKm(
      lat1: customerLat,
      lng1: customerLng,
      lat2: r.latitude,
      lng2: r.longitude,
    );

Serviceability serviceabilityOf(
  Restaurant r, {
  double? customerLat,
  double? customerLng,
}) {
  final d = distanceToRestaurantKm(
    r,
    customerLat: customerLat,
    customerLng: customerLng,
  );
  if (d == null) return Serviceability.unknown;
  return d <= kServiceRadiusKm
      ? Serviceability.inRange
      : Serviceability.outOfRange;
}
