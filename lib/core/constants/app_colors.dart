import 'package:flutter/material.dart';

/// Banquet & Catering palette — warm, premium, celebratory.
/// Reads as fine-dining / wedding rather than fast-food.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF8B1E3F); // Deep maroon
  static const Color primaryDark = Color(0xFF6A1530);
  static const Color primarySoft = Color(0xFFF6E7EC); // Tinted surface

  // Accent
  static const Color accent = Color(0xFFD4A574); // Warm gold
  static const Color accentDark = Color(0xFFB8894F);
  static const Color accentSoft = Color(0xFFF9EFE0);

  // Surfaces
  static const Color pageBg = Color(0xFFFFFBF5); // Warm cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFAF4EC);

  // Text
  static const Color textPrimary = Color(0xFF2A1A1F); // Deep brown-black
  static const Color textSecondary = Color(0xFF6B5862);
  static const Color textMuted = Color(0xFFA59196);

  // Lines
  static const Color border = Color(0xFFEBDFD4);
  static const Color divider = Color(0xFFF1E7DC);

  // Food indicators
  static const Color veg = Color(0xFF4A7C59);
  static const Color nonVeg = Color(0xFFB33951);

  // Semantic
  static const Color success = Color(0xFF4A7C59);
  static const Color warning = Color(0xFFD99A3E);
  static const Color error = Color(0xFFB33951);
  static const Color info = Color(0xFF4A6B8A);

  // Gradients
  static const List<Color> heroGradient = [
    Color(0xFF8B1E3F),
    Color(0xFFB23A5E),
  ];

  static const List<Color> goldGradient = [
    Color(0xFFD4A574),
    Color(0xFFE9C591),
  ];
}
