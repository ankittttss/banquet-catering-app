import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/veg_dot.dart';

class AdminMenuScreen extends ConsumerWidget {
  const AdminMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(menuItemsProvider);
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
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'No menu items',
              message:
                  'Seed your first restaurant and items via the admin SQL.',
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
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            itemBuilder: (_, i) => _ItemTile(
              item: list[i],
              category: cMap[list[i].categoryId],
              restaurantName: rMap[list[i].restaurantId]?.name,
            ),
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSizes.sm),
            itemCount: list.length,
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.category,
    required this.restaurantName,
  });

  final MenuItem item;
  final MenuCategory? category;
  final String? restaurantName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                Text(
                  '${restaurantName ?? "—"} · ${category?.name ?? "—"}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Text(Formatters.currency(item.price), style: AppTextStyles.price),
          const SizedBox(width: AppSizes.sm),
          Switch.adaptive(
            value: item.isAvailable,
            onChanged: (_) {
              // Placeholder — wire to Supabase update in Phase 5.1.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Toggling availability: TODO')),
              );
            },
          ),
        ],
      ),
    );
  }
}
