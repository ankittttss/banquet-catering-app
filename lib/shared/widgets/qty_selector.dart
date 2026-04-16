import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';

/// Two-state stepper: shows ADD button at qty=0, shows -/qty/+ otherwise.
class QtySelector extends StatelessWidget {
  const QtySelector({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return SizedBox(
        height: 40,
        width: 100,
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
            minimumSize: const Size(100, 40),
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
    return Container(
      height: 40,
      width: 100,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepperBtn(
            icon: Icons.remove_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              onRemove();
            },
          ),
          Text(
            '$quantity',
            style: AppTextStyles.bodyBold.copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          _StepperBtn(
            icon: Icons.add_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              onAdd();
            },
          ),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: SizedBox(
        width: 34,
        height: 40,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
