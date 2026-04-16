import '../../core/config/app_config.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/user_address.dart';

class AddressRepository {
  AddressRepository();

  Future<List<UserAddress>> fetchForUser(String userId) async {
    if (!AppConfig.hasSupabase) return const [];
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

  Future<UserAddress> create(UserAddress address) async {
    if (!AppConfig.hasSupabase) return address;
    if (address.isDefault) {
      // Clear any existing default first to honor the unique partial index.
      await supabase
          .from('user_addresses')
          .update({'is_default': false}).eq('user_id', address.userId);
    }
    final row = await supabase
        .from('user_addresses')
        .insert(address.toInsertMap())
        .select()
        .single();
    return UserAddress.fromMap(row);
  }

  Future<UserAddress> update(UserAddress address) async {
    if (!AppConfig.hasSupabase) return address;
    if (address.isDefault) {
      await supabase
          .from('user_addresses')
          .update({'is_default': false})
          .eq('user_id', address.userId)
          .neq('id', address.id);
    }
    final row = await supabase
        .from('user_addresses')
        .update({
          'label': address.label.label,
          'full_address': address.fullAddress,
          'is_default': address.isDefault,
        })
        .eq('id', address.id)
        .select()
        .single();
    return UserAddress.fromMap(row);
  }

  Future<void> delete(String id) async {
    if (!AppConfig.hasSupabase) return;
    await supabase.from('user_addresses').delete().eq('id', id);
  }

  Future<void> setDefault(String userId, String id) async {
    if (!AppConfig.hasSupabase) return;
    await supabase
        .from('user_addresses')
        .update({'is_default': false})
        .eq('user_id', userId);
    await supabase
        .from('user_addresses')
        .update({'is_default': true})
        .eq('id', id);
  }
}
