import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';

/// Banquet-catering include/exclude toggle — one tap picks the dish (one
/// portion per guest, scaled by headcount at checkout), a second tap removes
/// it. No numeric stepper: for per-guest catering, raising/lowering quantity
/// on the menu doesn't match the mental model ("I want biryani for everyone,
/// not 7 biryanis").
///
/// Callers that genuinely need multiple portions per guest of the same dish
/// can still bump the qty from the cart screen.
class PickToggle extends StatelessWidget {
  const PickToggle({
    super.key,
    required this.selected,
    required this.onAdd,
    required this.onRemove,
  });

  final bool selected;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return SizedBox(
        height: 40,
        width: 110,
        child: OutlinedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onAdd();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            backgroundColor: AppColors.primarySoft,
            side: const BorderSide(color: AppColors.primary, width: 1.2),
            padding: EdgeInsets.zero,
            minimumSize: const Size(110, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
          ),
          child: Text(
            'ADD',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.primary,
              fontSize: 12.5,
              letterSpacing: 1.4,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 40,
      width: 110,
      child: FilledButton.icon(
        onPressed: () {
          HapticFeedback.selectionClick();
          onRemove();
        },
        icon: const Icon(PhosphorIconsBold.check, size: 14),
        label: Text(
          'ADDED',
          style: AppTextStyles.captionBold.copyWith(
            color: Colors.white,
            fontSize: 12.5,
            letterSpacing: 1.4,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          minimumSize: const Size(110, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
        ),
      ),
    );
  }
}
