import '../../models/review.dart';
import '../review_repository.dart';

class StubReviewRepository implements ReviewRepository {
  final _rows = <Review>[];

  @override
  Future<List<Review>> fetchForRestaurant(String restaurantId,
      {int limit = 20}) async {
    final filtered = _rows
        .where((r) => r.restaurantId == restaurantId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<Review?> fetchMyReviewForOrder({
    required String userId,
    required String orderId,
  }) async {
    for (final r in _rows) {
      if (r.userId == userId && r.orderId == orderId) return r;
    }
    return null;
  }

  @override
  Future<Review> submit({
    String? id,
    required String userId,
    required String restaurantId,
    String? orderId,
    required int rating,
    String? comment,
  }) async {
    final existingIdx = orderId == null
        ? -1
        : _rows.indexWhere(
            (r) => r.userId == userId && r.orderId == orderId);
    final review = Review(
      id: id ??
          (existingIdx >= 0
              ? _rows[existingIdx].id
              : 'stub-${_rows.length + 1}'),
      userId: userId,
      restaurantId: restaurantId,
      orderId: orderId,
      rating: rating,
      comment: comment,
      createdAt: existingIdx >= 0
          ? _rows[existingIdx].createdAt
          : DateTime.now(),
      userName: 'You',
    );
    if (existingIdx >= 0) {
      _rows[existingIdx] = review;
    } else {
      _rows.add(review);
    }
    return review;
  }
}
