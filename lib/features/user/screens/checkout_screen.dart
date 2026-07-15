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
import '../../../data/models/venue_type.dart';
import '../../../shared/providers/addon_providers.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/charges_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/service_tax_tile.dart';

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
    // Gate: the customer must have a complete profile (name + phone) before
    // an order can be placed. Send them to profile completion if not.
    final profile = await ref.read(currentProfileProvider.future);
    if (!mounted) return;
    if (profile == null || !profile.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete your profile (name & phone) before ordering.',
          ),
        ),
      );
      context.push(AppRoutes.editProfile);
      return;
    }

    final draft = ref.read(eventDraftProvider);
    final address = ref.read(defaultAddressProvider);

    // Gate: the event must actually be planned before an order is placed.
    // Otherwise the checkout would fabricate a nameless event with a default
    // date/time (the customer never filled anything in). Require the core
    // details the "Plan your event" screen collects — a name and a date —
    // and route the customer there to complete them if they're missing.
    final eventName = draft.eventName?.trim() ?? '';
    if (eventName.isEmpty || draft.date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add your event details (name & date) before placing the order.',
          ),
        ),
      );
      context.push(AppRoutes.eventDetails);
      return;
    }

    // Backfill only the NOT-NULL-but-UI-optional scheduling fields (session /
    // start / end time) and resolve the delivery location from the saved
    // address when the draft carries none. Name and date are guaranteed above.
    final filled = _ensureDraftComplete(draft, address?.fullAddress);
    if (filled == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please add a delivery address before placing the order.'),
        ),
      );
      return;
    }

    setState(() => _placing = true);
    try {
      final userId = ref.read(currentUserIdProvider) ?? 'local-user';
      final cart = ref.read(cartProvider);
      final orderId = await ref.read(orderRepositoryProvider).placeOrder(
            userId: userId,
            event: filled,
            cart: cart,
            totals: totals,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ref.read(cartProvider.notifier).clear();
      ref.read(eventDraftProvider.notifier).reset();
      context.go('${AppRoutes.orderSuccess}?id=$orderId');
    } catch (e, st) {
      debugPrint('placeOrder failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place order: ${_friendlyError(e)}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// Fills in reasonable defaults for any missing event fields so the insert
  /// always has a valid payload. Returns null only when we can't infer a
  /// delivery location (no saved address + empty draft).
  EventDraft? _ensureDraftComplete(EventDraft d, String? fallbackLocation) {
    final location = (d.location != null && d.location!.trim().isNotEmpty)
        ? d.location
        : fallbackLocation;
    if (location == null || location.trim().isEmpty) return null;

    final now = DateTime.now();
    final date = d.date ?? now.add(const Duration(days: 3));
    final session = d.session ?? 'Dinner';
    final start =
        d.startTime ?? DateTime(date.year, date.month, date.day, 19, 0);
    final end = d.endTime ?? DateTime(date.year, date.month, date.day, 22, 0);
    final guests = d.guestCount > 0 ? d.guestCount : 50;

    return d.copyWith(
      date: date,
      location: location,
      session: session,
      startTime: start,
      endTime: end,
      guestCount: guests,
    );
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    // Postgrest errors ship with message/hint/details; pull the first line.
    final firstLine = s.split('\n').first;
    if (firstLine.length > 140) return '${firstLine.substring(0, 140)}…';
    return firstLine;
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.cart),
        ),
      ),
      body: charges.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e),
        data: (cfg) {
          final includeServiceTax = ref.watch(includeServiceTaxProvider);
          final addonsTotal = ref.watch(addonsTotalProvider);
          final totals = _totalsFor(
            cart,
            cfg,
            restaurants,
            event.guestCount,
            event.effectiveServiceBoyCount,
            includeServiceTax,
            event.venueType,
            addonsTotal,
          );
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
                    action: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.push(AppRoutes.eventDetails);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: AppColors.primarySoft,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusPill),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: Text(
                        'Edit',
                        style: AppTextStyles.captionBold
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
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
                          onTap: () =>
                              setState(() => _payment = _PaymentMethod.upi),
                        ),
                        _PaymentOption(
                          icon: Icons.credit_card_rounded,
                          label: 'Credit / Debit Card',
                          helper: 'Visa, Mastercard, RuPay',
                          selected: _payment == _PaymentMethod.card,
                          onTap: () =>
                              setState(() => _payment = _PaymentMethod.card),
                        ),
                        _PaymentOption(
                          icon: Icons.payments_outlined,
                          label: 'Cash on Delivery',
                          helper: 'Pay when food arrives',
                          selected: _payment == _PaymentMethod.cod,
                          onTap: () =>
                              setState(() => _payment = _PaymentMethod.cod),
                        ),
                      ],
                    ),
                  ),
                  _Section(
                    title: 'Bill summary',
                    child: _BillSummary(
                      totals: totals,
                      cart: cart,
                      charges: cfg,
                      minimumServiceBoys: event.suggestedServiceBoys,
                      guests: event.guestCount,
                      includeServiceTax: includeServiceTax,
                      onServiceTaxChanged: (bool v) => ref
                          .read(includeServiceTaxProvider.notifier)
                          .state = v,
                      onMinusBoy: () => ref
                          .read(eventDraftProvider.notifier)
                          .bumpServiceBoyCount(-1),
                      onPlusBoy: () => ref
                          .read(eventDraftProvider.notifier)
                          .bumpServiceBoyCount(1),
                    ),
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
    int guestCount,
    int serviceBoyCount,
    bool includeServiceTax,
    VenueType? venueType,
    double addonsTotal,
  ) {
    final uniq = cart.map((c) => c.item.restaurantId).toSet();
    final delivery = <String, double>{};
    for (final id in uniq) {
      delivery[id] = restaurants
          .firstWhere(
            (r) => r.id == id,
            orElse: () => const Restaurant(id: '', name: '', deliveryCharge: 0),
          )
          .deliveryCharge;
    }
    return CheckoutTotals.compute(
      cart: cart,
      charges: charges,
      deliveryByRestaurant: delivery,
      guestCount: guestCount,
      serviceBoyCount: serviceBoyCount,
      includeServiceTax: includeServiceTax,
      venueType: venueType,
      addonsTotal: addonsTotal,
    );
  }
}

