import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import 'my_events_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersStreamProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final order = list.where((o) => o.id == orderId).firstOrNull;
          if (order == null) {
            return const Center(child: Text('Order not found'));
          }
          return ListView(
            children: [
              const SizedBox(height: AppSizes.md),
              AppCard(
                color: AppColors.primarySoft,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsDuotone.calendar,
                        size: 36, color: AppColors.primary),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.eventDate == null
                                ? 'Date TBD'
                                : Formatters.date(order.eventDate!),
                            style: AppTextStyles.heading1
                                .copyWith(color: AppColors.primary),
                          ),
                          Text(
                            '${order.guestCount ?? "—"} guests',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: order.orderStatus.label,
                      tone: _tone(order.orderStatus),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Text('PROGRESS', style: AppTextStyles.overline),
              const SizedBox(height: AppSizes.sm),
              AppCard(child: _StatusStepper(current: order.orderStatus)),
              const SizedBox(height: AppSizes.lg),
              Text('PAYMENT', style: AppTextStyles.overline),
              const SizedBox(height: AppSizes.sm),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total payable',
                              style: AppTextStyles.captionBold),
                          Text(Formatters.currency(order.total),
                              style: AppTextStyles.heading1),
                        ],
                      ),
                    ),
                    StatusBadge(
                      label: order.paymentStatus.name.toUpperCase(),
                      tone: order.paymentStatus == PaymentStatus.paid
                          ? StatusTone.success
                          : StatusTone.pending,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  StatusTone _tone(OrderStatus s) => switch (s) {
        OrderStatus.placed => StatusTone.pending,
        OrderStatus.confirmed => StatusTone.info,
        OrderStatus.preparing => StatusTone.info,
        OrderStatus.dispatched => StatusTone.warning,
        OrderStatus.delivered => StatusTone.success,
        OrderStatus.cancelled => StatusTone.error,
      };
}

class _StatusStepper extends StatelessWidget {
  const _StatusStepper({required this.current});
  final OrderStatus current;

  @override
  Widget build(BuildContext context) {
    const steps = [
      OrderStatus.placed,
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.dispatched,
      OrderStatus.delivered,
    ];
    final currentIndex = steps.indexOf(current);
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _StepRow(
            label: steps[i].label,
            done: i <= currentIndex && current != OrderStatus.cancelled,
            last: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.last,
  });

  final String label;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.primary : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done ? AppColors.primary : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 16)
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 2,
                bottom: AppSizes.lg,
              ),
              child: Text(
                label,
                style: done
                    ? AppTextStyles.bodyBold
                    : AppTextStyles.bodyMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
