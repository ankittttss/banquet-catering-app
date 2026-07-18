import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/favorites_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/search_results_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/safe_net_image.dart';
import '../../../shared/widgets/selected_items_sheet.dart';
import '../widgets/reviews_section.dart';

class RestaurantDetailScreen extends ConsumerWidget {
  const RestaurantDetailScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve directly by id (ANY lifecycle state) so deep links, favorites
    // and search hits outside the nearby radius get an honest page instead
    // of a blank "Restaurant" shell.
    final byId = ref.watch(restaurantByIdProvider(restaurantId));
    final restaurant = byId.valueOrNull;

    if (restaurant == null) {
      if (byId.isLoading) {
        return const AppScaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }
      if (byId.hasError) {
        return AppScaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Couldn\'t load this restaurant',
                    style: AppTextStyles.heading2),
                const SizedBox(height: AppSizes.md),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(restaurantByIdProvider(restaurantId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      // Fetched fine, row simply doesn't exist anymore.
      return const _UnavailableView(name: null);
    }

    // Suspended / archived / draft — never orderable, don't render the menu.
    if (restaurant.status != RestaurantStatus.published) {
      return _UnavailableView(name: restaurant.name);
    }

    // Published — can it serve the customer's selected location?
    final coords = ref.watch(customerCoordsProvider);
    final serviceability = serviceabilityOf(
      restaurant,
      customerLat: coords.lat,
      customerLng: coords.lng,
    );
    final distanceKm = distanceToRestaurantKm(
      restaurant,
      customerLat: coords.lat,
      customerLng: coords.lng,
    );
    // Unknown range (no address yet) must not block — never punish missing
    // data; checkout re-verifies anyway.
    final orderable = serviceability != Serviceability.outOfRange;

    // Fetch menu items for THIS restaurant only — the catalog-wide provider
    // hits a 1000-row cap and misses most restaurants' menus.
    final items =
        ref.watch(restaurantMenuItemsProvider(restaurantId)).valueOrNull ??
            const <MenuItem>[];
    final categories =
        ref.watch(menuCategoriesProvider).valueOrNull ?? const <MenuCategory>[];
    final cartCount = ref.watch(cartCountProvider);
    // Guest-scaled total so the bar matches the cart's item total.
    final cartTotal = ref.watch(cartBilledFoodTotalProvider);

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
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _HeroSliver(restaurant: restaurant, ref: ref),
              SliverToBoxAdapter(child: _InfoBlock(restaurant: restaurant)),
              SliverToBoxAdapter(child: _StatsStrip(restaurant: restaurant)),
              if (!orderable)
                SliverToBoxAdapter(
                  child: _OutOfRangeBanner(distanceKm: distanceKm),
                ),
              // Offers strip removed for the MVP (no offers product); the
              // restaurant_offers table stays in the DB for later.
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.xl),
                    child: Center(child: Text('No items listed yet.')),
                  ),
                )
              else
                for (final catId in sortedCatIds) ...[
                  SliverToBoxAdapter(
                    child: _MenuCategoryHeader(
                      name: catMap[catId]?.name ?? 'Menu',
                    ),
                  ),
                  SliverList.builder(
                    itemCount: grouped[catId]!.length,
                    itemBuilder: (_, i) => _MenuItemRow(
                      item: grouped[catId]![i],
                      orderable: orderable,
                    ),
                  ),
                ],
              SliverToBoxAdapter(
                child: ReviewsSection(restaurantId: restaurantId),
              ),
              SliverToBoxAdapter(
                  child: SizedBox(height: cartCount > 0 ? 96 : AppSizes.xxl)),
            ],
          ),
          if (cartCount > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ViewCartBar(count: cartCount, total: cartTotal),
            ),
        ],
      ),
    );
  }
}

/// Full-page state for suspended / archived / deleted restaurants — replaces
/// the old blank "Restaurant" shell (which even let customers order).
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.storefront_rounded,
                    size: 36, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSizes.lg),
              Text(
                name == null
                    ? 'Restaurant not found'
                    : '$name is currently unavailable',
                style: AppTextStyles.heading2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                name == null
                    ? 'It may have been removed from Dawat.'
                    : 'This restaurant isn\'t taking orders right now. '
                        'Please check back later.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amber banner for published-but-too-far kitchens: browsable, not orderable.
class _OutOfRangeBanner extends StatelessWidget {
  const _OutOfRangeBanner({required this.distanceKm});
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.xs,
        AppSizes.pagePadding,
        AppSizes.xs,
      ),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_off_rounded,
              size: 18, color: AppColors.accentDark),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'Doesn\'t deliver to your selected location'
              '${distanceKm == null ? '' : ' — ${distanceKm!.toStringAsFixed(0)} km away'} '
              '(serves within ${kServiceRadiusKm.toStringAsFixed(0)} km). '
              'You can browse the menu, but ordering is disabled.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.accentDark, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Hero sliver ─────────────────────────

