import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    this.name,
    this.phone,
    this.email,
  });

  final String id;
  final UserRole role;
  final String? name;
  final String? phone;
  final String? email;

  bool get isAdmin => role == UserRole.admin;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      role: UserRole.fromString(map['role'] as String?),
      name: map['name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role.dbValue,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      };

  UserProfile copyWith({String? name, String? phone, String? email}) {
    return UserProfile(
      id: id,
      role: role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }
}
