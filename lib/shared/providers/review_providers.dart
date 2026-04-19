import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/review.dart';
import 'auth_providers.dart';
import 'repositories_providers.dart';

/// Recent reviews for a restaurant (newest first). Family key = restaurantId.
final restaurantReviewsProvider =
    FutureProvider.family<List<Review>, String>((ref, restaurantId) {
  return ref
      .read(reviewRepositoryProvider)
      .fetchForRestaurant(restaurantId);
});

/// The current user's review for a specific order, if any. Family key = orderId.
/// Returns null when signed out or the order hasn't been rated yet.
final myReviewForOrderProvider =
    FutureProvider.family<Review?, String>((ref, orderId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref
      .read(reviewRepositoryProvider)
      .fetchMyReviewForOrder(userId: userId, orderId: orderId);
});