class _HeroSliver extends StatelessWidget {
  const _HeroSliver({required this.restaurant, required this.ref});
  final Restaurant restaurant;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isFav = ref.watch(isFavoriteProvider(restaurant.id));
    final bg = AppColors.fromHex(restaurant.heroBgHex,
        fallback: AppColors.primarySoft);
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      elevation: 0,
      leading: _CircleAction(
        icon: Icons.arrow_back_rounded,
        onTap: () => context.pop(),
      ),
      actions: [
        _CircleAction(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFav ? AppColors.primary : AppColors.textPrimary,
          onTap: () {
            HapticFeedback.selectionClick();
            ref.read(favoritesProvider.notifier).toggle(restaurant.id);
          },
        ),
        _CircleAction(
          icon: Icons.ios_share_rounded,
          onTap: () {
            HapticFeedback.selectionClick();
            Clipboard.setData(
              ClipboardData(
                text: 'Check out ${restaurant.name} on Dawat',
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link copied to clipboard'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(width: AppSizes.sm),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (restaurant.logoUrl != null)
              SafeNetImage(
                url: restaurant.logoUrl!,
                errorBuilder: (_) => _emoji(bg),
              )
            else
              _emoji(bg),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xDDFFFFFF),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emoji(Color bg) => Container(
        color: bg,
        alignment: Alignment.center,
        child: Text(
          restaurant.heroEmoji ?? '🍽️',
          style: const TextStyle(fontSize: 80),
        ),
      );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xs + 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Info block ─────────────────────────

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(restaurant.name, style: AppTextStyles.display),
          if (restaurant.cuisinesDisplay != null) ...[
            const SizedBox(height: 4),
            Text(restaurant.cuisinesDisplay!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Stats strip ─────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          _Stat(
            value: restaurant.rating == null
                ? '—'
                : '★ ${restaurant.rating!.toStringAsFixed(1)}',
            label: restaurant.ratingsCount == null
                ? 'rating'
                : '${_fmtCount(restaurant.ratingsCount!)} ratings',
            color: AppColors.success,
          ),
          const _Separator(),
          _Stat(
            value: restaurant.deliveryEta.isEmpty
                ? '—'
                : restaurant.deliveryEta.replaceAll(' min', ''),
            label: 'mins delivery',
          ),
          const _Separator(),
          _Stat(
            value: restaurant.pricePerPlate == null
                ? '—'
                : '₹${restaurant.pricePerPlate!.toStringAsFixed(0)}',
            label: 'per plate',
          ),
        ],
      ),
    );
  }

  String _fmtCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              color: color ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
}

// ───────────────────────── Menu list ─────────────────────────

class _MenuCategoryHeader extends StatelessWidget {
  const _MenuCategoryHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.lg,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      child: Text(name, style: AppTextStyles.heading1),
    );
  }
}

class _MenuItemRow extends ConsumerWidget {
  const _MenuItemRow({required this.item, required this.orderable});
  final MenuItem item;

  /// False when the restaurant can't serve the customer's location — the
  /// menu stays browsable but ADD is disabled.
  final bool orderable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineQty = _lineQty(ref, item);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VegDot(isVeg: item.isVeg),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  style: AppTextStyles.heading3,
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.currency(item.price),
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                ),
                if (item.description != null &&
                    item.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          _ThumbWithAdd(item: item, qty: lineQty, orderable: orderable),
        ],
      ),
    );
  }

  int _lineQty(WidgetRef ref, MenuItem item) {
    final cart = ref.watch(cartProvider);
    return cart
        .where((c) => c.item.id == item.id)
        .fold<int>(0, (s, c) => s + c.qty);
  }
}

class _ThumbWithAdd extends ConsumerWidget {
  const _ThumbWithAdd({
    required this.item,
    required this.qty,
    required this.orderable,
  });
  final MenuItem item;
  final int qty;
  final bool orderable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Container(
              width: 110,
              height: 90,
              color: AppColors.surfaceAlt,
              child: item.imageUrl != null
                  ? SafeNetImage(
                      url: item.imageUrl!,
                      errorBuilder: (_) => _imgFallback(),
                    )
                  : _imgFallback(),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 2,
            child: qty == 0
                ? _AddButton(
                    enabled: orderable,
                    onTap: () {
                      if (!orderable) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This restaurant doesn\'t deliver to your '
                              'selected location.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      HapticFeedback.selectionClick();
                      ref.read(cartProvider.notifier).add(item);
                    },
                  )
                // Removing stays allowed even when out of range — helps the
                // customer clean up a cart built from an old address.
                : _AddedBadge(
                    onRemove: () {
                      HapticFeedback.selectionClick();
                      ref.read(cartProvider.notifier).remove(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _imgFallback() => const ColoredBox(
        color: AppColors.surfaceAlt,
        child: Center(
          child: Icon(Icons.restaurant_rounded,
              color: AppColors.textMuted, size: 32),
        ),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, this.enabled = true});
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      shadowColor: Colors.black.withValues(alpha: 0.1),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            'ADD',
            style: AppTextStyles.captionBold.copyWith(
              color: enabled ? AppColors.success : AppColors.textMuted,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the numeric qty stepper. Banquet-catering semantic: the dish is
/// either on the menu for this event (one portion per guest, scaled by
/// headcount at checkout) or it isn't. Single-tap toggles.
class _AddedBadge extends StatelessWidget {
  const _AddedBadge({required this.onRemove});
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.success,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'ADDED',
                style: AppTextStyles.captionBold.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
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
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

// ───────────────────────── Floating cart bar ─────────────────────────

class _ViewCartBar extends StatelessWidget {
  const _ViewCartBar({required this.count, required this.total});
  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Material(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          child: InkWell(
            onTap: () => showSelectedItemsSheet(context),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: AppSizes.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      'View items · $count ${count == 1 ? 'item' : 'items'} · '
                      '${Formatters.currency(total)}',
                      style:
                          AppTextStyles.bodyBold.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_up_rounded,
                      color: Colors.white, size: 22),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.2, end: 0),
      ),
    );
  }
}
