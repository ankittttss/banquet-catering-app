import '../../../core/supabase/supabase_client.dart';
import '../../models/user_address.dart';
import '../address_repository.dart';

class SupabaseAddressRepository implements AddressRepository {
  @override
  Future<List<UserAddress>> fetchForUser(String userId) async {
    final rows = await supabase
        .from('user_addresses')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at');
    return rows
        .map<UserAddress>((r) => UserAddress.fromMap(r))
        .toList(growable: false);
  }

  @override
  Future<UserAddress> save(UserAddressInput input) async {
    final raw = await supabase.rpc('upsert_address', params: {
      'p_id': input.id,
      'p_label': input.label.label,
      'p_address': input.fullAddress,
      'p_is_default': input.isDefault,
    });
    final map = raw is Map<String, dynamic>
        ? raw
        : (raw as List).first as Map<String, dynamic>;
    return UserAddress.fromMap(map);
  }

  @override
  Future<void> delete(String id) async {
    await supabase.from('user_addresses').delete().eq('id', id);
  }

  /// Atomic default toggle via [set_default_address] RPC — no race with the
  /// partial unique index.
  @override
  Future<void> setDefault(String userId, String id) async {
    await supabase.rpc('set_default_address', params: {'p_id': id});
  }
}
