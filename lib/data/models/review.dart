class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.rating,
    required this.createdAt,
    this.orderId,
    this.comment,
    this.userName,
  });

  final String id;
  final String userId;
  final String restaurantId;
  final String? orderId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  /// Display name, only populated when the review is joined with the
  /// author's profile (e.g. on the restaurant-detail reviews list).
  final String? userName;

  factory Review.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return Review(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      restaurantId: map['restaurant_id'] as String,
      orderId: map['order_id'] as String?,
      rating: (map['rating'] as num).toInt(),
      comment: map['comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      userName: profile?['name'] as String?,
    );
  }
}
