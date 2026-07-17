import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/admin_restaurant_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';

// Deep-indigo chrome so the admin console never gets confused with the
// customer or operator apps.
const _indigoDeep = Color(0xFF1E1B4B);
const _indigo = Color(0xFF4338CA);

/// Onboarding pipeline counts per lifecycle state — the one statistic that
/// belongs to an onboarding admin. Four cheap count-only queries (pageSize 1)
/// instead of the old console's full 23k-item catalog download.
final _kitchenCountsProvider =
    FutureProvider.autoDispose<Map<RestaurantStatus, int>>((ref) async {
  final repo = ref.read(adminRestaurantRepositoryProvider);
  final pages = await Future.wait([
    for (final s in RestaurantStatus.values)
      repo.fetchPage(status: s, pageSize: 1),
  ]);
  return {
    for (var i = 0; i < RestaurantStatus.values.length; i++)
      RestaurantStatus.values[i]: pages[i].total,
  };
});

/// Deliberately minimal admin console: the admin's job is onboarding /
/// managing kitchens and the charges config — nothing else. The old
/// five-tab operations dashboard (GMV, bookings, team, payouts, catalog
/// stats) was retired: order statuses flow automatically from banquet
/// decisions + kitchen progress, menus are managed per restaurant, and
/// anything new gets built when the business actually needs it.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(_kitchenCountsProvider);

    return AppScaffold(
      padded: false,
      backgroundColor: AppColors.surfaceWarm,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          Expanded(
            child: RefreshIndicator(
              color: _indigo,
              onRefresh: () async {
                ref.invalidate(_kitchenCountsProvider);
                ref.invalidate(adminRestaurantListProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.lg,
                  AppSizes.pagePadding,
                  AppSizes.xl,
                ),
                children: [
                  _KitchensCard(counts: counts),
                  const SizedBox(height: AppSizes.md),
                  _PrimaryButton(
                    icon: PhosphorIconsBold.plus,
                    label: 'Onboard kitchen',
                    onTap: () => context.push(AppRoutes.adminRestaurantNew),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  _NavTile(
                    icon: PhosphorIconsDuotone.gearSix,
                    iconBg: AppColors.catBlueLt,
                    iconColor: AppColors.catBlue,
                    title: 'Charges config',
                    subtitle: 'Fees, taxes and per-head service rates',
                    onTap: () => context.push(AppRoutes.adminCharges),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  _NavTile(
                    icon: PhosphorIconsDuotone.signOut,
                    iconBg: AppColors.primarySoft,
                    iconColor: AppColors.primary,
                    title: 'Sign out',
                    subtitle: null,
                    showChevron: false,
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      if (AppConfig.hasSupabase) {
                        try {
                          await sb.auth.signOut();
                        } catch (_) {
                          // best effort — still route to login
                        }
                      }
                      if (context.mounted) context.go(AppRoutes.login);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.lg,
        AppSizes.pagePadding,
        AppSizes.lg,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.7, -1),
          end: Alignment(0.7, 1),
          colors: [_indigoDeep, _indigo],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADMIN CONSOLE',
            style: AppTextStyles.overline.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dawat operations',
            style: AppTextStyles.displaySm.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            'Onboard kitchens · manage charges',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Kitchens pipeline card ─────────────────────────

class _KitchensCard extends StatelessWidget {
  const _KitchensCard({required this.counts});
  final AsyncValue<Map<RestaurantStatus, int>> counts;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: () => context.push(AppRoutes.adminRestaurants),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(
                  PhosphorIconsDuotone.storefront,
                  size: 26,
                  color: _indigo,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kitchens', style: AppTextStyles.heading2),
                    const SizedBox(height: 3),
                    counts.when(
                      loading: () => Text(
                        'Counting…',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                      error: (_, __) => Text(
                        'Tap to open the list',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                      data: (c) => Text(
                        _pipelineLine(c),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              const Icon(
                PhosphorIconsBold.caretRight,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _pipelineLine(Map<RestaurantStatus, int> c) {
    final live = c[RestaurantStatus.published] ?? 0;
    final drafts = c[RestaurantStatus.draft] ?? 0;
    final suspended = c[RestaurantStatus.suspended] ?? 0;
    final archived = c[RestaurantStatus.archived] ?? 0;
    final parts = <String>[
      '$live live',
      '$drafts draft${drafts == 1 ? '' : 's'}',
      if (suspended > 0) '$suspended suspended',
      if (archived > 0) '$archived archived',
    ];
    return parts.join(' · ');
  }
}

// ───────────────────────── Buttons / tiles ─────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _indigo,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: AppSizes.sm),
              Text(
                label,
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyBold),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                const Icon(
                  PhosphorIconsBold.caretRight,
                  size: 18,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
