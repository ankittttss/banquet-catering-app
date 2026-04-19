import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/delivery_assignment.dart';
import '../../../shared/providers/delivery_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../widgets/delivery_bottom_nav.dart';

class DeliveryHistoryScreen extends ConsumerStatefulWidget {
  const DeliveryHistoryScreen({super.key});
  @override
  ConsumerState<DeliveryHistoryScreen> createState() => _State();
}

class _State extends ConsumerState<DeliveryHistoryScreen> {
  int _tab = 0; // 0 All · 1 Completed · 2 Cancelled

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(deliveryHistoryProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(title: const Text('Delivery history')),
      bottomBar: const DeliveryBottomNav(active: DeliveryNavTab.history),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.pagePaddingSm),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: _Tab(
                      label: ['All', 'Completed', 'Cancelled'][i],
                      selected: _tab == i,
                      onTap: () => setState(() => _tab = i),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: AppSizes.xs),
                ],
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(deliveryHistoryProvider),
              ),
              data: (list) {
                final filtered = _filter(list);
                if (filtered.isEmpty) {
                  return const EmptyState(
                    title: 'No deliveries yet',
                    message:
                        'Completed deliveries will show up here.',
                    icon: PhosphorIconsDuotone.clockCounterClockwise,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pagePaddingSm,
                      vertical: AppSizes.xs),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _Tile(a: filtered[i]),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.sm),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<DeliveryAssignment> _filter(List<DeliveryAssignment> list) {
    return switch (_tab) {
      1 => list
          .where((a) => a.status == DeliveryStatus.delivered)
          .toList(),
      2 => list
          .where((a) => a.status == DeliveryStatus.cancelled)
          .toList(),
      _ => list,
    };
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: selected ? AppColors.textPrimary : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.captionBold.copyWith(
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.a});
  final DeliveryAssignment a;
  @override
  Widget build(BuildContext context) {
    final delivered = a.status == DeliveryStatus.delivered;
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.catGoldLt,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(PhosphorIconsFill.forkKnife,
                    color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Text(a.restaurantName,
                    style: AppTextStyles.bodyBold),
              ),
              _Pill(
                label: delivered ? 'Delivered' : 'Cancelled',
                color: delivered
                    ? AppColors.success
                    : AppColors.primary,
                bg: delivered
                    ? AppColors.catGreenLt
                    : AppColors.primarySoft,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${a.eventLabel} · ${a.guestCount} guests',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Text(
                      Formatters.currency(a.earningAmount * 12),
                      style: AppTextStyles.bodyBold,
                    ),
                    const Spacer(),
                    Text(
                      a.deliveredAt != null
                          ? Formatters.time(a.deliveredAt!)
                          : Formatters.date(a.offeredAt),
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(width: AppSizes.md),
                    Text(
                      delivered
                          ? '+${Formatters.currency(a.earningAmount)}'
                          : '₹0',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: delivered
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }
}
