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
import '../../../data/models/cart_item.dart';
import '../../../data/models/charges_config.dart';
import '../../../data/models/checkout_totals.dart';
import '../../../data/models/event_draft.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/charges_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/user_bottom_nav.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];
    final charges = ref.watch(chargesConfigProvider);
    final event = ref.watch(eventDraftProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Cart'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.userHome),
        ),
      ),
      bottomBar: const UserBottomNav(active: UserNavTab.cart),
      body: cart.isEmpty
          ? const _EmptyCart()
          : _CartBody(
              cart: cart,
              restaurants: restaurants,
              charges: charges,
              event: event,
            ),
    );
  }
}

class _CartBody extends ConsumerWidget {
  const _CartBody({
    required this.cart,
    required this.restaurants,
    required this.charges,
    required this.event,
  });

  final List<CartItem> cart;
  final List<Restaurant> restaurants;
  final AsyncValue<ChargesConfig> charges;
  final EventDraft event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group cart lines by restaurant id.
    final byRestaurant = <String, List<CartItem>>{};
    for (final c in cart) {
      byRestaurant.putIfAbsent(c.item.restaurantId, () => []).add(c);
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            for (final entry in byRestaurant.entries)
              _RestaurantGroup(
                restaurant: restaurants.firstWhere(
                  (r) => r.id == entry.key,
                  orElse: () => const Restaurant(
                      id: '', name: 'Restaurant', deliveryCharge: 0),
                ),
                lines: entry.value,
              ),
            _EventDetailsBlock(event: event),
            charges.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSizes.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                child: Text('Could not load charges: $e',
                    style: AppTextStyles.caption),
              ),
              data: (cfg) => _BillDetails(
                cart: cart,
                charges: cfg,
                restaurants: restaurants,
                event: event,
              ),
            ),
          ],
        ),
        charges.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (cfg) {
            final totals = _totalsFor(
              cart,
              cfg,
              restaurants,
              event.guestCount,
              event.effectiveServiceBoyCount,
            );
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CheckoutBar(total: totals.total),
            );
          },
        ),
      ],
    );
  }

  CheckoutTotals _totalsFor(
    List<CartItem> cart,
    ChargesConfig cfg,
    List<Restaurant> restaurants,
    int guestCount,
    int serviceBoyCount,
  ) {
    final uniq = cart.map((c) => c.item.restaurantId).toSet();
    final delivery = <String, double>{};
    for (final id in uniq) {
      delivery[id] = restaurants
          .firstWhere(
            (r) => r.id == id,
            orElse: () =>
                const Restaurant(id: '', name: '', deliveryCharge: 0),
          )
          .deliveryCharge;
    }
    return CheckoutTotals.compute(
      cart: cart,
      charges: cfg,
      deliveryByRestaurant: delivery,
      guestCount: guestCount,
      serviceBoyCount: serviceBoyCount,
    );
  }
}

// ───────────────────────── Restaurant group ─────────────────────────

class _RestaurantGroup extends ConsumerWidget {
  const _RestaurantGroup({required this.restaurant, required this.lines});
  final Restaurant restaurant;
  final List<CartItem> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = AppColors.fromHex(restaurant.heroBgHex,
        fallback: AppColors.primarySoft);
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  restaurant.heroEmoji ?? '🍽️',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurant.name, style: AppTextStyles.heading3),
                    if (restaurant.deliveryEta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${restaurant.deliveryEta} · ${restaurant.cuisinesDisplay ?? ''}'
                            .trim(),
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final line in lines) _CartLineRow(line: line),
      ],
    );
  }
}

