import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/menu_item.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/favorites_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/qty_selector.dart';
import '../../../shared/widgets/veg_dot.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
    final items =
        ref.watch(menuItemsProvider).valueOrNull ?? const <MenuItem>[];
    final list =
        items.where((i) => favs.contains(i.id)).toList(growable: false);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: list.isEmpty
          ? const EmptyState(
              title: 'No favorites yet',
              message:
                  'Tap the heart icon on any dish to save it here for later.',
              icon: Icons.favorite_outline_rounded,
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              itemBuilder: (_, i) => _FavoriteRow(item: list[i])
                  .animate(delay: (i * 40).ms)
                  .fadeIn(duration: 260.ms),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSizes.xs),
              itemCount: list.length,
            ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.item});
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
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
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
                  const SizedBox(height: 2),
                  Text(Formatters.currency(item.price),
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsFill.heart,
                  color: AppColors.primary),
              onPressed: () {
                HapticFeedback.selectionClick();
                ref
                    .read(favoritesProvider.notifier)
                    .toggle(item.id);
              },
            ),
            const SizedBox(width: AppSizes.xs),
            QtySelector(
              quantity: qty,
              onAdd: () => ref.read(cartProvider.notifier).add(item),
              onRemove: () => ref.read(cartProvider.notifier).remove(item),
            ),
          ],
        ),
      ),
    );
  }
}
