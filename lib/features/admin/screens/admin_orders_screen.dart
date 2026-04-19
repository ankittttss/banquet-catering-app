import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../shared/presentation/order_status_presentation.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../widgets/assign_driver_sheet.dart';

final adminOrdersProvider =
    FutureProvider.autoDispose<List<OrderSummary>>((ref) {
  return ref.read(orderRepositoryProvider).fetchAll();
});

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(adminOrdersProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.arrowClockwise),
            onPressed: () => ref.invalidate(adminOrdersProvider),
          ),
        ],
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
            error: e, onRetry: () => ref.invalidate(adminOrdersProvider)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'No bookings yet',
              message: 'New bookings will appear here in real time.',
              icon: PhosphorIconsDuotone.receipt,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            itemBuilder: (_, i) => _OrderTile(order: list[i]),
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSizes.sm),
            itemCount: list.length,
          );
        },
      ),
    );
  }
}

class _OrderTile extends ConsumerWidget {
  const _OrderTile({required this.order});
  final OrderSummary order;

  Future<void> _updateStatus(WidgetRef ref, OrderStatus status) async {
    await ref
        .read(orderRepositoryProvider)
        .updateStatus(order.id, status);
    ref.invalidate(adminOrdersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.eventDate == null
                      ? 'Date TBD'
                      : Formatters.date(order.eventDate!),
                  style: AppTextStyles.heading2,
                ),
              ),
              StatusBadge(
                label: order.orderStatus.label,
                tone: order.orderStatus.tone,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            '${order.guestCount ?? "—"} guests · '
            '${Formatters.currency(order.total)}',
            style: AppTextStyles.caption,
          ),
          if (order.location != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(order.location!,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            children: [
              for (final s in OrderStatus.values)
                OutlinedButton(
                  onPressed: () => _updateStatus(ref, s),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: 0,
                    ),
                    foregroundColor: s.tone == StatusTone.success
                        ? AppColors.success
                        : AppColors.primary,
                    side: BorderSide(
                      color: order.orderStatus == s
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Text(s.label,
                      style: AppTextStyles.captionBold),
                ),
            ],
          ),
          if (_canAssign(order.orderStatus)) ...[
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => AssignDriverSheet.show(context, order),
                icon: const Icon(PhosphorIconsBold.motorcycle, size: 16),
                label: Text(
                  order.driverName == null
                      ? 'Assign driver'
                      : 'Reassign driver (${order.driverName})',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _canAssign(OrderStatus s) =>
      s == OrderStatus.confirmed ||
      s == OrderStatus.preparing ||
      s == OrderStatus.dispatched;

}
