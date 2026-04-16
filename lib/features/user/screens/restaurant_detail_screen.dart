import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../shared/providers/favorites_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/qty_selector.dart';
import '../../../shared/widgets/veg_dot.dart';

class RestaurantDetailScreen extends ConsumerWidget {
  const RestaurantDetailScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(restaurantsProvider).valueOrNull ?? const [];
    final allItems =
        ref.watch(menuItemsProvider).valueOrNull ?? const <MenuItem>[];
    final categories =
        ref.watch(menuCategoriesProvider).valueOrNull ?? const <MenuCategory>[];
    final cartCount = ref.watch(cartCountProvider);
    final cartTotal = ref.watch(cartFoodTotalProvider);

    final restaurant = restaurants.firstWhere(
      (r) => r.id == restaurantId,
      orElse: () =>
          const Restaurant(id: '', name: 'Restaurant', deliveryCharge: 0),
    );

    final items = allItems.where((i) => i.restaurantId == restaurantId).toList();
    final catMap = {for (final c in categories) c.id: c};
    final grouped = <String, List<MenuItem>>{};
    for (final it in items) {
      grouped.putIfAbsent(it.categoryId, () => []).add(it);
    }
    final sortedCatIds = grouped.keys.toList()
      ..sort((a, b) =>
          (catMap[a]?.sortOrder ?? 99).compareTo(catMap[b]?.sortOrder ?? 99));

    return AppScaffold(
      padded: false,
      body: CustomScrollView(
        slivers: [
          _Hero(restaurant: restaurant),
          SliverToBoxAdapter(
            child: _InfoBar(restaurant: restaurant, itemCount: items.length),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.md)),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.xl),
                  child: Text('No items listed yet.'),
                ),
              ),
            )
          else
            for (final catId in sortedCatIds) ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryHeaderDelegate(
                  category: catMap[catId]?.name ?? 'Menu',
                  count: grouped[catId]!.length,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _MenuRow(item: grouped[catId]![i])
                      .animate(delay: (i * 40).ms)
                      .fadeIn(duration: 280.ms),
                  childCount: grouped[catId]!.length,
                ),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomBar: cartCount > 0 ? _CartBar(count: cartCount, total: cartTotal) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — collapsing image + back button + favorite heart
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: Padding(
        padding: const EdgeInsets.all(AppSizes.sm),
        child: _CircleIcon(
          icon: PhosphorIconsBold.arrowLeft,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.sm),
          child: _CircleIcon(
            icon: PhosphorIconsBold.heart,
            onTap: () {
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to favorites')),
              );
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (restaurant.logoUrl != null)
              CachedNetworkImage(
                imageUrl: restaurant.logoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallback(),
              )
            else
              _fallback(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC1A0A11)],
                ),
              ),
            ),
            Positioned(
              left: AppSizes.pagePadding,
              right: AppSizes.pagePadding,
              bottom: AppSizes.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                    ),
                    child: Text(
                      'PREMIUM CATERING',
                      style: AppTextStyles.overline.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    restaurant.name,
                    style: AppTextStyles.display.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info bar — rating + delivery + capacity
// ---------------------------------------------------------------------------

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.restaurant, required this.itemCount});
  final Restaurant restaurant;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.pagePadding),
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.star_rounded,
              iconColor: AppColors.success,
              value: '4.${(restaurant.name.length % 5) + 4}',
              label: '2.1k reviews',
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Stat(
              icon: PhosphorIconsBold.users,
              iconColor: AppColors.primary,
              value: '50+',
              label: 'guests',
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Stat(
              icon: PhosphorIconsBold.forkKnife,
              iconColor: AppColors.accentDark,
              value: '$itemCount',
              label: 'dishes',
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Stat(
              icon: PhosphorIconsBold.currencyInr,
              iconColor: AppColors.accentDark,
              value:
                  '${600 + (restaurant.name.length * 15)}',
              label: 'per plate',
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 2),
            Text(value,
                style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
          ],
        ),
        Text(label,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky category header
// ---------------------------------------------------------------------------

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CategoryHeaderDelegate({required this.category, required this.count});

  final String category;
  final int count;

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.pageBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(category, style: AppTextStyles.heading2),
          const SizedBox(width: AppSizes.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            ),
            child: Text('$count',
                style: AppTextStyles.captionBold
                    .copyWith(color: AppColors.accentDark)),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate old) =>
      old.category != category || old.count != count;
}

// ---------------------------------------------------------------------------
// Menu row
// ---------------------------------------------------------------------------

class _MenuRow extends ConsumerWidget {
  const _MenuRow({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((list) {
      final idx = list.indexWhere((c) => c.item.id == item.id);
      return idx == -1 ? 0 : list[idx].qty;
    }));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.xs,
        AppSizes.pagePadding,
        AppSizes.xs,
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
            _Thumb(item: item),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VegDot(isVeg: item.isVeg),
                      const SizedBox(width: AppSizes.xs + 2),
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTextStyles.bodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _FavoriteHeart(itemId: item.id),
                    ],
                  ),
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
                      Text(Formatters.currency(item.price),
                          style: AppTextStyles.price),
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

class _FavoriteHeart extends ConsumerWidget {
  const _FavoriteHeart({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(isFavoriteProvider(itemId));
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(favoritesProvider.notifier).toggle(itemId);
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          isFav ? PhosphorIconsFill.heart : PhosphorIconsBold.heart,
          color: isFav ? AppColors.primary : AppColors.textMuted,
          size: 18,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    final g = _gradientFor(item.name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: g,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: item.imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
                placeholder: (_, __) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Text(
        item.name[0].toUpperCase(),
        style: AppTextStyles.display.copyWith(
          color: Colors.white,
          fontSize: 30,
        ),
      ),
    );
  }

  static List<Color> _gradientFor(String name) {
    const palettes = <List<Color>>[
      [Color(0xFFE9C591), Color(0xFFD4A574)],
      [Color(0xFFF6CBD1), Color(0xFFE2A1AC)],
      [Color(0xFFC9DFC2), Color(0xFFA8C49E)],
      [Color(0xFFE6D3B3), Color(0xFFCBB38F)],
      [Color(0xFFF0B1A0), Color(0xFFD98471)],
      [Color(0xFFC6D8E8), Color(0xFF94B5CE)],
    ];
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return palettes[hash % palettes.length];
  }
}

// ---------------------------------------------------------------------------
// Cart bar at bottom
// ---------------------------------------------------------------------------

class _CartBar extends StatelessWidget {
  const _CartBar({required this.count, required this.total});
  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: PrimaryButton(
          label:
              '$count items · ${Formatters.currency(total)} — Review cart',
          icon: PhosphorIconsBold.shoppingBag,
          onPressed: () => context.push(AppRoutes.cart),
        ),
      ),
    );
  }
}