class _CartLineRow extends ConsumerWidget {
  const _CartLineRow({required this.line});
  final CartItem line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestCount = ref.watch(eventDraftProvider).guestCount;
    final billed = line.qty * guestCount;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _VegDot(isVeg: line.item.isVeg),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.item.name, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(
                  '${line.qty} per guest  ·  $billed portions for $guestCount guests',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          _QtyControl(
            qty: line.qty,
            onMinus: () => ref
                .read(cartProvider.notifier)
                .bumpLine(line.signature, -1),
            onPlus: () => ref
                .read(cartProvider.notifier)
                .bumpLine(line.signature, 1),
          ),
          const SizedBox(width: AppSizes.md),
          SizedBox(
            width: 72,
            child: Text(
              Formatters.currency(line.billedLineTotal(guestCount)),
              style: AppTextStyles.bodyBold,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  const _QtyControl({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        children: [
          _StepCell(
            icon: Icons.remove_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              onMinus();
            },
          ),
          Container(
            width: 32,
            height: 30,
            color: AppColors.surfaceAlt,
            alignment: Alignment.center,
            child: Text(
              '$qty',
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.success,
                fontSize: 13,
              ),
            ),
          ),
          _StepCell(
            icon: Icons.add_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              onPlus();
            },
          ),
        ],
      ),
    );
  }
}

class _StepCell extends StatelessWidget {
  const _StepCell({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 32,
        height: 30,
        child: Icon(icon, color: AppColors.success, size: 18),
      ),
    );
  }
}

