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
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/menu_item_thumb.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/qty_selector.dart';
import '../../../shared/widgets/veg_dot.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(menuCategoriesProvider);
    final items = ref.watch(filteredMenuItemsProvider);
    final restaurants = ref.watch(restaurantsProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final cartCount = ref.watch(cartCountProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Build your menu'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Categories
          SizedBox(
            height: 56,
            child: cats.when(
              loading: () => const SizedBox(),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) => ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.pagePadding),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                      child: CategoryChip(
                        label: 'All',
                        selected: selectedCat == null,
                        onTap: () => ref
                            .read(selectedCategoryProvider.notifier)
                            .state = null,
                      ),
                    );
                  }
                  final c = list[i - 1];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                    child: CategoryChip(
                      label: c.name,
                      selected: selectedCat == c.id,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(selectedCategoryProvider.notifier)
                            .state = c.id;
                      },
                    ),
                  );
                },
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSizes.sm),
                itemCount: list.length + 1,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.when(
              loading: () => _loadingList(),
              error: (e, _) => Center(child: Text('$e')),
              data: (itemList) {
                if (itemList.isEmpty) {
                  return const EmptyState(
                    title: 'No items in this category',
                    message: 'Try another category',
                  );
                }
                final rMap = {
                  for (final r in restaurants.valueOrNull ?? <Restaurant>[])
                    r.id: r,
                };
                final cMap = {
                  for (final c in cats.valueOrNull ?? <MenuCategory>[]) c.id: c,
                };
                final grouped = <String, List<MenuItem>>{};
                for (final it in itemList) {
                  grouped.putIfAbsent(it.restaurantId, () => []).add(it);
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    for (final entry in grouped.entries)
                      _RestaurantGroup(
                        restaurant: rMap[entry.key],
                        items: entry.value,
                        categoryMap: cMap,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomBar: cartCount == 0 ? null : _CartBar(count: cartCount),
    );
  }

  Widget _loadingList() {
    return AppSkeleton(
      loading: true,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.md),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantGroup extends StatelessWidget {
  const _RestaurantGroup({
    required this.restaurant,
    required this.items,
    required this.categoryMap,
  });

  final Restaurant? restaurant;
  final List<MenuItem> items;
  final Map<String, MenuCategory> categoryMap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.xl,
            AppSizes.pagePadding,
            AppSizes.sm,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIconsDuotone.storefront,
                  color: AppColors.accentDark, size: 18),
              const SizedBox(width: AppSizes.xs),
              Text(
                restaurant?.name ?? 'Restaurant',
                style: AppTextStyles.bodyBold
                    .copyWith(color: AppColors.accentDark),
              ),
            ],
          ),
        ),
        for (int i = 0; i < items.length; i++)
          _MenuItemCard(item: items[i])
              .animate(delay: (60 * i).ms)
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.06, end: 0),
      ],
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  const _MenuItemCard({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty =
        ref.watch(cartProvider.select((list) {
      final idx = list.indexWhere((c) => c.item.id == item.id);
      return idx == -1 ? 0 : list[idx].qty;
    }));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MenuItemThumb(
              name: item.name,
              imageUrl: item.imageUrl,
              isVeg: item.isVeg,
              showVegDot: false, // shown next to the name already
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    VegDot(isVeg: item.isVeg),
                    const SizedBox(width: AppSizes.xs + 2),
                    Expanded(
                      child: Text(item.name,
                          style: AppTextStyles.bodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  if (item.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatters.currency(item.price),
                        style: AppTextStyles.price,
                      ),
                      QtySelector(
                        quantity: qty,
                        onAdd: () =>
                            ref.read(cartProvider.notifier).add(item),
                        onRemove: () =>
                            ref.read(cartProvider.notifier).remove(item),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CartBar extends ConsumerWidget {
  const _CartBar({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(cartFoodTotalProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: PrimaryButton(
          label: '$count items · ${Formatters.currency(total)} — Review cart',
          icon: PhosphorIconsBold.shoppingBag,
          onPressed: () => context.push(AppRoutes.cart),
        ),
      )
          .animate()
          .slideY(begin: 1, end: 0, duration: 300.ms, curve: Curves.easeOut)
          .fadeIn(),
    );
  }
}
