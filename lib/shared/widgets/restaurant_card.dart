import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router/app_routes.dart';
import '../../data/models/restaurant.dart';
import '../providers/favorites_providers.dart';
import 'safe_net_image.dart';

/// The customer-facing restaurant card (home feed). Shared so the admin
/// console can render a pixel-identical preview — the preview can never
/// drift from what customers actually see.
class RestaurantCard extends ConsumerWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.interactive = true,
  });

  final Restaurant restaurant;

  /// When false the card is render-only: no tap navigation and no favorite
  /// button. Used by the admin publish-preview.
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = interactive && ref.watch(isFavoriteProvider(restaurant.id));
    final bg = AppColors.fromHex(
      restaurant.heroBgHex,
      fallback: AppColors.primarySoft,
    );
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: interactive
            ? () {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.restaurantDetailFor(restaurant.id));
              }
            : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (restaurant.logoUrl != null)
                        SafeNetImage(
                          url: restaurant.logoUrl!,
                          errorBuilder: (_) => _emojiFallback(bg),
                        )
                      else
                        _emojiFallback(bg),
                      if (restaurant.tag != null)
                        Positioned(
                          top: AppSizes.sm,
                          left: AppSizes.sm,
                          child: _TagChip(text: restaurant.tag!),
                        ),
                      if (interactive)
                        Positioned(
                          top: AppSizes.sm,
                          right: AppSizes.sm,
                          child: _FavButton(
                            active: isFav,
                            onTap: () => ref
                                .read(favoritesProvider.notifier)
                                .toggle(restaurant.id),
                          ),
                        ),
                      if (restaurant.minGuests != null)
                        Positioned(
                          bottom: AppSizes.sm,
                          right: AppSizes.sm,
                          child: _MinGuestsChip(min: restaurant.minGuests!),
                        ),
                      if (restaurant.pricePerPlate != null)
                        Positioned(
                          bottom: AppSizes.sm,
                          left: AppSizes.sm,
                          child: _PriceChip(
                            pricePerPlate: restaurant.pricePerPlate!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: AppTextStyles.heading2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (restaurant.rating != null)
                          _RatingChip(
                            rating: restaurant.rating!,
                            count: restaurant.ratingsCount,
                          ),
                      ],
                    ),
                    if (restaurant.cuisinesDisplay != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        restaurant.cuisinesDisplay!,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSizes.sm),
                    Container(
                      height: 1,
                      color: AppColors.divider,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: [
                        if (restaurant.deliveryEta.isNotEmpty) ...[
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            restaurant.deliveryEta,
                            style: AppTextStyles.caption,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          const _Dot(),
                          const SizedBox(width: AppSizes.sm),
                        ],
                        const Icon(
                          Icons.currency_rupee_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        Text(
                          '${restaurant.pricePerPlate?.toStringAsFixed(0) ?? '—'}/plate',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emojiFallback(Color bg) => Container(
        color: bg,
        alignment: Alignment.center,
        child: Text(
          restaurant.heroEmoji ?? '🍽️',
          style: const TextStyle(fontSize: 56),
        ),
      );
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.captionBold.copyWith(
          color: Colors.white,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 18,
          color: active ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _MinGuestsChip extends StatelessWidget {
  const _MinGuestsChip({required this.min});
  final int min;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.catGreenLt,
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
      child: Text(
        'Min $min guests',
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.catGreen,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.pricePerPlate});
  final double pricePerPlate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '₹${pricePerPlate.toStringAsFixed(0)}/plate',
        style: AppTextStyles.bodyBold.copyWith(
          color: AppColors.primary,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, this.count});
  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final bg = rating >= 4.0 ? AppColors.success : AppColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppSizes.radiusXs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: AppTextStyles.captionBold.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.star_rounded, color: Colors.white, size: 13),
            ],
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            _formatCount(count!),
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      return '(${(n / 1000).toStringAsFixed(1)}K)';
    }
    return '($n)';
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.border,
          shape: BoxShape.circle,
        ),
      );
}
