import '../models/delivery_assignment.dart';
import '../models/driver_profile.dart';

abstract interface class DeliveryRepository {
  /// Currently signed-in driver's profile.
  Future<DriverProfile?> fetchDriver(String driverId);

  Stream<DriverProfile> streamDriver(String driverId);

  Future<void> setOnline(String driverId, bool online);

  /// Stream of offered-but-unclaimed assignments (broadcast dispatch).
  /// Drivers see this while online.
  Stream<List<DeliveryAssignment>> streamOffers();

  /// The active assignment for this driver (accepted or picked_up).
  Stream<DeliveryAssignment?> streamActive(String driverId);

  /// Past deliveries for this driver, most recent first.
  Future<List<DeliveryAssignment>> fetchHistory(String driverId);

  Future<void> acceptOffer(String assignmentId, String driverId);
  Future<void> declineOffer(String assignmentId, String driverId);
  Future<void> markPickedUp(String assignmentId);
  Future<void> markDelivered(String assignmentId, {required String otp});

  /// Admin-side: list drivers for manual assignment.
  Future<List<DriverProfile>> fetchAvailableDrivers();

  /// Admin-side: broadcast a new delivery offer for a placed order.
  Future<String> broadcastOffer(DeliveryAssignment draft);

  /// Admin override: find the existing `offered` delivery row for this order
  /// (created by the auto-dispatch trigger) and assign it to [driverId]. If
  /// no offer exists yet, broadcasts a fresh one using [draft] and assigns it.
  Future<void> assignDriverToOrder({
    required String orderId,
    required String driverId,
    required DeliveryAssignment draft,
  });
}