// ───────────────────────── Section ─────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});
  final String title;
  final Widget child;

  /// Optional trailing widget on the header row (e.g. an "Edit" pill).
  final Widget? action;

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
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.heading3)),
              if (action != null) action!,
            ],
          ),
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
                  style:
                      AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
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
          const Icon(Icons.home_outlined, color: AppColors.primary, size: 22),
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

  String? _venueLabel() {
    if (event.banquetVenueName != null) return event.banquetVenueName;
    if (event.venueType == VenueType.privateProperty) {
      return 'Private property';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final occasion = event.eventName ??
        (event.session == null ? 'Not set yet' : '${event.session} event');
    final venue = _venueLabel();
    final time = (event.startTime != null && event.endTime != null)
        ? '${_fmtTime(event.startTime!)} – ${_fmtTime(event.endTime!)}'
        : null;
    final dateLabel = event.date == null
        ? 'Date TBD'
        : (time == null
            ? Formatters.date(event.date!)
            : '${Formatters.date(event.date!)} · $time');

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.sm,
        AppSizes.md,
        AppSizes.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          _EventRow(
            icon: Icons.celebration_outlined,
            label: 'Occasion',
            value: occasion,
          ),
          _EventRow(
            icon: Icons.groups_outlined,
            label: 'Guests',
            value: '${event.guestCount} guests',
          ),
          _EventRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date & time',
            value: dateLabel,
          ),
          if (venue != null)
            _EventRow(
              icon: Icons.apartment_outlined,
              label: 'Venue',
              value: venue,
            ),
          if (event.location != null && event.location!.isNotEmpty)
            _EventRow(
              icon: Icons.place_outlined,
              label: 'Location',
              value: event.location!,
              maxLines: 2,
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
  const _EventRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13.5),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
            color: selected ? AppColors.primarySoft : AppColors.surface,
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
                  color: selected ? AppColors.primary : AppColors.textSecondary,
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
  const _BillSummary({
    required this.totals,
    required this.cart,
    required this.charges,
    required this.minimumServiceBoys,
    required this.guests,
    required this.includeServiceTax,
    required this.onServiceTaxChanged,
    required this.onMinusBoy,
    required this.onPlusBoy,
  });
  final CheckoutTotals totals;
  final List<CartItem> cart;
  final ChargesConfig charges;
  final int minimumServiceBoys;
  final int guests;
  final bool includeServiceTax;
  final ValueChanged<bool> onServiceTaxChanged;
  final VoidCallback onMinusBoy;
  final VoidCallback onPlusBoy;

  String _pct(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

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
            _BillRow('Buffet setup', Formatters.currency(totals.buffetSetup)),
          if (totals.waterBottleCost > 0)
            _BillRow(
                'Water bottles', Formatters.currency(totals.waterBottleCost)),
          if (totals.setupEquipment > 0)
            _BillRow('Setup & equipment',
                Formatters.currency(totals.setupEquipment)),
          _CheckoutServiceBoyRow(
            count: totals.serviceBoyCount,
            unitCost: totals.serviceBoyUnitCost,
            lineTotal: totals.serviceBoyCost,
            minimum: minimumServiceBoys,
            guests: guests,
            onMinus: onMinusBoy,
            onPlus: onPlusBoy,
          ),
          _BillRow('Platform fee', Formatters.currency(totals.platformFee)),
          _BillRow(
            'GST (${_pct(charges.gstPercent)}%)',
            Formatters.currency(totals.gst),
          ),
          ServiceTaxTile(
            percent: charges.serviceTaxPercent,
            amount: totals.subtotal * (charges.serviceTaxPercent / 100),
            included: includeServiceTax,
            onChanged: onServiceTaxChanged,
          ),
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

class _CheckoutServiceBoyRow extends StatelessWidget {
  const _CheckoutServiceBoyRow({
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
    final labelStyle = AppTextStyles.body.copyWith(fontSize: 13);
    final valueStyle = AppTextStyles.body.copyWith(
      color: AppColors.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
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
                  style: labelStyle,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: count > minimum
                          ? () {
                              HapticFeedback.selectionClick();
                              onMinus();
                            }
                          : null,
                      child: SizedBox(
                        width: 28,
                        height: 26,
                        child: Icon(
                          Icons.remove_rounded,
                          color: count > minimum
                              ? AppColors.success
                              : AppColors.textMuted,
                          size: 16,
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 26,
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.success,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onPlus();
                      },
                      child: const SizedBox(
                        width: 28,
                        height: 26,
                        child: Icon(Icons.add_rounded,
                            color: AppColors.success, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              SizedBox(
                width: 72,
                child: Text(
                  Formatters.currency(lineTotal),
                  style: valueStyle,
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
