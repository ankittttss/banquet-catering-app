import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    final path = '$userId.jpg';
    await supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
            cacheControl: '3600',
          ),
        );
    final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);
    // Bust the CDN cache so a re-upload appears immediately. The previous
    // file is overwritten in place, so without ?v= clients would keep
    // showing the cached old image.
    final busted =
        '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    await supabase
        .from('profiles')
        .update({'avatar_url': busted}).eq('id', userId);
    return busted;
  }

  @override
  Future<void> clearAvatar(String userId) async {
    final path = '$userId.jpg';
    try {
      await supabase.storage.from('avatars').remove([path]);
    } on StorageException {
      // Object might not exist — fine, we still want the column nulled.
    }
    await supabase
        .from('profiles')
        .update({'avatar_url': null}).eq('id', userId);
  }
}
