import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer.dart';
import '../widgets/banquet_bottom_nav.dart';

class BanquetVenuesScreen extends ConsumerWidget {
  const BanquetVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(myBanquetVenuesProvider);
    return AppScaffold(
      appBar: AppBar(
        // Hide the back arrow when arrived via bottom-nav (no prior
        // route to pop). Operator already has the tab to switch away.
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(PhosphorIconsBold.arrowLeft),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('My venues'),
      ),
      bottomBar: const BanquetBottomNav(active: BanquetNavTab.venues),
      body: venues.when(
        loading: () => const _VenueListLoading(),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(myBanquetVenuesProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: PhosphorIconsDuotone.buildings,
              title: 'No venues yet',
              message:
                  'An admin will provision venues under your account. Once added, capacity and availability will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            itemCount: rows.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSizes.md),
            itemBuilder: (_, i) => _VenueCard(venue: rows[i]),
          );
        },
      ),
    );
  }
}

class _VenueListLoading extends StatelessWidget {
  const _VenueListLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, __) => AppCard(
        child: Row(
          children: [
            ShimmerBox(
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            const SizedBox(width: AppSizes.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 160, height: 16),
                  SizedBox(height: 8),
                  ShimmerBox(width: 220, height: 12),
                  SizedBox(height: 12),
                  ShimmerBox(width: 130, height: 22),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});
  final BanquetVenue venue;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: const Icon(PhosphorIconsDuotone.buildings,
                    color: AppColors.primary),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(venue.name, style: AppTextStyles.heading2),
                    if (venue.address != null) ...[
                      const SizedBox(height: 2),
                      Text(venue.address!,
                          style: AppTextStyles.caption, maxLines: 2),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              if (venue.capacity != null)
                _StatChip(
                  icon: PhosphorIconsDuotone.users,
                  label: 'Up to ${venue.capacity} guests',
                ),
              const SizedBox(width: AppSizes.sm),
              _StatChip(
                icon: PhosphorIconsBold.circle,
                label: venue.isActive ? 'Active' : 'Inactive',
                colour: venue.isActive
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.colour,
  });
  final IconData icon;
  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final c = colour ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.captionBold.copyWith(color: c)),
        ],
      ),
    );
  }
}
