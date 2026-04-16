import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/cart_item.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/qty_selector.dart';
import '../../../shared/widgets/veg_dot.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartFoodTotalProvider);
    final restaurants = ref.watch(restaurantsProvider).valueOrNull ?? [];

    final grouped = <String, List<CartItem>>{};
    for (final c in cart) {
      grouped.putIfAbsent(c.item.restaurantId, () => []).add(c);
    }

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: cart.isEmpty
          ? EmptyState(
              title: 'Cart is empty',
              message: 'Head back to the menu and pick your favourites.',
              icon: Icons.shopping_bag_outlined,
              actionLabel: 'Browse menu',
              onAction: () => context.pop(),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSizes.md),
                    child: Row(
                      children: [
                        const Icon(PhosphorIconsDuotone.storefront,
                            color: AppColors.accentDark, size: 18),
                        const SizedBox(width: AppSizes.xs),
                        Text(
                          restaurants
                                  .where((r) => r.id == entry.key)
                                  .map((r) => r.name)
                                  .firstOrNull ??
                              'Restaurant',
                          style: AppTextStyles.heading3,
                        ),
                      ],
                    ),
                  ),
                  for (final ci in entry.value) _CartRow(item: ci),
                  const Divider(height: 1),
                ],
              ],
            ),
      bottomBar: cart.isEmpty
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.all(AppSizes.lg),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Food subtotal',
                                  style: AppTextStyles.caption),
                              Text(Formatters.currency(total),
                                  style: AppTextStyles.heading2),
                            ],
                          ),
                        ),
                        PrimaryButton(
                          label: 'Checkout',
                          icon: PhosphorIconsBold.arrowRight,
                          expand: false,
                          onPressed: () =>
                              context.push(AppRoutes.checkout),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _CartRow extends ConsumerWidget {
  const _CartRow({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VegDot(isVeg: item.item.isVeg),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.item.name, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(
                  Formatters.currency(item.item.price),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          QtySelector(
            quantity: item.qty,
            onAdd: () => ref.read(cartProvider.notifier).add(item.item),
            onRemove: () =>
                ref.read(cartProvider.notifier).remove(item.item),
          ),
          const SizedBox(width: AppSizes.md),
          SizedBox(
            width: 60,
            child: Text(
              Formatters.currency(item.lineTotal),
              textAlign: TextAlign.right,
              style: AppTextStyles.price,
            ),
          ),
        ],
      ),
    );
  }
}
