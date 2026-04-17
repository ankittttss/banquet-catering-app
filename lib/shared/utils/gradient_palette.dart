import 'package:flutter/material.dart';

/// Deterministic 2-stop gradients keyed off a stable string (e.g. item name).
/// Same input always yields the same gradient — used for placeholder avatars,
/// thumbnails, chip backgrounds, anywhere a colorful-but-stable visual is wanted.
class GradientPalette {
  GradientPalette._();

  static const List<List<Color>> palettes = [
    [Color(0xFFE9C591), Color(0xFFD4A574)], // gold
    [Color(0xFFF6CBD1), Color(0xFFE2A1AC)], // rose
    [Color(0xFFC9DFC2), Color(0xFFA8C49E)], // sage
    [Color(0xFFE6D3B3), Color(0xFFCBB38F)], // beige
    [Color(0xFFF0B1A0), Color(0xFFD98471)], // terracotta
    [Color(0xFFC6D8E8), Color(0xFF94B5CE)], // sky
  ];

  static List<Color> forSeed(String seed) {
    if (seed.isEmpty) return palettes.first;
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return palettes[hash % palettes.length];
  }

  static LinearGradient linearFor(String seed) => LinearGradient(
        colors: forSeed(seed),
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
