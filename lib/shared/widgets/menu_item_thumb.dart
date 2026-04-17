import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../utils/gradient_palette.dart';
import 'safe_net_image.dart';

/// Premium food-item thumbnail. Shows [imageUrl] via CachedNetworkImage when
/// present; otherwise falls back to a deterministic foodish-api image based on
/// dish keywords, and finally to a gradient avatar with the item's initial.
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
    final resolved = (imageUrl != null && imageUrl!.isNotEmpty)
        ? imageUrl!
        : FoodImageResolver.urlFor(name, isVeg: isVeg);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: BoxDecoration(gradient: gradient)),
            SafeNetImage(
              url: resolved,
              errorBuilder: (_) =>
                  _Initial(initial: _initial, fontSize: size * 0.38),
              placeholder: (_) =>
                  _Initial(initial: _initial, fontSize: size * 0.38),
            ),
            if (showVegDot) _VegDotCorner(isVeg: isVeg, size: size * 0.14),
          ],
        ),
      ),
    );
  }
}

/// Deterministic food-image resolver. Picks a category-appropriate image from
/// foodish-api.com (free, CORS-enabled) based on keywords in the dish name.
/// Ensures every dish has a photo, even when the DB `image_url` is null.
class FoodImageResolver {
  FoodImageResolver._();

  static const _base = 'https://foodish-api.com/images';

  // foodish-api categories and their image counts (as of 2026).
  static const Map<String, int> _counts = {
    'biryani': 40,
    'burger': 33,
    'butter-chicken': 15,
    'dessert': 53,
    'dosa': 29,
    'idly': 31,
    'pasta': 40,
    'pizza': 40,
    'rice': 41,
    'samosa': 30,
  };

  /// Returns a stable URL for [name]. Same name always resolves to same photo.
  static String urlFor(String name, {bool isVeg = true}) {
    final n = name.toLowerCase();
    final cat = _categoryFor(n, isVeg: isVeg);
    final count = _counts[cat]!;
    // Deterministic hash of name → index in category.
    final idx = (name.codeUnits.fold<int>(0, (s, c) => s + c) % count) + 1;
    return '$_base/$cat/$cat$idx.jpg';
  }

  static String _categoryFor(String n, {required bool isVeg}) {
    if (n.contains('biryani') || n.contains('pulao')) return 'biryani';
    if (n.contains('dosa') || n.contains('uttapam')) return 'dosa';
    if (n.contains('idly') || n.contains('idli') || n.contains('vada')) {
      return 'idly';
    }
    if (n.contains('samosa') ||
        n.contains('pakora') ||
        n.contains('chaat') ||
        n.contains('papad')) {
      return 'samosa';
    }
    if (n.contains('pizza')) return 'pizza';
    if (n.contains('pasta') || n.contains('noodle')) return 'pasta';
    if (n.contains('burger')) return 'burger';
    if (n.contains('gulab') ||
        n.contains('jamun') ||
        n.contains('halwa') ||
        n.contains('kheer') ||
        n.contains('phirni') ||
        n.contains('rasmalai') ||
        n.contains('kulfi') ||
        n.contains('bebinca') ||
        n.contains('mohan') ||
        n.contains('barfi') ||
        n.contains('laddu') ||
        n.contains('shahi tukda') ||
        n.contains('falooda') ||
        n.contains('dessert') ||
        n.contains('sweet')) {
      return 'dessert';
    }
    if (!isVeg ||
        n.contains('chicken') ||
        n.contains('mutton') ||
        n.contains('lamb') ||
        n.contains('fish') ||
        n.contains('prawn') ||
        n.contains('tikka') ||
        n.contains('kebab') ||
        n.contains('curry') ||
        n.contains('masala') ||
        n.contains('makhani') ||
        n.contains('rogan') ||
        n.contains('lababdar') ||
        n.contains('do pyaza') ||
        n.contains('paneer')) {
      return 'butter-chicken';
    }
    // Default: rice-based (dal, khichdi, thali, naan, paratha all look fine).
    return 'rice';
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
