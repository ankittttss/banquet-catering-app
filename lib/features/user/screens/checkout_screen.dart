import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/event_draft.dart';
import '../../../data/models/restaurant.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/charges_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/price_row.dart';
import '../../../shared/widgets/primary_button.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _placing = false;

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
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place booking: $e')),
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

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: charges.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (cfg) {
          // Delivery charge = sum of unique restaurants' delivery charges.
          final uniqueRestaurants = <String>{};
          for (final c in cart) {
            uniqueRestaurants.add(c.item.restaurantId);
          }
          final deliveryByRestaurant = <String, double>{};
          for (final id in uniqueRestaurants) {
            final r = restaurants.firstWhere(
              (x) => x.id == id,
              orElse: () =>
                  const Restaurant(id: '', name: '', deliveryCharge: 0),
            );
            deliveryByRestaurant[id] = r.deliveryCharge;
          }

          final totals = CheckoutTotals.compute(
            cart: cart,
            charges: cfg,
            deliveryByRestaurant: deliveryByRestaurant,
          );

          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              const SizedBox(height: AppSizes.md),
              _EventSummary(event: event),
              const SizedBox(height: AppSizes.lg),
              AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BILL SUMMARY', style: AppTextStyles.overline),
                    const SizedBox(height: AppSizes.sm),
                    PriceRow(
                      label: 'Food cost',
                      amount: totals.foodCost,
                      helper: '${cart.length} unique items',
                    ),
                    PriceRow(
                      label: 'Banquet charges',
                      amount: totals.banquetCharge,
                    ),
                    PriceRow(
                      label: 'Total delivery charge',
                      amount: totals.deliveryCharge,
                      helper: '${uniqueRestaurants.length} '
                          'restaurant${uniqueRestaurants.length == 1 ? '' : 's'}',
                    ),
                    PriceRow(
                      label: 'Buffet setup',
                      amount: totals.buffetSetup,
                    ),
                    PriceRow(
                      label: 'Service boys',
                      amount: totals.serviceBoyCost,
                    ),
                    PriceRow(
                      label: 'Water bottles',
                      amount: totals.waterBottleCost,
                    ),
                    PriceRow(
                      label: 'Platform fees',
                      amount: totals.platformFee,
                    ),
                    const Divider(height: AppSizes.xl),
                    PriceRow(
                      label: 'Total cart value',
                      amount: totals.subtotal,
                      emphasis: true,
                    ),
                    PriceRow(
                      label: 'GST ${cfg.gstPercent.toStringAsFixed(0)}%',
                      amount: totals.gst,
                    ),
                    const Divider(height: AppSizes.xl),
                    PriceRow(
                      label: 'Total payable',
                      amount: totals.total,
                      isTotal: true,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: 0.04, end: 0),
              const SizedBox(height: AppSizes.lg),
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsBold.info,
                        color: AppColors.accentDark, size: 20),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        'A team representative will call to confirm your booking.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accentDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xxl),
              PrimaryButton(
                label: 'Request Booking — ${Formatters.currency(totals.total)}',
                icon: PhosphorIconsBold.checkCircle,
                loading: _placing,
                onPressed: cart.isEmpty ? null : () => _placeOrder(totals),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.event});
  final EventDraft event;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      color: AppColors.primarySoft,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(
              PhosphorIconsDuotone.calendar,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.date == null
                      ? 'Date TBD'
                      : Formatters.date(event.date!),
                  style: AppTextStyles.heading2
                      .copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.session ?? "—"} · ${event.guestCount} guests',
                  style: AppTextStyles.body,
                ),
                if (event.location != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.location!,
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
    );
  }
}
