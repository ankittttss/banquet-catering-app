import '../../../core/supabase/supabase_client.dart';
import '../../models/review.dart';
import '../review_repository.dart';

class SupabaseReviewRepository implements ReviewRepository {
  @override
  Future<List<Review>> fetchForRestaurant(String restaurantId,
      {int limit = 20}) async {
    final rows = await supabase
        .from('reviews')
        .select('*, profiles!reviews_user_profile_fkey(name)')
        .eq('restaurant_id', restaurantId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map<Review>(Review.fromMap).toList(growable: false);
  }

  @override
  Future<Review?> fetchMyReviewForOrder({
    required String userId,
    required String orderId,
  }) async {
    final row = await supabase
        .from('reviews')
        .select()
        .eq('user_id', userId)
        .eq('order_id', orderId)
        .maybeSingle();
    if (row == null) return null;
    return Review.fromMap(row);
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
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'user_id': userId,
      'restaurant_id': restaurantId,
      if (orderId != null) 'order_id': orderId,
      'rating': rating,
      'comment': comment,
    };
    final row = await supabase
        .from('reviews')
        .upsert(payload, onConflict: 'user_id,order_id')
        .select()
        .single();
    return Review.fromMap(row);
  }
}
