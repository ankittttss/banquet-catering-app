import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../shared/presentation/order_status_presentation.dart';
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
                      tone: order.orderStatus.tone,
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
            active: i == currentIndex && current != OrderStatus.cancelled,
            last: i == steps.length - 1,
            index: i,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
    required this.last,
    required this.index,
  });

  final String label;
  final bool done;
  final bool active;
  final bool last;
  final int index;

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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: done ? AppColors.primary : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color:
                                AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: done
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 18)
                        .animate(delay: (index * 120).ms)
                        .scale(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          duration: 380.ms,
                          curve: Curves.elasticOut,
                        )
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color,
                  )
                      .animate(delay: (index * 120 + 200).ms)
                      .custom(
                        duration: 300.ms,
                        builder: (_, value, child) => ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: done ? 1.0 : value,
                            child: child,
                          ),
                        ),
                      ),
                ),
            ],
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 4,
                bottom: AppSizes.lg,
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: done
                        ? AppTextStyles.bodyBold
                        : AppTextStyles.bodyMuted,
                  ),
                  if (active) ...[
                    const SizedBox(width: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusPill),
                      ),
                      child: Text(
                        'NOW',
                        style: AppTextStyles.overline.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    )
                        .animate(
                            onPlay: (c) => c.repeat(reverse: true))
                        .fadeIn(duration: 700.ms)
                        .then()
                        .fadeOut(duration: 700.ms),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
