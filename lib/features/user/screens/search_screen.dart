import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/qty_selector.dart';
import '../../../shared/widgets/veg_dot.dart';

// Local state for this screen — plain text controller; could be StateProvider later.
final _recentSearchesProvider =
    StateProvider<List<String>>((ref) => const ['Paneer Tikka', 'Biryani', 'Rasmalai']);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit(String q) {
    final text = q.trim();
    if (text.isEmpty) return;
    final recent = ref.read(_recentSearchesProvider);
    if (recent.contains(text)) return;
    ref.read(_recentSearchesProvider.notifier).state = [
      text,
      ...recent.take(7),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(menuItemsProvider).valueOrNull ?? const [];
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];
    final q = _query.toLowerCase().trim();

    final matchedItems = q.isEmpty
        ? const <MenuItem>[]
        : items
            .where((i) =>
                i.name.toLowerCase().contains(q) ||
                (i.description?.toLowerCase().contains(q) ?? false))
            .take(25)
            .toList();
    final matchedRestaurants = q.isEmpty
        ? const <Restaurant>[]
        : restaurants
            .where((r) => r.name.toLowerCase().contains(q))
            .take(10)
            .toList();

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSizes.pagePadding),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: _commit,
            decoration: InputDecoration(
              hintText: 'Search dishes, cuisines, restaurants…',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              prefixIcon: const Icon(PhosphorIconsBold.magnifyingGlass,
                  size: 20, color: AppColors.primary),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(PhosphorIconsBold.x, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: q.isEmpty
          ? _EmptyPrompt(
              recent: ref.watch(_recentSearchesProvider),
              onPick: (t) {
                _ctrl.text = t;
                _ctrl.selection =
                    TextSelection.collapsed(offset: t.length);
                setState(() => _query = t);
              },
            )
          : (matchedItems.isEmpty && matchedRestaurants.isEmpty)
              ? const EmptyState(
                  title: 'No matches',
                  message: 'Try a different cuisine or dish.',
                  icon: Icons.search_off_rounded,
                )
              : ListView(
                  padding: const EdgeInsets.only(
                    top: AppSizes.sm,
                    bottom: 120,
                  ),
                  children: [
                    if (matchedRestaurants.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.pagePadding,
                          AppSizes.md,
                          AppSizes.pagePadding,
                          AppSizes.sm,
                        ),
                        child: Text('RESTAURANTS',
                            style: AppTextStyles.overline),
                      ),
                      for (int i = 0; i < matchedRestaurants.length; i++)
                        _RestaurantRow(restaurant: matchedRestaurants[i])
                            .animate(delay: (i * 40).ms)
                            .fadeIn(duration: 250.ms),
                    ],
                    if (matchedItems.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.pagePadding,
                          AppSizes.md,
                          AppSizes.pagePadding,
                          AppSizes.sm,
                        ),
                        child: Text(
                          'DISHES · ${matchedItems.length}',
                          style: AppTextStyles.overline,
                        ),
                      ),
                      for (int i = 0; i < matchedItems.length; i++)
                        _ItemRow(item: matchedItems[i])
                            .animate(delay: (i * 30).ms)
                            .fadeIn(duration: 240.ms),
                    ],
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.recent, required this.onPick});
  final List<String> recent;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Biryani',
      'Paneer',
      'Mughlai',
      'North Indian',
      'Rasmalai',
      'Gulab Jamun',
      'Kebab',
      'Dal',
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        if (recent.isNotEmpty) ...[
          Text('RECENT', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              for (final r in recent)
                InkWell(
                  onTap: () => onPick(r),
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: AppSizes.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsBold.clockCounterClockwise,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: AppSizes.xs),
                        Text(r, style: AppTextStyles.body),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
        ],
        Text('TRENDING', style: AppTextStyles.overline),
        const SizedBox(height: AppSizes.sm),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final s in suggestions)
              InkWell(
                onTap: () => onPick(s),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusPill),
                  ),
                  child: Text(s,
                      style: AppTextStyles.bodyBold
                          .copyWith(color: AppColors.primary)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({required this.restaurant});
  final Restaurant restaurant;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          context.push(AppRoutes.restaurantDetailFor(restaurant.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              alignment: Alignment.center,
              child: Text(
                restaurant.name[0],
                style: AppTextStyles.display.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant.name, style: AppTextStyles.bodyBold),
                  Text('Restaurant · tap to open',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.caretRight,
                color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});
  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(cartProvider.select((list) {
      final idx = list.indexWhere((c) => c.item.id == item.id);
      return idx == -1 ? 0 : list[idx].qty;
    }));
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pagePadding,
        vertical: AppSizes.xs,
      ),
      child: Row(
        children: [
          VegDot(isVeg: item.isVeg),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.bodyBold),
                Text(Formatters.currency(item.price),
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          QtySelector(
            quantity: qty,
            onAdd: () => ref.read(cartProvider.notifier).add(item),
            onRemove: () => ref.read(cartProvider.notifier).remove(item),
          ),
        ],
      ),
    );
  }
}
