import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accentSoft,
      onSecondaryContainer: AppColors.accentDark,
      tertiary: AppColors.accentDark,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceAlt,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
      shadow: Colors.black12,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.pageBg,
      splashFactory: InkRipple.splashFactory,
      textTheme: _textTheme(),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.pageBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading2,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: AppTextStyles.buttonLabel,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: AppTextStyles.buttonLabel,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.buttonLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        labelStyle: AppTextStyles.bodyMuted,
        hintStyle: AppTextStyles.bodyMuted,
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.primary,
        disabledColor: AppColors.surfaceAlt,
        side: const BorderSide(color: AppColors.border),
        labelStyle: AppTextStyles.bodyBold,
        secondaryLabelStyle:
            AppTextStyles.bodyBold.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          side: BorderSide.none,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXl),
          ),
        ),
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle:
            AppTextStyles.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        titleTextStyle: AppTextStyles.heading2,
        contentTextStyle: AppTextStyles.body,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(Colors.transparent),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.all(0),
        radius: const Radius.circular(0),
        thumbVisibility: WidgetStateProperty.all(false),
        trackVisibility: WidgetStateProperty.all(false),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTextStyles.bodyBold,
        unselectedLabelStyle: AppTextStyles.body,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
    );
  }

  static ThemeData dark() {
    // Dark theme mirrors but deepens; keep light for v1.
    // Re-derive from light so dev never ships a broken dark.
    return light();
  }

  static TextTheme _textTheme() {
    return GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: AppTextStyles.display,
      displayMedium: AppTextStyles.displaySm,
      headlineLarge: AppTextStyles.heading1,
      headlineMedium: AppTextStyles.heading1,
      headlineSmall: AppTextStyles.heading2,
      titleLarge: AppTextStyles.heading2,
      titleMedium: AppTextStyles.heading3,
      titleSmall: AppTextStyles.bodyBold,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.caption,
      labelLarge: AppTextStyles.buttonLabel,
      labelMedium: AppTextStyles.captionBold,
      labelSmall: AppTextStyles.overline,
    );
  }
}
