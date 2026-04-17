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

  /// Sets a single address as default by:
  ///   1. Clearing all current defaults for the user.
  ///   2. Setting is_default=true on the target.
  /// Both in one round-trip where possible; partial unique index enforces safety.
  @override
  Future<void> setDefault(String userId, String id) async {
    await supabase
        .from('user_addresses')
        .update({'is_default': false})
        .eq('user_id', userId)
        .neq('id', id);
    await supabase
        .from('user_addresses')
        .update({'is_default': true}).eq('id', id);
  }
}
