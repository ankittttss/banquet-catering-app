enum UserRole {
  user('User', 'Plan events, pick menus, place bookings'),
  admin('Admin', 'Manage menu, charges, and incoming bookings');

  const UserRole(this.label, this.description);
  final String label;
  final String description;

  static UserRole fromString(String? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      _ => UserRole.user,
    };
  }

  String get dbValue => name; // 'user' | 'admin'
}
