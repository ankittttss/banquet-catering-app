import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/user_bottom_nav.dart';

final myOrdersStreamProvider =
    StreamProvider.autoDispose<List<OrderSummary>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.read(orderRepositoryProvider).streamMyOrders(userId);
});

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersStreamProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        automaticallyImplyLeading: false,
      ),
      body: orders.when(
        loading: () => _SkeletonList(),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              title: 'No events yet',
              message: 'Your first booking will show up here.',
              icon: PhosphorIconsDuotone.calendarPlus,
              actionLabel: 'Plan your first event',
              onAction: () => context.go(AppRoutes.eventDetails),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myOrdersStreamProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              itemBuilder: (_, i) {
                final o = list[i];
                return _OrderCard(order: o)
                    .animate(delay: (i * 60).ms)
                    .fadeIn(duration: 320.ms)
                    .slideY(begin: 0.06, end: 0);
              },
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.md),
              itemCount: list.length,
            ),
          );
        },
      ),
      bottomBar: const UserBottomNav(active: UserNavTab.events),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      loading: true,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        itemBuilder: (_, __) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
        ),
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppSizes.md),
        itemCount: 4,
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final OrderSummary order;

  StatusTone _tone() => switch (order.orderStatus) {
        OrderStatus.placed => StatusTone.pending,
        OrderStatus.confirmed => StatusTone.info,
        OrderStatus.preparing => StatusTone.info,
        OrderStatus.dispatched => StatusTone.warning,
        OrderStatus.delivered => StatusTone.success,
        OrderStatus.cancelled => StatusTone.error,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(AppRoutes.orderDetailFor(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.eventDate == null
                    ? 'Date TBD'
                    : Formatters.date(order.eventDate!),
                style: AppTextStyles.heading2
                    .copyWith(color: AppColors.primary),
              ),
              const Spacer(),
              StatusBadge(
                label: order.orderStatus.label,
                tone: _tone(),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(PhosphorIconsBold.users,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSizes.xs),
              Text('${order.guestCount ?? "—"} guests',
                  style: AppTextStyles.caption),
              const SizedBox(width: AppSizes.md),
              const Icon(PhosphorIconsBold.receipt,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: AppSizes.xs),
              Text(Formatters.currency(order.total),
                  style: AppTextStyles.captionBold),
            ],
          ),
          if (order.location != null) ...[
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                const Icon(PhosphorIconsBold.mapPin,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: AppSizes.xs),
                Expanded(
                  child: Text(
                    order.location!,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
