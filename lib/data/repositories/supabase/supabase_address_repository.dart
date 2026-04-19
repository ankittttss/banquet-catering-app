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
    // Build params conditionally so we stay compatible with the older
    // 4-parameter signature of `upsert_address` for environments where
    // phase6_geolocation.sql hasn't been run yet.
    final params = <String, dynamic>{
      'p_id': input.id,
      'p_label': input.label.label,
      'p_address': input.fullAddress,
      'p_is_default': input.isDefault,
    };
    if (input.latitude != null) params['p_latitude'] = input.latitude;
    if (input.longitude != null) params['p_longitude'] = input.longitude;
    if (input.shortLabel != null) params['p_short_label'] = input.shortLabel;

    final raw = await supabase.rpc('upsert_address', params: params);
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
