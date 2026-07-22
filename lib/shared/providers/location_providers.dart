import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/location_service.dart';

/// Resolves the device's current location as a reverse-geocoded address.
/// Throws [LocationException] when location is off, permission is denied, or the
/// lookup fails.
typedef CurrentLocationResolver = Future<ResolvedAddress> Function();

/// The device-GPS seam. The app never touches GPS until the customer explicitly
/// taps "Use my current location" while planning; wrapping it in a provider
/// keeps that single call site overridable in tests (the concrete
/// [LocationService] hits static geolocator APIs that can't be faked directly).
final currentLocationProvider = Provider<CurrentLocationResolver>(
  (ref) => LocationService.instance.currentAddress,
);
