import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/veg_dot.dart';
import '../widgets/menu_item_form_sheet.dart';

class AdminMenuScreen extends ConsumerWidget {
  const AdminMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(adminMenuItemsProvider);
    final restaurants = ref.watch(restaurantsProvider);
    final cats = ref.watch(menuCategoriesProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('Add item'),
        onPressed: () => _add(context),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'No menu items',
              message: 'Tap "Add item" to create your first dish.',
              icon: PhosphorIconsDuotone.forkKnife,
            );
          }
          final cMap = {
            for (final c in cats.valueOrNull ?? <MenuCategory>[]) c.id: c,
          };
          final rMap = <String, Restaurant>{
            for (final r in restaurants.valueOrNull ?? <Restaurant>[])
              r.id: r,
          };

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.md,
              AppSizes.pagePadding,
              96, // clear the floating "Add item" button
            ),
            itemBuilder: (_, i) => _ItemTile(
              item: list[i],
              category: cMap[list[i].categoryId],
              restaurantName: rMap[list[i].restaurantId]?.name,
            ),
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
            itemCount: list.length,
          );
        },
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final saved = await MenuItemFormSheet.show(context);
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added')),
      );
    }
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.item,
    required this.category,
    required this.restaurantName,
  });

  final MenuItem item;
  final MenuCategory? category;
  final String? restaurantName;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref
          .read(menuRepositoryProvider)
          .setMenuItemAvailability(id: item.id, isAvailable: value);
      ref.invalidate(adminMenuItemsProvider);
      ref.invalidate(menuItemsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update: ${_first(e)}')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('"${item.name}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(menuRepositoryProvider).deleteMenuItem(item.id);
      ref.invalidate(adminMenuItemsProvider);
      ref.invalidate(menuItemsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: ${_first(e)}')),
        );
      }
    }
  }

  String _first(Object e) {
    final s = e.toString().split('\n').first;
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => MenuItemFormSheet.show(context, existing: item),
      child: Opacity(
        opacity: item.isAvailable ? 1 : 0.55,
        child: Row(
          children: [
            VegDot(isVeg: item.isVeg),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyBold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${restaurantName ?? "—"} · ${category?.name ?? "—"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(Formatters.currency(item.price), style: AppTextStyles.price),
            Switch.adaptive(
              value: item.isAvailable,
              activeTrackColor: AppColors.primary,
              onChanged: (v) => _toggle(context, ref, v),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsBold.trash, size: 20),
              color: AppColors.textMuted,
              tooltip: 'Delete',
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
