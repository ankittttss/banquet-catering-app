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
import '../../../data/models/user_address.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/charges_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';

enum _PaymentMethod { upi, card, cod }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _placing = false;
  _PaymentMethod _payment = _PaymentMethod.upi;

  Future<void> _placeOrder(CheckoutTotals totals) async {
    setState(() => _placing = true);
    try {
      final userId = ref.read(currentUserIdProvider) ?? 'local-user';
      final draft = ref.read(eventDraftProvider);
      final cart = ref.read(cartProvider);
      final orderId = await ref.read(orderRepositoryProvider).placeOrder(
            userId: userId,
            event: draft,
            cart: cart,
            totals: totals,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.read(cartProvider.notifier).clear();
      ref.read(eventDraftProvider.notifier).reset();
      context.go('${AppRoutes.orderSuccess}?id=$orderId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charges = ref.watch(chargesConfigProvider);
    final cart = ref.watch(cartProvider);
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? <Restaurant>[];
    final event = ref.watch(eventDraftProvider);
    final address = ref.watch(defaultAddressProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: charges.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e),
        data: (cfg) {
          final totals = _totalsFor(cart, cfg, restaurants);
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  _Section(
                    title: 'Delivery address',
                    child: _AddressCard(address: address),
                  ),
                  _Section(
                    title: 'Event details',
                    child: _EventCard(event: event),
                  ),
                  _Section(
                    title: 'Payment method',
                    child: Column(
                      children: [
                        _PaymentOption(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'UPI / Google Pay',
                          helper: 'Pay securely via UPI',
                          selected: _payment == _PaymentMethod.upi,
                          onTap: () => setState(
                              () => _payment = _PaymentMethod.upi),
                        ),
                        _PaymentOption(
                          icon: Icons.credit_card_rounded,
                          label: 'Credit / Debit Card',
                          helper: 'Visa, Mastercard, RuPay',
                          selected: _payment == _PaymentMethod.card,
                          onTap: () => setState(
                              () => _payment = _PaymentMethod.card),
                        ),
                        _PaymentOption(
                          icon: Icons.payments_outlined,
                          label: 'Cash on Delivery',
                          helper: 'Pay when food arrives',
                          selected: _payment == _PaymentMethod.cod,
                          onTap: () => setState(
                              () => _payment = _PaymentMethod.cod),
                        ),
                      ],
                    ),
                  ),
                  _Section(
                    title: 'Bill summary',
                    child: _BillSummary(totals: totals, cart: cart),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PlaceOrderBar(
                  total: totals.total,
                  loading: _placing,
                  disabled: cart.isEmpty || address == null,
                  onPlace: () => _placeOrder(totals),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  CheckoutTotals _totalsFor(
    List<CartItem> cart,
    ChargesConfig charges,
    List<Restaurant> restaurants,
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
      charges: charges,
      deliveryByRestaurant: delivery,
    );
  }
}

// ───────────────────────── Section ─────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading3),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

// ───────────────────────── Address card ─────────────────────────

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});
  final UserAddress? address;

  @override
  Widget build(BuildContext context) {
    if (address == null) {
      return InkWell(
        onTap: () => context.push(AppRoutes.addresses),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            border: Border.all(color: AppColors.primary, width: 1.4),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_location_alt_outlined,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  'Add a delivery address to continue',
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.primary, width: 1.4),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.home_outlined,
              color: AppColors.primary, size: 22),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address!.label.label, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(
                  address!.fullAddress,
                  style: AppTextStyles.caption,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.push(AppRoutes.addresses),
            child: Padding(
              padding: const EdgeInsets.only(left: AppSizes.sm),
              child: Text(
                'Change',
                style: AppTextStyles.bodyBold
                    .copyWith(color: AppColors.primary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Event card ─────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final EventDraft event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Column(
        children: [
          _EventRow(
            icon: Icons.celebration_outlined,
            text: event.session == null
                ? 'Event type pending'
                : '${event.session} event',
          ),
          _EventRow(
            icon: Icons.groups_outlined,
            text: '${event.guestCount} guests',
          ),
          _EventRow(
            icon: Icons.calendar_today_outlined,
            text: event.date == null
                ? 'Date TBD'
                : Formatters.date(event.date!),
          ),
          if (event.startTime != null && event.endTime != null)
            _EventRow(
              icon: Icons.schedule_outlined,
              text:
                  '${_fmtTime(event.startTime!)} – ${_fmtTime(event.endTime!)}',
            ),
          if (event.location != null && event.location!.isNotEmpty)
            _EventRow(
              icon: Icons.place_outlined,
              text: event.location!,
            ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final am = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
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
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Payment options ─────────────────────────

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color:
                selected ? AppColors.primarySoft : AppColors.surface,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: AppSizes.md),
              Icon(icon,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 22),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.bodyBold),
                    Text(helper,
                        style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Bill summary ─────────────────────────

class _BillSummary extends StatelessWidget {
  const _BillSummary({required this.totals, required this.cart});
  final CheckoutTotals totals;
  final List<CartItem> cart;

  @override
  Widget build(BuildContext context) {
    final extras = totals.banquetCharge +
        totals.buffetSetup +
        totals.serviceBoyCost +
        totals.waterBottleCost;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Column(
        children: [
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
          _BillRow('Platform fee', Formatters.currency(totals.platformFee)),
          if (extras > 0)
            _BillRow('Event setup & service', Formatters.currency(extras)),
          _BillRow('GST & charges', Formatters.currency(totals.gst)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: Divider(color: AppColors.border, height: 1),
          ),
          _BillRow('To pay', Formatters.currency(totals.total), bold: true),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms);
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow(
    this.label,
    this.value, {
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = (bold ? AppTextStyles.bodyBold : AppTextStyles.body)
        .copyWith(fontSize: bold ? 15 : 13);
    final valueStyle = style.copyWith(
      color: valueColor ?? AppColors.textPrimary,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

// ───────────────────────── Place order bar ─────────────────────────

class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({
    required this.total,
    required this.loading,
    required this.disabled,
    required this.onPlace,
  });

  final double total;
  final bool loading;
  final bool disabled;
  final VoidCallback onPlace;

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
                    style: AppTextStyles.display.copyWith(
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text('Total amount',
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            FilledButton(
              onPressed: disabled || loading ? null : onPlace,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xl,
                  vertical: AppSizes.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Place order',
                      style: AppTextStyles.buttonLabel
                          .copyWith(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
