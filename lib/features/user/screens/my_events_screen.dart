import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/order_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/user_bottom_nav.dart';

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersStreamProvider);
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('My orders'),
        automaticallyImplyLeading: false,
      ),
      bottomBar: const UserBottomNav(active: UserNavTab.orders),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load orders',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(myOrdersStreamProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No orders yet',
              message: 'Your bookings will appear here.',
              actionLabel: 'Start a new event',
              onAction: () => context.push(AppRoutes.eventDetails),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(myOrdersStreamProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.sm),
              itemBuilder: (_, i) => _OrderCard(
                order: list[i],
                restaurants: restaurants,
              ).animate().fadeIn(duration: 260.ms, delay: (40 * i).ms),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Order card ─────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.restaurants});
  final OrderSummary order;
  final List<Restaurant> restaurants;

  @override
  Widget build(BuildContext context) {
    final r = restaurants.isEmpty
        ? null
        : restaurants.first; // Phase 3 doesn't join order→restaurant; use first for label.
    final bg = AppColors.fromHex(r?.heroBgHex, fallback: AppColors.primarySoft);
    final badge = _StatusBadge(status: order.orderStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(AppRoutes.orderDetailFor(order.id));
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        r?.heroEmoji ?? '🍽️',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order.id.substring(0, 6).toUpperCase()}',
                            style: AppTextStyles.heading3,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _dateLabel(order.createdAt),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    badge,
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                Container(
                  height: 1,
                  color: AppColors.divider,
                ),
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Formatters.currency(order.total),
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                      ),
                    ),
                    if (order.orderStatus == OrderStatus.delivered ||
                        order.orderStatus == OrderStatus.cancelled)
                      _ReorderButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push(AppRoutes.userHome);
                        },
                      )
                    else
                      _TrackButton(
                        onTap: () => context
                            .push(AppRoutes.orderDetailFor(order.id)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today · ${_clock(d)}';
    if (diff.inDays == 1) return 'Yesterday · ${_clock(d)}';
    return Formatters.date(d);
  }

  String _clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final am = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      OrderStatus.delivered => (AppColors.catGreenLt, AppColors.success),
      OrderStatus.cancelled => (AppColors.primarySoft, AppColors.primary),
      OrderStatus.dispatched => (AppColors.catBlueLt, AppColors.info),
      OrderStatus.preparing => (AppColors.catGoldLt, AppColors.warning),
      _ => (AppColors.surfaceAlt, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.captionBold.copyWith(
          color: fg,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ReorderButton extends StatelessWidget {
  const _ReorderButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        'Reorder',
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.primary,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  const _TrackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: 6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        'Track',
        style: AppTextStyles.captionBold.copyWith(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }
}
