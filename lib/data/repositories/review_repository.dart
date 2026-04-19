import '../models/review.dart';

abstract interface class ReviewRepository {
  Future<List<Review>> fetchForRestaurant(String restaurantId, {int limit = 20});

  /// Review written by [userId] for [orderId]. Null when not yet rated.
  Future<Review?> fetchMyReviewForOrder({
    required String userId,
    required String orderId,
  });

  /// Upsert a review. When [id] is null a new row is inserted.
  Future<Review> submit({
    String? id,
    required String userId,
    required String restaurantId,
    String? orderId,
    required int rating,
    String? comment,
  });
}
