import 'dart:typed_data';

import '../models/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> fetchById(String userId);
  Future<UserProfile> upsert(UserProfile profile);

  /// Uploads [bytes] (a JPEG re-encoded by the client) to the avatars
  /// bucket at `avatars/{userId}.jpg`, updates `profiles.avatar_url` with
  /// the public URL + a cache-busting `?v=` query param, and returns the
  /// new URL.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  });

  /// Removes the user's avatar — clears the file in storage and nulls
  /// `profiles.avatar_url`. Safe to call when no avatar exists.
  Future<void> clearAvatar(String userId);
}
