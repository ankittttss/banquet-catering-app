import '../../models/user_address.dart';
import '../address_repository.dart';

/// In-memory impl used when Supabase isn't configured (local UI dev).
class StubAddressRepository implements AddressRepository {
  final List<UserAddress> _store = [];
  int _counter = 0;

  @override
  Future<List<UserAddress>> fetchForUser(String userId) async {
    return _store.where((a) => a.userId == userId).toList(growable: false);
  }

  @override
  Future<UserAddress> save(UserAddressInput input) async {
    if (input.isDefault) {
      for (var i = 0; i < _store.length; i++) {
        if (_store[i].isDefault) {
          _store[i] = UserAddress(
            id: _store[i].id,
            userId: _store[i].userId,
            label: _store[i].label,
            fullAddress: _store[i].fullAddress,
          );
        }
      }
    }
    final existingIx =
        input.id == null ? -1 : _store.indexWhere((a) => a.id == input.id);
    final next = UserAddress(
      id: input.id ?? 'stub-${++_counter}',
      userId: 'local',
      label: input.label,
      fullAddress: input.fullAddress,
      isDefault: input.isDefault,
    );
    if (existingIx == -1) {
      _store.add(next);
    } else {
      _store[existingIx] = next;
    }
    return next;
  }

  @override
  Future<void> delete(String id) async {
    _store.removeWhere((a) => a.id == id);
  }

  @override
  Future<void> setDefault(String userId, String id) async {
    for (var i = 0; i < _store.length; i++) {
      if (_store[i].userId != userId) continue;
      _store[i] = UserAddress(
        id: _store[i].id,
        userId: _store[i].userId,
        label: _store[i].label,
        fullAddress: _store[i].fullAddress,
        isDefault: _store[i].id == id,
      );
    }
  }
}