class _VegDot extends StatelessWidget {
  const _VegDot({required this.isVeg});
  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.veg : AppColors.nonVeg;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

// ───────────────────────── Event details ─────────────────────────

class _EventDetailsBlock extends StatelessWidget {
  const _EventDetailsBlock({required this.event});
  final EventDraft event;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      margin: const EdgeInsets.only(top: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎉 Event details', style: AppTextStyles.heading3),
          const SizedBox(height: AppSizes.sm),
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Column(
              children: [
                _EventRow(
                  icon: Icons.celebration_outlined,
                  text: event.session == null
                      ? 'Tap to set event type'
                      : '${event.session} event',
                ),
                _EventRow(
                  icon: Icons.groups_outlined,
                  text: '${event.guestCount} Guests',
                ),
                _EventRow(
                  icon: Icons.calendar_today_outlined,
                  text: event.date == null
                      ? 'Pick a date'
                      : Formatters.date(event.date!),
                ),
                if (event.location != null && event.location!.isNotEmpty)
                  _EventRow(
                    icon: Icons.place_outlined,
                    text: event.location!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          InkWell(
            onTap: () => context.push(AppRoutes.eventDetails),
            child: Text(
              'Edit event details →',
              style: AppTextStyles.bodyBold
                  .copyWith(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Bill details ─────────────────────────

class _BillDetails extends ConsumerWidget {
  const _BillDetails({
    required this.cart,
    required this.charges,
    required this.restaurants,
    required this.event,
  });
  final List<CartItem> cart;
  final ChargesConfig charges;
  final List<Restaurant> restaurants;
  final EventDraft event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uniq = cart.map((c) => c.item.restaurantId).toSet();
    final delivery = <String, double>{};
    for (final id in uniq) {
      delivery[id] = restaurants
          .firstWhere(
            (r) => r.id == id,
            orElse: () =>
                const Restaurant(id: '', name: '', deliveryCharge: 0),
          )
          .deliveryCharge;
    }
    final totals = CheckoutTotals.compute(
      cart: cart,
      charges: charges,
      deliveryByRestaurant: delivery,
      guestCount: event.guestCount,
      serviceBoyCount: event.effectiveServiceBoyCount,
    );

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill details', style: AppTextStyles.heading3),
          const SizedBox(height: AppSizes.sm),
          _BillRow('Item total', Formatters.currency(totals.foodCost)),
          _BillRow(
            'Delivery fee',
            totals.deliveryCharge == 0
                ? 'FREE'
                : Formatters.currency(totals.deliveryCharge),
            valueColor: totals.deliveryCharge == 0
                ? AppColors.success
                : AppColors.textPrimary,
          ),
          if (totals.banquetCharge > 0)
            _BillRow(
                'Banquet charge', Formatters.currency(totals.banquetCharge)),
          if (totals.buffetSetup > 0)
            _BillRow(
                'Buffet setup', Formatters.currency(totals.buffetSetup)),
          if (totals.waterBottleCost > 0)
            _BillRow(
                'Water bottles', Formatters.currency(totals.waterBottleCost)),
          _ServiceBoyRow(
            count: totals.serviceBoyCount,
            unitCost: totals.serviceBoyUnitCost,
            lineTotal: totals.serviceBoyCost,
            minimum: event.suggestedServiceBoys,
            guests: event.guestCount,
            onMinus: () =>
                ref.read(eventDraftProvider.notifier).bumpServiceBoyCount(-1),
            onPlus: () =>
                ref.read(eventDraftProvider.notifier).bumpServiceBoyCount(1),
          ),
          _BillRow('Platform fee', Formatters.currency(totals.platformFee)),
          _BillRow(
            'GST (${charges.gstPercent.toStringAsFixed(charges.gstPercent.truncateToDouble() == charges.gstPercent ? 0 : 1)}%)',
            Formatters.currency(totals.gst),
          ),
          _BillRow(
            'Service tax (${charges.serviceTaxPercent.toStringAsFixed(charges.serviceTaxPercent.truncateToDouble() == charges.serviceTaxPercent ? 0 : 1)}%)',
            Formatters.currency(totals.serviceTax),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: DashedDivider(),
          ),
          _BillRow(
            'To pay',
            Formatters.currency(totals.total),
            bold: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms);
  }
}

class _ServiceBoyRow extends StatelessWidget {
  const _ServiceBoyRow({
    required this.count,
    required this.unitCost,
    required this.lineTotal,
    required this.minimum,
    required this.guests,
    required this.onMinus,
    required this.onPlus,
  });
  final int count;
  final double unitCost;
  final double lineTotal;
  final int minimum;
  final int guests;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Service boys ($count × ${Formatters.currency(unitCost)})',
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ),
              _SmallStepper(
                value: count,
                minusEnabled: count > minimum,
                onMinus: onMinus,
                onPlus: onPlus,
              ),
              const SizedBox(width: AppSizes.md),
              SizedBox(
                width: 72,
                child: Text(
                  Formatters.currency(lineTotal),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Recommended minimum: $minimum service boys based on $guests guests',
              style: AppTextStyles.caption.copyWith(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallStepper extends StatelessWidget {
  const _SmallStepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.minusEnabled = true,
  });
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool minusEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        children: [
          _StepperCell(
            icon: Icons.remove_rounded,
            enabled: minusEnabled,
            onTap: () {
              HapticFeedback.selectionClick();
              onMinus();
            },
          ),
          Container(
            width: 28,
            height: 26,
            color: AppColors.surfaceAlt,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.success,
                fontSize: 12,
              ),
            ),
          ),
          _StepperCell(
            icon: Icons.add_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              onPlus();
            },
          ),
        ],
      ),
    );
  }
}

class _StepperCell extends StatelessWidget {
  const _StepperCell({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 28,
        height: 26,
        child: Icon(
          icon,
          color: enabled ? AppColors.success : AppColors.textMuted,
          size: 16,
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow(
    this.label,
    this.value, {
    this.valueColor,
    this.bold = false,
    this.helper,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final labelStyle = (bold ? AppTextStyles.bodyBold : AppTextStyles.body)
        .copyWith(fontSize: bold ? 15 : 13);
    final valueStyle = (bold ? AppTextStyles.bodyBold : AppTextStyles.body)
        .copyWith(
      color: valueColor ?? AppColors.textPrimary,
      fontSize: bold ? 15 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              Text(value, style: valueStyle),
            ],
          ),
          if (helper != null)
            Text(helper!,
                style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        const dash = 4.0;
        const gap = 4.0;
        final n = (c.maxWidth / (dash + gap)).floor();
        return Row(
          children: List.generate(
            n,
            (_) => Container(
              width: dash,
              height: 1,
              color: AppColors.border,
              margin: const EdgeInsets.only(right: gap),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── Bottom checkout bar ─────────────────────────

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.total});
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Formatters.currency(total),
                    style: AppTextStyles.display
                        .copyWith(fontSize: 20, color: AppColors.textPrimary),
                  ),
                  Text('Incl. all taxes',
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => context.push(AppRoutes.checkout),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xl,
                  vertical: AppSizes.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Proceed to checkout',
                    style: AppTextStyles.buttonLabel
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Empty state ─────────────────────────

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: AppSizes.lg),
            Text('Your cart is empty', style: AppTextStyles.heading1),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Add items from a restaurant to get started.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.userHome),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Browse restaurants'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xl,
                  vertical: AppSizes.md,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
