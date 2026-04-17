import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/favorites_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/safe_net_image.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favSet = ref.watch(favoritesProvider).valueOrNull ?? const <String>{};
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];
    final favorites =
        restaurants.where((r) => favSet.contains(r.id)).toList();

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Favorites'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.profile),
        ),
      ),
      body: favorites.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No favorites yet',
              message:
                  'Tap the heart on any restaurant to save it here for quick reorders.',
              actionLabel: 'Browse restaurants',
              onAction: () => context.go(AppRoutes.userHome),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              itemCount: favorites.length,
              itemBuilder: (_, i) => _FavRow(restaurant: favorites[i])
                  .animate()
                  .fadeIn(duration: 220.ms, delay: (30 * i).ms),
            ),
    );
  }
}

class _FavRow extends ConsumerWidget {
  const _FavRow({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = AppColors.fromHex(restaurant.heroBgHex,
        fallback: AppColors.primarySoft);

    return InkWell(
      onTap: () => context.push(AppRoutes.restaurantDetailFor(restaurant.id)),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: SizedBox(
                width: 70,
                height: 70,
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
                      '${restaurant.cuisinesDisplay!}'
                      '${restaurant.rating == null ? '' : ' · ★ ${restaurant.rating!.toStringAsFixed(1)}'}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(favoritesProvider.notifier).toggle(restaurant.id);
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.favorite_rounded,
                    color: AppColors.primary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(Color bg) => Container(
        color: bg,
        alignment: Alignment.center,
        child: Text(
          restaurant.heroEmoji ?? '🍽️',
          style: const TextStyle(fontSize: 28),
        ),
      );
}
