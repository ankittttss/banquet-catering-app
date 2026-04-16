import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/user_profile.dart';
import '../models/user_role.dart';

class ProfileRepository {
  ProfileRepository();

  Future<UserProfile?> fetchById(String userId) async {
    if (!AppConfig.hasSupabase) {
      return UserProfile(id: userId, role: UserRole.user);
    }
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromMap(row);
  }

  Future<UserProfile> upsert(UserProfile profile) async {
    if (!AppConfig.hasSupabase) return profile;
    final row = await supabase
        .from('profiles')
        .upsert(profile.toMap())
        .select()
        .single();
    return UserProfile.fromMap(row);
  }
}
