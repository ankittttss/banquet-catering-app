enum AddressLabel {
  home('Home'),
  work('Work'),
  other('Other');

  const AddressLabel(this.label);
  final String label;

  static AddressLabel fromString(String? v) => switch (v) {
        'Work' => AddressLabel.work,
        'Other' => AddressLabel.other,
        _ => AddressLabel.home,
      };
}

class UserAddress {
  const UserAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.fullAddress,
    this.isDefault = false,
  });

  final String id;
  final String userId;
  final AddressLabel label;
  final String fullAddress;
  final bool isDefault;

  factory UserAddress.fromMap(Map<String, dynamic> map) => UserAddress(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        label: AddressLabel.fromString(map['label'] as String?),
        fullAddress: map['full_address'] as String,
        isDefault: (map['is_default'] as bool?) ?? false,
      );
}

/// Input used to create or update an address. Does NOT carry an id on create.
class UserAddressInput {
  const UserAddressInput({
    this.id,
    required this.label,
    required this.fullAddress,
    required this.isDefault,
  });

  final String? id;
  final AddressLabel label;
  final String fullAddress;
  final bool isDefault;
}
