import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../core/utils/formatters.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import 'my_events_screen.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/user_bottom_nav.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    if (_hydrated) return;
    _nameCtrl.text = profile.name ?? '';
    _hydrated = true;
  }

  Future<void> _save(UserProfile profile) async {
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).upsert(
            profile.copyWith(name: _nameCtrl.text.trim()),
          );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to place new bookings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(
              'Sign out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (AppConfig.hasSupabase) {
      await sb.auth.signOut();
    }
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        automaticallyImplyLeading: false,
      ),
      bottomBar: const UserBottomNav(active: UserNavTab.profile),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(currentProfileProvider)),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not signed in'));
          }
          _hydrate(profile);
          return ListView(
            children: [
              const SizedBox(height: AppSizes.lg),
              _Header(profile: profile)
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: 0.05, end: 0),
              const SizedBox(height: AppSizes.lg),
              const _StatsRow(),
              const SizedBox(height: AppSizes.xl),
              Text('ACCOUNT', style: AppTextStyles.overline),
              const SizedBox(height: AppSizes.sm),
              AppCard(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  children: [
                    _FieldRow(
                      label: 'Name',
                      icon: PhosphorIconsBold.user,
                      child: _editing
                          ? TextField(
                              controller: _nameCtrl,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Your name',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: AppSizes.md,
                                  vertical: AppSizes.sm,
                                ),
                              ),
                            )
                          : Text(
                              profile.name?.isNotEmpty == true
                                  ? profile.name!
                                  : 'Not set',
                              style: AppTextStyles.bodyBold,
                            ),
                    ),
                    const Divider(height: AppSizes.xl),
                    _FieldRow(
                      label: 'Email',
                      icon: PhosphorIconsBold.envelope,
                      child: Text(
                        profile.email ?? 'Not set',
                        style: AppTextStyles.body,
                      ),
                    ),
                    if (profile.phone != null) ...[
                      const Divider(height: AppSizes.xl),
                      _FieldRow(
                        label: 'Phone',
                        icon: PhosphorIconsBold.phone,
                        child:
                            Text(profile.phone!, style: AppTextStyles.body),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              if (_editing) ...[
                PrimaryButton(
                  label: 'Save changes',
                  icon: PhosphorIconsBold.checkCircle,
                  loading: _saving,
                  onPressed: () => _save(profile),
                ),
                const SizedBox(height: AppSizes.sm),
                PrimaryButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.ghost,
                  onPressed: () {
                    _hydrated = false;
                    _hydrate(profile);
                    setState(() => _editing = false);
                  },
                ),
              ] else
                PrimaryButton(
                  label: 'Edit profile',
                  icon: PhosphorIconsBold.pencilSimple,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => setState(() => _editing = true),
                ),
              const SizedBox(height: AppSizes.xl),
              Text('QUICK LINKS', style: AppTextStyles.overline),
              const SizedBox(height: AppSizes.sm),
              _ProfileLink(
                icon: PhosphorIconsDuotone.calendarCheck,
                iconColor: AppColors.accentDark,
                iconBg: AppColors.accentSoft,
                label: 'My events',
                onTap: () => context.push(AppRoutes.myEvents),
              ),
              const SizedBox(height: AppSizes.sm),
              _ProfileLink(
                icon: PhosphorIconsDuotone.mapPinArea,
                iconColor: AppColors.primary,
                iconBg: AppColors.primarySoft,
                label: 'My addresses',
                onTap: () => context.push(AppRoutes.addresses),
              ),
              const SizedBox(height: AppSizes.sm),
              _ProfileLink(
                icon: PhosphorIconsDuotone.heart,
                iconColor: AppColors.primary,
                iconBg: AppColors.primarySoft,
                label: 'Favorites',
                onTap: () => context.push(AppRoutes.favorites),
              ),
              const SizedBox(height: AppSizes.xxl),
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(PhosphorIconsBold.signOut),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final UserProfile profile;

  String _initials() {
    final src = (profile.name?.trim().isNotEmpty == true
            ? profile.name!
            : profile.email ?? 'User')
        .trim();
    final parts = src.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts.first[0] + parts[1][0]).toUpperCase();
    }
    return src.substring(0, src.length < 2 ? src.length : 2).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(),
              style: AppTextStyles.heading1.copyWith(
                color: Colors.white,
                fontSize: 26,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.name?.trim().isNotEmpty == true
                      ? profile.name!
                      : 'Set your name',
                  style: AppTextStyles.heading1.copyWith(
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.email != null)
                  Text(
                    profile.email!,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppSizes.sm),
                StatusBadge(
                  label: profile.role.label.toUpperCase(),
                  tone: profile.isAdmin
                      ? StatusTone.warning
                      : StatusTone.info,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersStreamProvider).valueOrNull ?? const [];
    final totalSpent = orders.fold<double>(0, (s, o) => s + o.total);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: PhosphorIconsDuotone.calendarCheck,
              value: '${orders.length}',
              label: 'Events',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _StatCard(
              icon: PhosphorIconsDuotone.wallet,
              value: Formatters.currency(totalSpent),
              label: 'Total spent',
              color: AppColors.accentDark,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _StatCard(
              icon: PhosphorIconsDuotone.medal,
              value: orders.length >= 3
                  ? 'Pro'
                  : orders.length >= 1
                      ? 'Active'
                      : 'New',
              label: 'Status',
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSizes.sm),
          Text(value,
              style: AppTextStyles.heading2.copyWith(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(child: Text(label, style: AppTextStyles.bodyBold)),
          const Icon(PhosphorIconsBold.caretRight,
              color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.icon,
    required this.child,
  });
  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSizes.md),
        SizedBox(
          width: 60,
          child: Text(label, style: AppTextStyles.captionBold),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(child: child),
      ],
    );
  }
}
