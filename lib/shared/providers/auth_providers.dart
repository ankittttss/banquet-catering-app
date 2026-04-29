import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_client.dart' as sb;
import '../../data/models/user_profile.dart';
import '../../data/models/user_role.dart';
import 'repositories_providers.dart';

/// Stream of Supabase auth state changes (sign in / sign out / refresh).
final authStateChangesProvider = StreamProvider<AuthState?>((ref) {
  if (!AppConfig.hasSupabase) return const Stream.empty();
  return sb.auth.onAuthStateChange;
});

/// Current user id (from the Supabase session), null if signed out.
final currentUserIdProvider = Provider<String?>((ref) {
  if (!AppConfig.hasSupabase) return null;
  // Re-evaluate when auth state changes.
  ref.watch(authStateChangesProvider);
  return sb.auth.currentUser?.id;
});

/// Loads the profile row for the current user. null when signed out.
/// When the row is missing we INSERT a bare row (role defaults to 'user' in
/// the DB) — never upsert, because an upsert here can silently overwrite an
/// admin/delivery role if RLS briefly hid the existing row.
final currentProfileProvider =
    FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final repo = ref.read(profileRepositoryProvider);
  final existing = await repo.fetchById(userId);
  if (existing != null) return existing;

  if (!AppConfig.hasSupabase) return null;
  final user = sb.auth.currentUser;
  if (user == null) return null;

  try {
    await sb.supabase.from('profiles').insert({
      'id': userId,
      if (user.email != null) 'email': user.email,
      if (user.phone != null) 'phone': user.phone,
    });
  } on PostgrestException {
    // Row already exists (race with handle_new_user trigger). Fine — we
    // fall through and re-fetch so we respect whatever role the DB has.
  }
  return repo.fetchById(userId);
});

/// Convenience — resolves role from the current profile, defaulting to
/// customer when the profile isn't loaded yet.
final currentRoleProvider = Provider<UserRole>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.role ?? UserRole.customer;
});
