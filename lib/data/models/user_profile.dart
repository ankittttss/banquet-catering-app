import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    this.name,
    this.phone,
    this.email,
    this.gender,
    this.dateOfBirth,
    this.avatarUrl,
    this.dietaryPreference,
    this.allergies = const [],
    this.notificationPrefs = const {},
  });

  final String id;
  final UserRole role;
  final String? name;
  final String? phone;
  final String? email;

  // Phase 11 extras — all optional.
  final String? gender;
  final DateTime? dateOfBirth;
  final String? avatarUrl;

  /// One of: 'veg' | 'non_veg' | 'eggetarian' | 'vegan' | 'jain' | null.
  final String? dietaryPreference;

  /// Free-form tags (e.g. 'peanuts', 'dairy'). Empty list when none selected.
  final List<String> allergies;

  /// Structured prefs. Known keys today:
  ///   order_updates, promos, event_reminders, whatsapp — all bool.
  final Map<String, dynamic> notificationPrefs;

  bool get isAdmin => role == UserRole.admin;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final rawAllergies = map['allergies'];
    final allergies = <String>[];
    if (rawAllergies is List) {
      for (final v in rawAllergies) {
        if (v is String) allergies.add(v);
      }
    }
    final rawPrefs = map['notification_prefs'];
    final prefs = <String, dynamic>{};
    if (rawPrefs is Map) {
      rawPrefs.forEach((k, v) {
        if (k is String) prefs[k] = v;
      });
    }
    DateTime? dob;
    final dobRaw = map['date_of_birth'];
    if (dobRaw is String && dobRaw.isNotEmpty) {
      dob = DateTime.tryParse(dobRaw);
    }

    return UserProfile(
      id: map['id'] as String,
      role: UserRole.fromString(map['role'] as String?),
      name: map['name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      gender: map['gender'] as String?,
      dateOfBirth: dob,
      avatarUrl: map['avatar_url'] as String?,
      dietaryPreference: map['dietary_preference'] as String?,
      allergies: allergies,
      notificationPrefs: prefs,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role.dbValue,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (gender != null) 'gender': gender,
        if (dateOfBirth != null)
          'date_of_birth':
              '${dateOfBirth!.year.toString().padLeft(4, '0')}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}',
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (dietaryPreference != null)
          'dietary_preference': dietaryPreference,
        'allergies': allergies,
        'notification_prefs': notificationPrefs,
      };

  UserProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? gender,
    DateTime? dateOfBirth,
    String? avatarUrl,
    String? dietaryPreference,
    List<String>? allergies,
    Map<String, dynamic>? notificationPrefs,
  }) {
    return UserProfile(
      id: id,
      role: role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      allergies: allergies ?? this.allergies,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
    );
  }
}
