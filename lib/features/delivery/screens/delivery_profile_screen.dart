import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../shared/providers/delivery_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../widgets/delivery_bottom_nav.dart';

class DeliveryProfileScreen extends ConsumerWidget {
  const DeliveryProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(currentDriverProvider).valueOrNull;

    return AppScaffold(
      padded: false,
      appBar: AppBar(title: const Text('Profile')),
      bottomBar: const DeliveryBottomNav(active: DeliveryNavTab.profile),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.lg,
              AppSizes.pagePadding,
              0,
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.catBlueLt,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                  ),
                  child: const Icon(PhosphorIconsFill.userCircle,
                      color: AppColors.catBlue, size: 44),
                ),
                const SizedBox(height: AppSizes.md),
                Text(driver?.name ?? '—', style: AppTextStyles.heading1),
                const SizedBox(height: 2),
                Text(
                  driver == null
                      ? ''
                      : '${driver.phone} · ${driver.vehicle}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: '⭐ ${driver?.rating.toStringAsFixed(1) ?? "–"}',
                        label: 'Rating',
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        value: '${driver?.totalDeliveries ?? 0}',
                        label: 'Deliveries',
                      ),
                    ),
                    const Expanded(
                      child: _Stat(value: '2 yrs', label: 'Experience'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePaddingSm),
            child: Column(
              children: [
                _MenuItem(
                  icon: PhosphorIconsBold.userCircle,
                  color: AppColors.primary,
                  bg: AppColors.primarySoft,
                  label: 'Edit profile',
                ),
                _MenuItem(
                  icon: PhosphorIconsBold.motorcycle,
                  color: AppColors.info,
                  bg: AppColors.catBlueLt,
                  label: 'Vehicle details',
                ),
                _MenuItem(
                  icon: PhosphorIconsBold.bank,
                  color: AppColors.success,
                  bg: AppColors.catGreenLt,
                  label: 'Bank & payout',
                ),
                _MenuItem(
                  icon: PhosphorIconsBold.fileText,
                  color: AppColors.accent,
                  bg: AppColors.catGoldLt,
                  label: 'Documents',
                ),
                _MenuItem(
                  icon: PhosphorIconsBold.gear,
                  color: AppColors.textSecondary,
                  bg: AppColors.surfaceAlt,
                  label: 'Settings',
                ),
                _MenuItem(
                  icon: PhosphorIconsBold.question,
                  color: AppColors.textSecondary,
                  bg: AppColors.surfaceAlt,
                  label: 'Help & support',
                ),
                _MenuItem(
                  icon: PhosphorIconsBold.signOut,
                  color: AppColors.primary,
                  bg: AppColors.primarySoft,
                  label: 'Log out',
                  labelColor: AppColors.primary,
                  showChevron: false,
                  onTap: () async {
                    if (AppConfig.hasSupabase) {
                      await sb.auth.signOut();
                    }
                    if (!context.mounted) return;
                    context.go(AppRoutes.login);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xl),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.heading2),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.captionBold
                  .copyWith(color: AppColors.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
    this.labelColor,
    this.showChevron = true,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;
  final Color? labelColor;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(icon, color: color, size: 18),
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
            if (showChevron)
              const Icon(PhosphorIconsBold.caretRight,
                  color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}
