import '../models/user_address.dart';

/// Contract for reading/writing user addresses.
/// Implementations: [SupabaseAddressRepository] (real) and
/// [StubAddressRepository] (in-memory, for dev without Supabase).
abstract interface class AddressRepository {
  Future<List<UserAddress>> fetchForUser(String userId);
  Future<UserAddress> save(UserAddressInput input);
  Future<void> delete(String id);
  Future<void> setDefault(String userId, String id);
}
