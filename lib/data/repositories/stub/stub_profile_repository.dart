import 'dart:typed_data';

import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../profile_repository.dart';

class StubProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  @override
  Future<UserProfile?> fetchById(String userId) async {
    return _profile ?? UserProfile(id: userId, role: UserRole.customer);
  }

  @override
  Future<UserProfile> upsert(UserProfile profile) async {
    _profile = profile;
    return profile;
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    // Offline / UI-only mode: pretend the upload succeeded so the rest of
    // the flow can be exercised without Supabase. Returns a placeholder
    // data URL the UI will happily render.
    const url = 'about:blank';
    _profile = (_profile ?? UserProfile(id: userId, role: UserRole.customer))
        .copyWith(avatarUrl: url);
    return url;
  }

  @override
  Future<void> clearAvatar(String userId) async {
    if (_profile != null) {
      _profile = _profile!.copyWith(avatarUrl: null);
    }
  }
}
