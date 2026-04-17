import '../../../core/supabase/supabase_client.dart';
import '../../models/user_profile.dart';
import '../profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile?> fetchById(String userId) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromMap(row);
  }

  @override
  Future<UserProfile> upsert(UserProfile profile) async {
    final row = await supabase
        .from('profiles')
        .upsert(profile.toMap())
        .select()
        .single();
    return UserProfile.fromMap(row);
  }
}
