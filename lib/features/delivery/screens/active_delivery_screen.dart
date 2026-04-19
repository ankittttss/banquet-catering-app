import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/delivery_assignment.dart';
import '../../../shared/providers/delivery_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../widgets/map_placeholder.dart';

class ActiveDeliveryScreen extends ConsumerWidget {
  const ActiveDeliveryScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeDeliveryProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: active.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (a) {
          if (a == null) {
            return const Center(child: Text('No active delivery.'));
          }
          return _Body(a: a);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.a});
  final DeliveryAssignment a;

  @override
  Widget build(BuildContext context) {
    final pickedUp = a.status == DeliveryStatus.pickedUp;
    return Stack(
      children: [
        Column(
          children: [
            Stack(
              children: [
                MapPlaceholder(
                  pickupLabel: a.restaurantName,
                  dropLabel: a.dropAddress,
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: AppSizes.md,
                  child: _BackBtn(),
                ),
              ],
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSizes.radiusXl),
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const SizedBox(height: AppSizes.sm + 2),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusPill),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      _StatusStrip(a: a),
                      const SizedBox(height: AppSizes.sm),
                      _StepsCard(a: a, pickedUp: pickedUp),
                      const SizedBox(height: AppSizes.md),
                      _SectionTitle('CUSTOMER'),
                      _CustomerCard(a: a),
                      _SectionTitle('ORDER ITEMS'),
                      _OrderItemsCard(a: a),
                      const SizedBox(height: AppSizes.md),
                      _SlideAction(a: a, pickedUp: pickedUp),
                      const SizedBox(height: AppSizes.xl),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      elevation: 2,
      child: InkWell(
        onTap: () => context.pop(),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(PhosphorIconsBold.arrowLeft,
              color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.a});
  final DeliveryAssignment a;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding, AppSizes.sm, AppSizes.pagePadding, AppSizes.sm),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(a.status.label, style: AppTextStyles.heading2),
          ),
          if (a.etaMinutes != null)
            Text(
              'ETA ${a.etaMinutes} min',
              style: AppTextStyles.bodyBold
                  .copyWith(color: AppColors.success),
            ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.a, required this.pickedUp});
  final DeliveryAssignment a;
  final bool pickedUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePaddingSm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.sm),
        child: Column(
          children: [
            _StepRow(
              color: AppColors.accent,
              bg: AppColors.catGoldLt,
              icon: PhosphorIconsBold.storefront,
              title: a.restaurantName,
              subtitle: a.pickupAddress,
              actionLabel: pickedUp ? 'Done' : 'Picked up',
              actionColor: pickedUp
                  ? AppColors.textMuted
                  : AppColors.accent,
              actionBg: pickedUp
                  ? AppColors.surfaceAlt
                  : AppColors.catGoldLt,
              onAction: pickedUp
                  ? null
                  : () => context
                      .push(AppRoutes.deliveryPickupFor(a.id)),
            ),
            const Divider(height: 1, color: AppColors.divider),
            _StepRow(
              color: AppColors.primary,
              bg: AppColors.primarySoft,
              icon: PhosphorIconsBold.mapPin,
              title: a.dropAddress,
              subtitle: '${a.customerName} · ${a.customerPhone}',
              actionLabel: 'Deliver',
              actionColor:
                  pickedUp ? AppColors.success : AppColors.textMuted,
              actionBg: pickedUp
                  ? AppColors.catGreenLt
                  : AppColors.surfaceAlt,
              onAction: pickedUp
                  ? () => context
                      .push(AppRoutes.deliveryDeliverFor(a.id))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.color,
    required this.bg,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionColor,
    required this.actionBg,
    this.onAction,
  });
  final Color color;
  final Color bg;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color actionColor;
  final Color actionBg;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm + 2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Material(
            color: actionBg,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md, vertical: 6),
                child: Text(
                  actionLabel,
                  style: AppTextStyles.captionBold.copyWith(
                    color: actionColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      child: Text(
        text,
        style: AppTextStyles.captionBold.copyWith(
          letterSpacing: 1.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.a});
  final DeliveryAssignment a;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePaddingSm),
      child: AppCard(
        color: const Color(0xFFFDFBF9),
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: const Icon(PhosphorIconsFill.userCircle,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.customerName, style: AppTextStyles.bodyBold),
                  Text(
                    '${a.eventLabel} · ${a.guestCount} guests',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            _RoundBtn(
              color: AppColors.success,
              bg: AppColors.catGreenLt,
              icon: PhosphorIconsFill.phone,
              onTap: () {},
            ),
            const SizedBox(width: AppSizes.xs),
            _RoundBtn(
              color: AppColors.info,
              bg: AppColors.catBlueLt,
              icon: PhosphorIconsFill.chatCircleText,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({
    required this.color,
    required this.bg,
    required this.icon,
    required this.onTap,
  });
  final Color color;
  final Color bg;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.a});
  final DeliveryAssignment a;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePaddingSm),
      child: AppCard(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.restaurantName,
                          style: AppTextStyles.bodyBold),
                      Text('#${a.orderId} · ${a.itemCount} items',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            _Item(veg: true, name: 'Hyderabadi Veg Dum Biryani', qty: 2),
            _Item(veg: false, name: 'Chicken Dum Biryani', qty: 1),
            _Item(veg: true, name: 'Double Ka Meetha', qty: 2),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.veg, required this.name, required this.qty});
  final bool veg;
  final String name;
  final int qty;
  @override
  Widget build(BuildContext context) {
    final color = veg ? AppColors.veg : AppColors.nonVeg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Container(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(child: Text(name, style: AppTextStyles.body)),
          Text('×$qty', style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}

class _SlideAction extends StatelessWidget {
  const _SlideAction({required this.a, required this.pickedUp});
  final DeliveryAssignment a;
  final bool pickedUp;
  @override
  Widget build(BuildContext context) {
    final color = pickedUp ? AppColors.success : AppColors.accent;
    final label =
        pickedUp ? 'Swipe to confirm delivery →' : 'Swipe to confirm pickup →';
    final onTap = pickedUp
        ? () => context.push(AppRoutes.deliveryDeliverFor(a.id))
        : () => context.push(AppRoutes.deliveryPickupFor(a.id));
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePaddingSm),
      child: Material(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: SizedBox(
            height: 56,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyBold
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMd),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(PhosphorIconsBold.arrowRight,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
