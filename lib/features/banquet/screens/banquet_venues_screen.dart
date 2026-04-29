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
import '../../../shared/widgets/app_scaffold.dart';

class BanquetVenuesScreen extends ConsumerWidget {
  const BanquetVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(myBanquetVenuesProvider);
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('My venues'),
      ),
      body: venues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load venues: $e',
              style: AppTextStyles.caption),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIconsDuotone.buildings,
                        size: 56, color: AppColors.textMuted),
                    const SizedBox(height: AppSizes.md),
                    Text('No venues yet', style: AppTextStyles.heading3),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      'An admin will provision venues under your account.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
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
