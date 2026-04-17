import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/search_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/safe_net_image.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String v) => setState(() => _query = v);

  void _submit(String v) {
    final q = v.trim();
    if (q.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(q);
  }

  void _runQuery(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    _setQuery(q);
    _submit(q);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: false,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: _SearchField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _setQuery,
          onSubmitted: _submit,
          onClear: () {
            _ctrl.clear();
            _setQuery('');
          },
        ),
      ),
      body: _query.isEmpty
          ? _EmptyQueryView(onRunQuery: _runQuery)
          : _ResultsView(query: _query),
    );
  }
}

// ───────────────────────── Search field ─────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.pagePadding),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 20, color: AppColors.textMuted),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search caterers, cuisines…',
                  hintStyle:
                      AppTextStyles.body.copyWith(color: AppColors.textMuted),
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
            if (controller.text.isNotEmpty)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(100),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Empty (recent + trending) ─────────────────────────

class _EmptyQueryView extends ConsumerWidget {
  const _EmptyQueryView({required this.onRunQuery});
  final ValueChanged<String> onRunQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    final trending = ref.watch(trendingSearchesProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.xxxl),
      children: [
        recent.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.pagePadding,
                    AppSizes.md,
                    AppSizes.pagePadding,
                    AppSizes.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent searches',
                        style: AppTextStyles.captionBold
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      InkWell(
                        onTap: () => ref
                            .read(recentSearchesProvider.notifier)
                            .clear(),
                        child: Text(
                          'Clear',
                          style: AppTextStyles.captionBold
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final q in list)
                  _RecentRow(
                    label: q,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onRunQuery(q);
                    },
                    onRemove: () => ref
                        .read(recentSearchesProvider.notifier)
                        .remove(q),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSizes.md),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.sm,
          ),
          child: Text(
            'Trending now',
            style: AppTextStyles.captionBold
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pagePadding,
          ),
          child: trending.when(
            loading: () => const _TrendingSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) => Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final t in list)
                  _TrendingChip(
                    emoji: t.emoji,
                    label: t.label,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onRunQuery(t.label);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.sm + 4,
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded,
                color: AppColors.textMuted, size: 20),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(label, style: AppTextStyles.body),
            ),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(100),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingChip extends StatelessWidget {
  const _TrendingChip({
    required this.label,
    required this.onTap,
    this.emoji,
  });
  final String label;
  final String? emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingSkeleton extends StatelessWidget {
  const _TrendingSkeleton();
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSizes.sm,
        runSpacing: AppSizes.sm,
        children: List.generate(
          6,
          (_) => Container(
            width: 90,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            ),
          ),
        ),
      );
}

// ───────────────────────── Results ─────────────────────────

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.toLowerCase();
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];
    final items =
        ref.watch(menuItemsProvider).valueOrNull ?? const <MenuItem>[];

    final matchingRestaurants = restaurants
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            (r.cuisinesDisplay?.toLowerCase().contains(q) ?? false))
        .toList();

    final matchingItems = items
        .where((i) =>
            i.name.toLowerCase().contains(q) ||
            (i.description?.toLowerCase().contains(q) ?? false))
        .toList();

    if (matchingRestaurants.isEmpty && matchingItems.isEmpty) {
      return _NoResultsView(query: query);
    }

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSizes.md,
        bottom: AppSizes.xxxl,
      ),
      children: [
        if (matchingRestaurants.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.sm,
              AppSizes.pagePadding,
              AppSizes.sm,
            ),
            child: Text(
              'Restaurants (${matchingRestaurants.length})',
              style: AppTextStyles.captionBold
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          for (final r in matchingRestaurants)
            _RestaurantResultRow(restaurant: r),
        ],
        if (matchingItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.lg,
              AppSizes.pagePadding,
              AppSizes.sm,
            ),
            child: Text(
              'Dishes (${matchingItems.length})',
              style: AppTextStyles.captionBold
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          for (final m in matchingItems.take(20))
            _DishResultRow(item: m, restaurants: restaurants),
        ],
      ],
    );
  }
}

class _RestaurantResultRow extends StatelessWidget {
  const _RestaurantResultRow({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.fromHex(restaurant.heroBgHex,
        fallback: AppColors.primarySoft);
    return InkWell(
      onTap: () => context.push(AppRoutes.restaurantDetailFor(restaurant.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.sm,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: SizedBox(
                width: 60,
                height: 60,
                child: restaurant.logoUrl != null
                    ? SafeNetImage(
                        url: restaurant.logoUrl!,
                        errorBuilder: (_) => _fallback(bg),
                      )
                    : _fallback(bg),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant.name, style: AppTextStyles.bodyBold),
                  if (restaurant.cuisinesDisplay != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      restaurant.cuisinesDisplay!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (restaurant.rating != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      restaurant.rating!.toStringAsFixed(1),
                      style: AppTextStyles.captionBold.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.star_rounded,
                        color: Colors.white, size: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms);
  }

  Widget _fallback(Color bg) => Container(
        color: bg,
        alignment: Alignment.center,
        child: Text(
          restaurant.heroEmoji ?? '🍽️',
          style: const TextStyle(fontSize: 26),
        ),
      );
}

class _DishResultRow extends StatelessWidget {
  const _DishResultRow({required this.item, required this.restaurants});
  final MenuItem item;
  final List<Restaurant> restaurants;

  @override
  Widget build(BuildContext context) {
    final r = restaurants.firstWhere(
      (x) => x.id == item.restaurantId,
      orElse: () => const Restaurant(id: '', name: '', deliveryCharge: 0),
    );
    return InkWell(
      onTap: () {
        if (r.id.isNotEmpty) {
          context.push(AppRoutes.restaurantDetailFor(r.id));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.sm,
        ),
        child: Row(
          children: [
            _VegDot(isVeg: item.isVeg),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppTextStyles.bodyBold, maxLines: 1),
                  const SizedBox(height: 2),
                  Text(
                    '₹${item.price.toStringAsFixed(0)} · ${r.name}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.north_east_rounded,
                color: AppColors.textMuted, size: 18),
          ],
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

class _NoResultsView extends StatelessWidget {
  const _NoResultsView({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: const Icon(Icons.search_off_rounded,
                  size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              'No results for "$query"',
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Try a different dish, cuisine, or caterer name.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
          ],
        ),
      ),
    );
  }
}
