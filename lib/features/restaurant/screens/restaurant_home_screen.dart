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
import '../../../data/models/order_vendor_lot.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/providers/restaurant_ops_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';

class RestaurantHomeScreen extends ConsumerWidget {
  const RestaurantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lots = ref.watch(myVendorLotsProvider);
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Restaurant'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.signOut),
            tooltip: 'Sign out',
            onPressed: () async {
              if (AppConfig.hasSupabase) await sb.auth.signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(myVendorLotsProvider),
        child: lots.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: AppSizes.xl),
            Text('Could not load orders: $e',
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ]),
          data: (rows) {
            final active = rows
                .where((r) => r.status != VendorLotStatus.delivered &&
                    r.status != VendorLotStatus.cancelled)
                .toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: AppSizes.xl),
              children: [
                const SizedBox(height: AppSizes.sm),
                Text('Kitchen board', style: AppTextStyles.display),
                const SizedBox(height: AppSizes.xs),
                Text(
                  active.isEmpty
                      ? 'No active lots. New prep jobs will appear here in real time.'
                      : '${active.length} lot${active.length == 1 ? '' : 's'} waiting on you.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: AppSizes.lg),
                if (active.isEmpty) const _EmptyBoard(),
                for (final lot in rows) ...[
                  _LotCard(lot: lot),
                  const SizedBox(height: AppSizes.md),
                ],
              ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.06, end: 0),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(PhosphorIconsDuotone.forkKnife,
              size: 40, color: AppColors.textMuted),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              'When a multi-vendor order routes a lot to your kitchen, it lands here.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _LotCard extends ConsumerWidget {
  const _LotCard({required this.lot});
  final OrderVendorLot lot;

  VendorLotStatus? _nextStatus() => switch (lot.status) {
        VendorLotStatus.pending => VendorLotStatus.accepted,
        VendorLotStatus.accepted => VendorLotStatus.preparing,
        VendorLotStatus.preparing => VendorLotStatus.readyForPickup,
        VendorLotStatus.readyForPickup => null, // Porter picks up next.
        _ => null,
      };

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    final next = _nextStatus();
    if (next == null) return;
    try {
      await ref
          .read(restaurantOpsRepositoryProvider)
          .updateLotStatus(lotId: lot.id, status: next);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Color _statusColor() => switch (lot.status) {
        VendorLotStatus.pending => AppColors.primary,
        VendorLotStatus.accepted => AppColors.primary,
        VendorLotStatus.preparing => AppColors.accent,
        VendorLotStatus.readyForPickup => AppColors.success,
        VendorLotStatus.pickedUp => AppColors.textMuted,
        VendorLotStatus.delivered => AppColors.success,
        VendorLotStatus.cancelled => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = _nextStatus();
    final statusColor = _statusColor();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lot.restaurantName ?? 'Lot',
                  style: AppTextStyles.heading2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  lot.status.label,
                  style: AppTextStyles.captionBold
                      .copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${Formatters.currency(lot.subtotal)} subtotal',
            style: AppTextStyles.caption,
          ),
          if (next != null) ...[
            const SizedBox(height: AppSizes.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _advance(context, ref),
                icon: const Icon(PhosphorIconsBold.arrowRight, size: 16),
                label: Text('Mark ${next.label.toLowerCase()}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
