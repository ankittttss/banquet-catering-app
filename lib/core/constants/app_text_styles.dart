import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography: Plus Jakarta Sans for everything — modern, rounded sans-serif
/// that matches the Zomato-style prototype. Clean readability, good weights.
class AppTextStyles {
  AppTextStyles._();

  // --- Display (big hero text) ---
  static TextStyle display = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.8,
  );

  static TextStyle displaySm = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static TextStyle totalAmount = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    letterSpacing: -0.3,
  );

  // --- Headings ---
  static TextStyle heading1 = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
    letterSpacing: -0.4,
  );

  static TextStyle heading2 = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static TextStyle heading3 = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // --- Body ---
  static TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle bodyBold = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyMuted = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // --- Caption / Label ---
  static TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  static TextStyle captionBold = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  static TextStyle overline = GoogleFonts.plusJakartaSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.accentDark,
    letterSpacing: 1.2,
  );

  // --- Buttons ---
  static TextStyle buttonLabel = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  // --- Price ---
  static TextStyle price = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle priceStrike = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    color: AppColors.textMuted,
    decoration: TextDecoration.lineThrough,
  );
}
