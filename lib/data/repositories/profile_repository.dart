import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> fetchById(String userId);
  Future<UserProfile> upsert(UserProfile profile);
}
