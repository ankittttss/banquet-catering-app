import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../data/models/user_profile.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/notification_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/user_bottom_nav.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      bottomBar: const UserBottomNav(active: UserNavTab.profile),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          if (profile == null) return const _SignedOutView();
          return _SignedInView(profile: profile, unread: unread);
        },
      ),
    );
  }
}

// ───────────────────────── Signed-in layout ─────────────────────────

class _SignedInView extends ConsumerWidget {
  const _SignedInView({required this.profile, required this.unread});
  final UserProfile profile;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.xxxl),
      children: [
        const SizedBox(height: AppSizes.sm),
        _Header(profile: profile)
            .animate()
            .fadeIn(duration: 260.ms)
            .slideY(begin: 0.04, end: 0),
        const SizedBox(height: AppSizes.md),
        _ProfileTile(
          icon: Icons.receipt_long_rounded,
          label: 'My orders',
          iconBg: AppColors.primarySoft,
          iconColor: AppColors.primary,
          onTap: () => context.go(AppRoutes.myEvents),
        ),
        _ProfileTile(
          icon: Icons.favorite_rounded,
          label: 'Favorites',
          iconBg: AppColors.catPinkLt,
          iconColor: AppColors.catPink,
          onTap: () => context.push(AppRoutes.favorites),
        ),
        _ProfileTile(
          icon: Icons.location_on_rounded,
          label: 'Saved addresses',
          iconBg: AppColors.catBlueLt,
          iconColor: AppColors.catBlue,
          onTap: () => context.push(AppRoutes.addresses),
        ),
        _ProfileTile(
          icon: Icons.payments_rounded,
          label: 'Payment methods',
          iconBg: AppColors.catGreenLt,
          iconColor: AppColors.catGreen,
          onTap: () {},
        ),
        _ProfileTile(
          icon: Icons.notifications_rounded,
          label: 'Notifications',
          iconBg: AppColors.catGoldLt,
          iconColor: AppColors.catGold,
          badge: unread > 0 ? unread : null,
          onTap: () => context.push(AppRoutes.notifications),
        ),
        _ProfileTile(
          icon: Icons.help_rounded,
          label: 'Help & support',
          iconBg: AppColors.catPurpleLt,
          iconColor: AppColors.catPurple,
          onTap: () {},
        ),
        _ProfileTile(
          icon: Icons.info_rounded,
          label: 'About',
          iconBg: AppColors.surfaceAlt,
          iconColor: AppColors.textSecondary,
          onTap: () {},
        ),
        _ProfileTile(
          icon: Icons.logout_rounded,
          label: 'Log out',
          labelColor: AppColors.primary,
          iconBg: AppColors.primarySoft,
          iconColor: AppColors.primary,
          showChevron: false,
          onTap: () async {
            HapticFeedback.mediumImpact();
            try {
              await sb.auth.signOut();
            } catch (_) {
              // ignore — best effort
            }
            ref.invalidate(currentProfileProvider);
            if (!context.mounted) return;
            context.go(AppRoutes.login);
          },
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final UserProfile profile;

  String _initials() {
    final name = profile.name?.trim() ?? '';
    if (name.isEmpty) {
      final email = profile.email ?? '';
      return email.isEmpty ? 'U' : email[0].toUpperCase();
    }
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = profile.name?.trim().isNotEmpty == true
        ? profile.name!
        : (profile.email ?? 'User');
    final sub =
        [profile.phone, profile.email].where((e) => e != null).join(' · ');

    return Container(
      margin:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      padding: const EdgeInsets.all(AppSizes.md + 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(),
              style: AppTextStyles.display
                  .copyWith(fontSize: 22, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: AppTextStyles.heading1),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: AppTextStyles.caption.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
    this.labelColor,
    this.showChevron = true,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;
  final Color? labelColor;
  final bool showChevron;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyBold.copyWith(
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
                child: Text(
                  '$badge',
                  style: AppTextStyles.captionBold.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
            ],
            if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Signed-out view ─────────────────────────

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person_outline_rounded,
                  size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: AppSizes.lg),
            Text('You\'re signed out', style: AppTextStyles.heading1),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Sign in to manage events, saved addresses, and more.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.login),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign in'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xl,
                  vertical: AppSizes.md,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
