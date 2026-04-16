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
final currentProfileProvider =
    FutureProvider<UserProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final repo = ref.read(profileRepositoryProvider);
  return repo.fetchById(userId);
});

/// Convenience — resolves role to user/admin (defaults to user).
final currentRoleProvider = Provider<UserRole>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.role ?? UserRole.user;
});
