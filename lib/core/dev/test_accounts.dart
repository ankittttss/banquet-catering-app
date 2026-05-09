/// Hardcoded mirror of the seeded test accounts in
/// [env/test_accounts.json]. Kept in sync with the seed migrations
/// (phase19_bootstrap_test_roles.sql + phase21_demo_data.sql + phase10
/// for drivers). Used only by the dev quick-sign-in panel — never read
/// in production builds because the panel itself is gated on
/// `AppConfig.isDev`.
class DevTestAccount {
  const DevTestAccount({
    required this.label,
    required this.role,
    required this.email,
    required this.password,
  });

  final String label;
  final String role;
  final String email;
  final String password;
}

const String _kDevPassword = 'dawat1234';

/// Display order is intentional — operator roles first (most-tested
/// during the new event-detail work), then customers.
const devTestAccounts = <DevTestAccount>[
  DevTestAccount(
    label: 'Banquet operator',
    role: 'banquet',
    email: 'banquet1@dawat.test',
    password: _kDevPassword,
  ),
  DevTestAccount(
    label: 'Manager',
    role: 'manager',
    email: 'manager1@dawat.test',
    password: _kDevPassword,
  ),
  DevTestAccount(
    label: 'Service boy 1',
    role: 'service_boy',
    email: 'serviceboy1@dawat.test',
    password: _kDevPassword,
  ),
  DevTestAccount(
    label: 'Service boy 2',
    role: 'service_boy',
    email: 'serviceboy2@dawat.test',
    password: _kDevPassword,
  ),
  DevTestAccount(
    label: 'Restaurant',
    role: 'restaurant',
    email: 'restaurant1@dawat.test',
    password: _kDevPassword,
  ),
  DevTestAccount(
    label: 'Admin',
    role: 'admin',
    email: 'admin1@dawat.test',
    password: _kDevPassword,
  ),
  DevTestAccount(
    label: 'Customer · Priya',
    role: 'customer',
    email: 'customer1@dawat.test',
    password: _kDevPassword,
  ),
  DevTestAccount(
    label: 'Customer · Rohan',
    role: 'customer',
    email: 'customer2@dawat.test',
    password: _kDevPassword,
  ),
  DevTestAccount(
    label: 'Customer · Ananya',
    role: 'customer',
    email: 'customer3@dawat.test',
    password: _kDevPassword,
  ),
];
