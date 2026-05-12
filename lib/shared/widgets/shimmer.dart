import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Soft, repeating shimmer for loading placeholders. Built on top of
/// flutter_animate (already a project dep) so we don't pull in a
/// dedicated shimmer package — and so the cadence matches the rest of
/// the app's animations.
///
/// The widget is just a coloured rectangle with a moving white sheen
/// crossing it diagonally. Drop one anywhere a `Container` would go;
/// shape it via [width], [height], and [borderRadius].
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
    this.baseColor,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? baseColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(6);
    final base = baseColor ?? AppColors.border.withValues(alpha: 0.55);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: radius,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1400.ms,
          color: Colors.white.withValues(alpha: 0.6),
        );
  }
}

/// Card-shaped shimmer placeholder that mimics the operator's inbox /
/// recent-bookings card. Used during the initial load so the screen
/// reveals its real shape immediately instead of showing a spinner.
class ShimmerBookingCard extends StatelessWidget {
  const ShimmerBookingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: ShimmerBox(width: 160, height: 14),
              ),
              ShimmerBox(
                width: 64,
                height: 20,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm + 2),
          const ShimmerBox(width: 180, height: 18),
          const SizedBox(height: 6),
          const ShimmerBox(width: 120, height: 12),
          const SizedBox(height: 10),
          const ShimmerBox(width: 220, height: 12),
        ],
      ),
    );
  }
}

/// Compact shimmer that mirrors the dashboard's stat-card layout
/// (icon swatch + big number + label). Three of these stacked in a
/// row replace the stats-row spinner during load.
class ShimmerStatCard extends StatelessWidget {
  const ShimmerStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(
            width: 30,
            height: 30,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          const SizedBox(height: AppSizes.sm),
          const ShimmerBox(width: 40, height: 22),
          const SizedBox(height: 4),
          const ShimmerBox(width: 70, height: 10),
        ],
      ),
    );
  }
}
