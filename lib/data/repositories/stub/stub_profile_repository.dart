import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../profile_repository.dart';

class StubProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  @override
  Future<UserProfile?> fetchById(String userId) async {
    return _profile ?? UserProfile(id: userId, role: UserRole.user);
  }

  @override
  Future<UserProfile> upsert(UserProfile profile) async {
    _profile = profile;
    return profile;
  }
}
