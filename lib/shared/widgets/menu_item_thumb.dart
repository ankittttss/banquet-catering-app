import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../utils/gradient_palette.dart';

/// Premium food-item thumbnail. Shows [imageUrl] via CachedNetworkImage when
/// present; otherwise renders a deterministic gradient avatar with the
/// item's initial. Optionally overlays a veg/non-veg dot in the corner.
class MenuItemThumb extends StatelessWidget {
  const MenuItemThumb({
    super.key,
    required this.name,
    this.imageUrl,
    this.isVeg = true,
    this.showVegDot = true,
    this.size = 72,
    this.borderRadius = AppSizes.radiusMd,
  });

  final String name;
  final String? imageUrl;
  final bool isVeg;
  final bool showVegDot;
  final double size;
  final double borderRadius;

  String get _initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    final gradient = GradientPalette.linearFor(name);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: BoxDecoration(gradient: gradient)),
            if (hasImage)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _Initial(
                    initial: _initial, fontSize: size * 0.38),
                errorWidget: (_, __, ___) => _Initial(
                    initial: _initial, fontSize: size * 0.38),
              )
            else
              _Initial(initial: _initial, fontSize: size * 0.38),
            if (showVegDot) _VegDotCorner(isVeg: isVeg, size: size * 0.14),
          ],
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial, required this.fontSize});
  final String initial;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: AppTextStyles.display.copyWith(
          color: Colors.white.withValues(alpha: 0.96),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _VegDotCorner extends StatelessWidget {
  const _VegDotCorner({required this.isVeg, required this.size});
  final bool isVeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 6,
      right: 6,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isVeg ? AppColors.veg : AppColors.nonVeg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.4),
        ),
      ),
    );
  }
}
