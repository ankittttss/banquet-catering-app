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
import '../../../shared/providers/order_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));
    final asyncState = ref.watch(myOrdersStreamProvider);

    return AppScaffold(
      padded: false,
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: '$e'),
        data: (_) {
          if (order == null) return const _NotFoundView();
          return _Tracker(order: order);
        },
      ),
    );
  }
}

// ───────────────────────── Tracker ─────────────────────────

class _Tracker extends StatelessWidget {
  const _Tracker({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.xxxl),
      children: [
        _MapHeader(),
        Transform.translate(
          offset: const Offset(0, -20),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
            child: _StatusCard(order: order)
                .animate()
                .fadeIn(duration: 260.ms)
                .slideY(begin: 0.1, end: 0),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        _Steps(order: order),
        if (order.driverName != null) ...[
          const SizedBox(height: AppSizes.sm),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.pagePadding,
            ),
            child: _DriverCard(order: order),
          ),
        ],
        const SizedBox(height: AppSizes.md),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
          child: _PaymentRow(order: order),
        ),
      ],
    );
  }
}

// ───────────────────────── Map header ─────────────────────────

class _MapHeader extends StatelessWidget {
  const _MapHeader();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Container(
            color: AppColors.surfaceAlt,
            child: Center(
              child: Icon(
                Icons.map_rounded,
                size: 80,
                color: AppColors.border,
              ),
            ),
          ),
          Positioned(
            top: AppSizes.md + MediaQuery.of(context).padding.top / 2,
            left: AppSizes.md,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.userHome),
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(Icons.arrow_back_rounded,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Status card ─────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.order});
  final OrderSummary order;

  String _etaText() {
    if (order.orderStatus == OrderStatus.delivered) {
      return 'Delivered ${_timeAgo(order.deliveredAt ?? order.createdAt)}';
    }
    if (order.orderStatus == OrderStatus.cancelled) {
      return 'Cancelled ${_timeAgo(order.cancelledAt ?? order.createdAt)}';
    }
    if (order.etaMinutesMin != null && order.etaMinutesMax != null) {
      return 'ETA ${order.etaMinutesMin}–${order.etaMinutesMax} min';
    }
    return 'We\'ll keep you posted as it moves.';
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (order.orderStatus) {
      OrderStatus.placed => 'Order placed',
      OrderStatus.confirmed => 'Order confirmed',
      OrderStatus.preparing => 'Preparing your order',
      OrderStatus.dispatched => 'Out for delivery',
      OrderStatus.delivered => 'Order delivered 🎉',
      OrderStatus.cancelled => 'Order cancelled',
    };

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading1),
          const SizedBox(height: 2),
          Text(_etaText(),
              style: AppTextStyles.caption.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

// ───────────────────────── Timeline steps ─────────────────────────

class _Steps extends StatelessWidget {
  const _Steps({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    if (order.orderStatus == OrderStatus.cancelled) {
      return _CancelledBlock(order: order);
    }
    final active = order.orderStatus.stepIndex;
    final steps = <_StepItem>[
      _StepItem(
        icon: Icons.check_rounded,
        title: 'Order placed',
        subtitle: order.placedAt == null
            ? 'Your order has been placed'
            : '${_formatTime(order.placedAt!)} · Your order has been placed',
      ),
      _StepItem(
        icon: Icons.check_rounded,
        title: 'Order confirmed',
        subtitle: order.confirmedAt == null
            ? 'Awaiting restaurant confirmation'
            : '${_formatTime(order.confirmedAt!)} · Kitchen notified',
      ),
      _StepItem(
        icon: Icons.local_fire_department_rounded,
        title: 'Being prepared',
        subtitle: order.preparingAt == null
            ? 'Preparation pending'
            : '${_formatTime(order.preparingAt!)} · Freshly prepared for you',
      ),
      _StepItem(
        icon: Icons.delivery_dining_rounded,
        title: 'Out for delivery',
        subtitle: order.dispatchedAt == null
            ? 'On the way to your location'
            : '${_formatTime(order.dispatchedAt!)} · On the way',
      ),
      _StepItem(
        icon: Icons.check_circle_rounded,
        title: 'Delivered',
        subtitle: order.deliveredAt == null
            ? 'Enjoy your event!'
            : '${_formatTime(order.deliveredAt!)} · Delivered',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        0,
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          final isDone = i < active;
          final isActive = i == active;
          final isLast = i == steps.length - 1;
          return _StepRow(
            step: steps[i],
            state: isDone
                ? _StepState.done
                : isActive
                    ? _StepState.active
                    : _StepState.pending,
            isLast: isLast,
          );
        }),
      ),
    );
  }
}

