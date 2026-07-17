import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/restaurant.dart';

/// Colored lifecycle chip — used on the admin restaurants list, the
/// management page header and the wizard.
class RestaurantStatusBadge extends StatelessWidget {
  const RestaurantStatusBadge({super.key, required this.status});

  final RestaurantStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      RestaurantStatus.published => (AppColors.catGreenLt, AppColors.catGreen),
      RestaurantStatus.draft => (AppColors.catBlueLt, AppColors.catBlue),
      RestaurantStatus.suspended => (AppColors.catGoldLt, AppColors.accentDark),
      RestaurantStatus.archived => (AppColors.surfaceAlt, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: AppTextStyles.captionBold.copyWith(color: fg, fontSize: 9),
      ),
    );
  }
}
