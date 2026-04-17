import 'package:flutter/material.dart';

/// Feast palette — Zomato-style delivery-app look.
/// Warm red primary on clean whites, with dedicated event-category tints.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary     = Color(0xFFE23744);
  static const Color primaryDark = Color(0xFFC1272D);
  static const Color primarySoft = Color(0xFFFFF1F2);

  // Accent (gold / premium)
  static const Color accent     = Color(0xFFE5A100);
  static const Color accentDark = Color(0xFFB88300);
  static const Color accentSoft = Color(0xFFFFF8E7);

  // Surfaces
  static const Color pageBg     = Color(0xFFFFFFFF);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9F9F9);

  // Text
  static const Color textPrimary   = Color(0xFF1C1C1C);
  static const Color textSecondary = Color(0xFF4F4F4F);
  static const Color textMuted     = Color(0xFF828282);

  // Lines
  static const Color border  = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFF2F2F2);

  // Food indicators
  static const Color veg    = Color(0xFF1BA672);
  static const Color nonVeg = Color(0xFFE23744);

  // Semantic
  static const Color success = Color(0xFF1BA672);
  static const Color warning = Color(0xFFE5A100);
  static const Color error   = Color(0xFFE23744);
  static const Color info    = Color(0xFF2B6CB0);

  // Event-category tints (prototype palette)
  static const Color catRedLt    = Color(0xFFFFF1F2);
  static const Color catRed      = Color(0xFFE23744);
  static const Color catPinkLt   = Color(0xFFFCE8F0);
  static const Color catPink     = Color(0xFFD63384);
  static const Color catBlueLt   = Color(0xFFEBF4FF);
  static const Color catBlue     = Color(0xFF2B6CB0);
  static const Color catGoldLt   = Color(0xFFFFF8E7);
  static const Color catGold     = Color(0xFFE5A100);
  static const Color catPurpleLt = Color(0xFFF3E8FF);
  static const Color catPurple   = Color(0xFF9B59B6);
  static const Color catGreenLt  = Color(0xFFEAFAF1);
  static const Color catGreen    = Color(0xFF1BA672);

  // Gradients
  static const List<Color> heroGradient = [
    Color(0xFFE23744),
    Color(0xFFFF6B7A),
  ];

  static const List<Color> goldGradient = [
    Color(0xFFE5A100),
    Color(0xFFFFC93D),
  ];

  /// Parse a `#RRGGBB` hex from the backend into a Flutter [Color].
  /// Returns [fallback] on bad input.
  static Color fromHex(String? hex, {Color fallback = surfaceAlt}) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(cleaned.length == 6 ? (0xFF000000 | value) : value);
  }
}