enum _StepState { pending, active, done }

class _StepItem {
  const _StepItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.state,
    required this.isLast,
  });
  final _StepItem step;
  final _StepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.active => AppColors.primary,
      _StepState.pending => AppColors.border,
    };
    final titleColor = state == _StepState.pending
        ? AppColors.textMuted
        : AppColors.textPrimary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _Dot(color: color, active: state == _StepState.active),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        state == _StepState.done ? color : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: AppTextStyles.bodyBold
                          .copyWith(color: titleColor)),
                  const SizedBox(height: 2),
                  Text(step.subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        active ? Icons.local_fire_department_rounded : Icons.check_rounded,
        color: Colors.white,
        size: 14,
      ),
    )
        .animate(
          autoPlay: active,
          onPlay: (c) => active ? c.repeat(reverse: true) : null,
        )
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.08, 1.08),
          duration: 900.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _CancelledBlock extends StatelessWidget {
  const _CancelledBlock({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.primary),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                'This order was cancelled. If this was unexpected, contact support.',
                style: AppTextStyles.body.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Driver card ─────────────────────────

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final avatarBg = AppColors.fromHex(order.driverAvatarHex,
        fallback: AppColors.catBlueLt);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: avatarBg),
            alignment: Alignment.center,
            child: const Icon(Icons.delivery_dining_rounded,
                color: AppColors.info, size: 24),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.driverName ?? 'Driver assigned',
                    style: AppTextStyles.bodyBold),
                Text(
                  order.driverRating == null
                      ? 'Delivery partner'
                      : 'Delivery partner · ★ ${order.driverRating!.toStringAsFixed(1)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          _DriverAction(
            icon: Icons.call_rounded,
            onTap: () => HapticFeedback.selectionClick(),
          ),
          const SizedBox(width: AppSizes.xs),
          _DriverAction(
            icon: Icons.chat_rounded,
            onTap: () => HapticFeedback.selectionClick(),
          ),
        ],
      ),
    );
  }
}

class _DriverAction extends StatelessWidget {
  const _DriverAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.success, size: 20),
      ),
    );
  }
}

// ───────────────────────── Payment row ─────────────────────────

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total paid', style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  Formatters.currency(order.total),
                  style: AppTextStyles.heading1,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: order.paymentStatus == PaymentStatus.paid
                  ? AppColors.catGreenLt
                  : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            ),
            child: Text(
              order.paymentStatus.name.toUpperCase(),
              style: AppTextStyles.captionBold.copyWith(
                color: order.paymentStatus == PaymentStatus.paid
                    ? AppColors.success
                    : AppColors.warning,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Empty / error ─────────────────────────

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            Text('Order not found', style: AppTextStyles.heading2),
            const SizedBox(height: AppSizes.xs),
            Text(
              'This order may have been removed or doesn\'t belong to you.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton(
              onPressed: () => context.go(AppRoutes.myEvents),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xl,
                  vertical: AppSizes.md,
                ),
              ),
              child: const Text('Back to orders'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            Text('Couldn\'t load order', style: AppTextStyles.heading2),
            const SizedBox(height: AppSizes.xs),
            Text(message,
                style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final am = t.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $am';
}

String _timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  return Formatters.date(t);
}
