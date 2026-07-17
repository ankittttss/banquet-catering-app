import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/geo.dart';
import '../../../data/models/dish_search_result.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/search_providers.dart';
import '../../../shared/providers/search_results_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/safe_net_image.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Pre-filled search text — used by the home collection cards to land the
  /// customer on live results (e.g. "Biryani") instead of an empty box.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      _ctrl.text = q;
      _query = q;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _commitNow(q);
      });
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Local state updates instantly (view switching / clear button); the
  /// server query is committed after a debounce so we don't fire a network
  /// round-trip per keystroke.
  void _setQuery(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = v;
    });
  }

  /// Immediate commit — used by recent rows / trending chips.
  void _commitNow(String v) {
    _debounce?.cancel();
    ref.read(searchQueryProvider.notifier).state = v;
  }

  void _submit(String v) {
    final q = v.trim();
    if (q.isEmpty) return;
    _commitNow(v);
    ref.read(recentSearchesProvider.notifier).add(q);
  }

  void _runQuery(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _query = q);
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
            setState(() => _query = '');
            _commitNow('');
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
                        onTap: () =>
                            ref.read(recentSearchesProvider.notifier).clear(),
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
                    onRemove: () =>
                        ref.read(recentSearchesProvider.notifier).remove(q),
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
    if (query.trim().length < 2) {
      return Center(
        child: Text(
          'Type at least 2 letters to search',
          style: AppTextStyles.bodyMuted,
        ),
      );
    }

    // The debounce means the committed query can briefly lag what's typed —
    // treat that window as loading so we never flash "No results".
    final committed = ref.watch(searchQueryProvider);
    final pending = committed.trim() != query.trim();
    final restA = ref.watch(restaurantSearchProvider);
    final dishA = ref.watch(dishSearchProvider);
    final loading = pending || restA.isLoading || dishA.isLoading;

    final restaurants = restA.valueOrNull;
    final dishes = dishA.valueOrNull;

    if (restaurants == null || dishes == null) {
      if (!loading && (restA.hasError || dishA.hasError)) {
        return _SearchErrorView(
          onRetry: () {
            ref.invalidate(restaurantSearchProvider);
            ref.invalidate(dishSearchProvider);
          },
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (!loading && restaurants.isEmpty && dishes.isEmpty) {
      return _NoResultsView(query: query);
    }

    final coords = ref.watch(customerCoordsProvider);
    final hasCoords = coords.lat != null && coords.lng != null;

    return Column(
      children: [
        if (loading)
          const LinearProgressIndicator(
            minHeight: 2,
            color: AppColors.primary,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(
              top: AppSizes.md,
              bottom: AppSizes.xxxl,
            ),
            children: [
              if (!hasCoords)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.pagePadding,
                    0,
                    AppSizes.pagePadding,
                    AppSizes.sm,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.sm + 2),
                    decoration: BoxDecoration(
                      color: AppColors.catBlueLt,
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.catBlue,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            'Set your delivery address to see which '
                            'kitchens can serve you.',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.catBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (restaurants.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.pagePadding,
                    AppSizes.sm,
                    AppSizes.pagePadding,
                    AppSizes.sm,
                  ),
                  child: Text(
                    'Restaurants (${restaurants.length})',
                    style: AppTextStyles.captionBold
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                for (final r in restaurants)
                  _RestaurantResultRow(
                    restaurant: r,
                    serviceability: serviceabilityOf(
                      r,
                      customerLat: coords.lat,
                      customerLng: coords.lng,
                    ),
                    distanceKm: distanceToRestaurantKm(
                      r,
                      customerLat: coords.lat,
                      customerLng: coords.lng,
                    ),
                  ),
              ],
              if (dishes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.pagePadding,
                    AppSizes.lg,
                    AppSizes.pagePadding,
                    AppSizes.sm,
                  ),
                  child: Text(
                    'Dishes (${dishes.length})',
                    style: AppTextStyles.captionBold
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                for (final d in dishes) _DishResultRow(result: d),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchErrorView extends StatelessWidget {
  const _SearchErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSizes.md),
            Text('Search is unavailable', style: AppTextStyles.heading2),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Check your connection and try again.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _RestaurantResultRow extends StatelessWidget {
  const _RestaurantResultRow({
    required this.restaurant,
    required this.serviceability,
    required this.distanceKm,
  });
  final Restaurant restaurant;
  final Serviceability serviceability;
  final double? distanceKm;

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
                  const SizedBox(height: 3),
                  _RangeLabel(
                    serviceability: serviceability,
                    distanceKm: distanceKm,
                  ),
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
  const _DishResultRow({required this.result});
  final DishSearchResult result;

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final outOfRange =
        result.distanceKm != null && result.distanceKm! > kServiceRadiusKm;
    return InkWell(
      // Always navigable — the RPC guarantees the restaurant is published,
      // and the detail screen handles the out-of-range state itself.
      onTap: () =>
          context.push(AppRoutes.restaurantDetailFor(item.restaurantId)),
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
                    '₹${item.price.toStringAsFixed(0)} · '
                    '${result.restaurantName}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (outOfRange) ...[
              const SizedBox(width: AppSizes.sm),
              const _OutOfRangeChip(),
            ],
            const SizedBox(width: AppSizes.sm),
            const Icon(Icons.north_east_rounded,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Distance / serviceability line under a restaurant result. Out-of-range
/// kitchens stay visible and tappable — this label is the honest signal.
class _RangeLabel extends StatelessWidget {
  const _RangeLabel({required this.serviceability, required this.distanceKm});
  final Serviceability serviceability;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    switch (serviceability) {
      case Serviceability.inRange:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 12,
              color: AppColors.success,
            ),
            const SizedBox(width: 2),
            Text(
              distanceKm == null
                  ? 'Delivers to your location'
                  : '${distanceKm!.toStringAsFixed(1)} km away',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.success,
                fontSize: 11,
              ),
            ),
          ],
        );
      case Serviceability.outOfRange:
        return const _OutOfRangeChip();
      case Serviceability.unknown:
        return const SizedBox.shrink();
    }
  }
}

class _OutOfRangeChip extends StatelessWidget {
  const _OutOfRangeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'OUT OF RANGE',
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.accentDark,
          fontSize: 9,
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
