import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/dev/test_accounts.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../data/models/user_role.dart';
import '../../../shared/providers/auth_providers.dart';

/// Local-dev shortcut: a row of role chips that one-tap signs you in
/// using the seeded test accounts, so you don't have to type a different
/// email + password every time you're flipping between roles.
///
/// Renders nothing in production builds (`!AppConfig.isDev`) so the
/// panel never ships to real users.
class DevSignInPanel extends ConsumerStatefulWidget {
  const DevSignInPanel({super.key});

  @override
  ConsumerState<DevSignInPanel> createState() => _DevSignInPanelState();
}

class _DevSignInPanelState extends ConsumerState<DevSignInPanel> {
  String? _busyEmail; // email of the account currently signing in

  Future<void> _signInAs(DevTestAccount acc) async {
    if (!AppConfig.hasSupabase) {
      // Stub mode — Supabase isn't configured, just fire the customer
      // home so the dev can browse the local UI.
      if (!mounted) return;
      context.go(AppRoutes.userHome);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _busyEmail = acc.email);
    try {
      // Sign out first so switching users doesn't keep the previous
      // session attached (Supabase silently re-uses tokens otherwise).
      await sb.auth.signOut();
      await sb.auth.signInWithPassword(
        email: acc.email,
        password: acc.password,
      );
      ref.invalidate(currentProfileProvider);
      final profile = await ref.read(currentProfileProvider.future);
      if (!mounted) return;
      final role = profile?.role ?? UserRole.customer;
      context.go(switch (role) {
        UserRole.admin => AppRoutes.adminHome,
        UserRole.banquet => AppRoutes.banquetHome,
        UserRole.restaurant => AppRoutes.restaurantHome,
        UserRole.manager => AppRoutes.managerHome,
        UserRole.serviceBoy => AppRoutes.serviceBoyHome,
        UserRole.customer => AppRoutes.userHome,
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dev sign-in failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dev sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyEmail = null);
    }
  }

  Color _roleColor(String role) {
    return switch (role) {
      'banquet' => const Color(0xFF2B6CB0),
      'manager' => const Color(0xFFE5A100),
      'service_boy' => const Color(0xFF1BA672),
      'restaurant' => const Color(0xFF7C3AED),
      'admin' => const Color(0xFFE23744),
      _ => const Color(0xFF6B5D4F),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isDev) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5A100).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A100),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'One-tap sign in',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B6914),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Local-only · uses seeded dawat.test accounts',
            style: TextStyle(fontSize: 11, color: Color(0xFF8B6914)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final acc in devTestAccounts)
                _AccountChip(
                  label: acc.label,
                  color: _roleColor(acc.role),
                  busy: _busyEmail == acc.email,
                  disabled: _busyEmail != null && _busyEmail != acc.email,
                  onTap: () => _signInAs(acc),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.label,
    required this.color,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = disabled ? color.withValues(alpha: 0.4) : color;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.10),
          border: Border.all(color: fg.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: fg),
              )
            else
              Icon(Icons.bolt_rounded, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
