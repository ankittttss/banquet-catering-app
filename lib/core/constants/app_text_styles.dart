import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography: Playfair Display (serif) for display/totals — reads "fine dining".
/// Inter (sans) for body, labels, buttons — clean modern readability.
class AppTextStyles {
  AppTextStyles._();

  // --- Display (serif) ---
  static TextStyle display = GoogleFonts.playfairDisplay(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static TextStyle displaySm = GoogleFonts.playfairDisplay(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.3,
  );

  /// Used for totals / invoice-like amounts (premium feel).
  static TextStyle totalAmount = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: -0.3,
  );

  // --- Headings (sans) ---
  static TextStyle heading1 = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static TextStyle heading2 = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static TextStyle heading3 = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // --- Body ---
  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle bodyBold = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMuted = GoogleFonts.inter(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // --- Caption / Label ---
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  static TextStyle captionBold = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.6,
  );

  static TextStyle overline = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.accentDark,
    letterSpacing: 1.2,
  );

  // --- Buttons ---
  static TextStyle buttonLabel = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  // --- Price ---
  static TextStyle price = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle priceStrike = GoogleFonts.inter(
    fontSize: 13,
    color: AppColors.textMuted,
    decoration: TextDecoration.lineThrough,
  );
}
