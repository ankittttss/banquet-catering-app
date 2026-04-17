import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../providers/cart_providers.dart';

/// Persistent "cart peek" bar shown at the bottom of menu-like screens.
/// Hidden when the cart is empty; slides in as soon as the first item is added.
/// Tap to jump to the full cart screen.
class CartPeekBar extends ConsumerWidget {
  const CartPeekBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    if (count == 0) return const SizedBox.shrink();
    final total = ref.watch(cartFoodTotalProvider);
    final uniqueRestaurants = ref
        .watch(cartProvider)
        .map((c) => c.item.restaurantId)
        .toSet()
        .length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(AppRoutes.cart),
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.36),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: const Icon(
                      PhosphorIconsFill.shoppingBag,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count ${count == 1 ? 'item' : 'items'}'
                          '${uniqueRestaurants > 1 ? ' · $uniqueRestaurants kitchens' : ''}',
                          style: AppTextStyles.captionBold.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          Formatters.currency(total),
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View cart',
                        style: AppTextStyles.bodyBold
                            .copyWith(color: Colors.white),
                      ),
                      const SizedBox(width: AppSizes.xs),
                      const Icon(PhosphorIconsBold.arrowRight,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .slideY(begin: 1.2, end: 0, duration: 280.ms, curve: Curves.easeOut)
        .fadeIn();
  }
}
