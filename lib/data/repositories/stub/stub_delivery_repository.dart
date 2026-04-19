import 'dart:async';

import '../../models/delivery_assignment.dart';
import '../../models/driver_profile.dart';
import '../delivery_repository.dart';

/// In-memory stub — no backend. Seeds a few fake drivers + a rotating
/// stream of "offered" assignments so the UI stays lively during dev.
class StubDeliveryRepository implements DeliveryRepository {
  StubDeliveryRepository() {
    _seed();
  }

  final Map<String, DriverProfile> _drivers = {};
  final Map<String, DeliveryAssignment> _assignments = {};
  final _offersCtl =
      StreamController<List<DeliveryAssignment>>.broadcast();
  final Map<String, StreamController<DriverProfile>> _driverCtls = {};
  final Map<String, StreamController<DeliveryAssignment?>> _activeCtls = {};

  void _seed() {
    _drivers['me'] = const DriverProfile(
      id: 'me',
      name: 'Ravi Kumar',
      phone: '+91 98765 43210',
      vehicle: 'Honda Activa',
      vehicleNumber: 'TS 09 AB 1234',
      rating: 4.9,
      totalDeliveries: 1842,
      isOnline: true,
    );
    _drivers['d2'] = const DriverProfile(
      id: 'd2',
      name: 'Suresh Naidu',
      phone: '+91 99876 54321',
      vehicle: 'Bajaj Pulsar',
      vehicleNumber: 'TS 08 CD 5678',
      rating: 4.7,
      totalDeliveries: 920,
      isOnline: true,
    );
    _drivers['d3'] = const DriverProfile(
      id: 'd3',
      name: 'Karthik M',
      phone: '+91 90000 11111',
      vehicle: 'TVS Jupiter',
      vehicleNumber: 'TS 10 EF 3344',
      rating: 4.8,
      totalDeliveries: 460,
      isOnline: false,
    );

    // One seeded offer so the popup + dashboard show something.
    final offer = DeliveryAssignment(
      id: 'offer-1',
      orderId: 'DWT-4829',
      status: DeliveryStatus.offered,
      offeredAt: DateTime.now(),
      pickupAddress: 'Paradise Biryani, Banjara Hills',
      dropAddress: 'Plot 42, Road No. 12, Banjara Hills',
      distanceKm: 4.2,
      earningAmount: 85,
      itemCount: 3,
      restaurantName: 'Paradise Biryani',
      customerName: 'Arjun Reddy',
      customerPhone: '+91 98500 12345',
      eventLabel: 'Birthday Party',
      guestCount: 25,
      deliveryOtp: '4829',
      etaMinutes: 18,
    );
    _assignments[offer.id] = offer;
  }

  void _pushOffers() {
    final list = _assignments.values
        .where((a) => a.status == DeliveryStatus.offered)
        .toList();
    _offersCtl.add(list);
  }

  void _pushDriver(String id) {
    final p = _drivers[id];
    if (p == null) return;
    _driverCtls[id]?.add(p);
  }

  void _pushActive(String driverId) {
    final ctl = _activeCtls[driverId];
    if (ctl == null) return;
    final a = _assignments.values
        .where((a) =>
            a.driverId == driverId &&
            (a.status == DeliveryStatus.accepted ||
                a.status == DeliveryStatus.pickedUp))
        .toList();
    ctl.add(a.isEmpty ? null : a.first);
  }

  @override
  Future<DriverProfile?> fetchDriver(String driverId) async =>
      _drivers[driverId];

  @override
  Stream<DriverProfile> streamDriver(String driverId) {
    final ctl = _driverCtls.putIfAbsent(
      driverId,
      () => StreamController<DriverProfile>.broadcast(),
    );
    // Emit current snapshot on next tick.
    Future<void>.microtask(() => _pushDriver(driverId));
    return ctl.stream;
  }

  @override
  Future<void> setOnline(String driverId, bool online) async {
    final p = _drivers[driverId];
    if (p == null) return;
    _drivers[driverId] = p.copyWith(isOnline: online);
    _pushDriver(driverId);
  }

  @override
  Stream<List<DeliveryAssignment>> streamOffers() {
    // Emit current snapshot on next tick.
    Future<void>.microtask(_pushOffers);
    return _offersCtl.stream;
  }

  @override
  Stream<DeliveryAssignment?> streamActive(String driverId) {
    final ctl = _activeCtls.putIfAbsent(
      driverId,
      () => StreamController<DeliveryAssignment?>.broadcast(),
    );
    Future<void>.microtask(() => _pushActive(driverId));
    return ctl.stream;
  }

  @override
  Future<List<DeliveryAssignment>> fetchHistory(String driverId) async {
    return _assignments.values
        .where((a) =>
            a.driverId == driverId &&
            (a.status == DeliveryStatus.delivered ||
                a.status == DeliveryStatus.cancelled))
        .toList()
      ..sort((a, b) =>
          (b.deliveredAt ?? b.offeredAt).compareTo(a.deliveredAt ?? a.offeredAt));
  }

  @override
  Future<void> acceptOffer(String assignmentId, String driverId) async {
    final a = _assignments[assignmentId];
    if (a == null) return;
    _assignments[assignmentId] = a.copyWith(
      status: DeliveryStatus.accepted,
      driverId: driverId,
      acceptedAt: DateTime.now(),
    );
    final d = _drivers[driverId];
    if (d != null) {
      _drivers[driverId] =
          d.copyWith(activeAssignmentId: assignmentId);
      _pushDriver(driverId);
    }
    _pushOffers();
    _pushActive(driverId);
  }

  @override
  Future<void> declineOffer(String assignmentId, String driverId) async {
    // Stub treats decline as "skip for me" — offer stays available so
    // local dev can try again. Real impl would record per-driver decline.
    _pushOffers();
  }

  @override
  Future<void> markPickedUp(String assignmentId) async {
    final a = _assignments[assignmentId];
    if (a == null) return;
    _assignments[assignmentId] = a.copyWith(
      status: DeliveryStatus.pickedUp,
      pickedUpAt: DateTime.now(),
    );
    if (a.driverId != null) _pushActive(a.driverId!);
  }

  @override
  Future<void> markDelivered(String assignmentId,
      {required String otp}) async {
    final a = _assignments[assignmentId];
    if (a == null) return;
    if (otp != a.deliveryOtp) {
      throw StateError('Invalid OTP');
    }
    _assignments[assignmentId] = a.copyWith(
      status: DeliveryStatus.delivered,
      deliveredAt: DateTime.now(),
    );
    if (a.driverId != null) {
      final d = _drivers[a.driverId!];
      if (d != null) {
        _drivers[a.driverId!] = d.copyWith(activeAssignmentId: null);
        _pushDriver(a.driverId!);
      }
      _pushActive(a.driverId!);
    }
  }

  @override
  Future<List<DriverProfile>> fetchAvailableDrivers() async {
    return _drivers.values
        .where((d) => d.isOnline && d.activeAssignmentId == null)
        .toList();
  }

  @override
  Future<String> broadcastOffer(DeliveryAssignment draft) async {
    _assignments[draft.id] = draft;
    _pushOffers();
    return draft.id;
  }
}
