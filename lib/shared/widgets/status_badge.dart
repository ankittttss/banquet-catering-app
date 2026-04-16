import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';

enum StatusTone { neutral, info, success, warning, error, pending }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  ({Color bg, Color fg}) _colors() {
    switch (tone) {
      case StatusTone.success:
        return (
          bg: AppColors.success.withValues(alpha: 0.12),
          fg: AppColors.success,
        );
      case StatusTone.warning:
        return (
          bg: AppColors.warning.withValues(alpha: 0.14),
          fg: AppColors.warning,
        );
      case StatusTone.error:
        return (
          bg: AppColors.error.withValues(alpha: 0.12),
          fg: AppColors.error,
        );
      case StatusTone.info:
        return (
          bg: AppColors.info.withValues(alpha: 0.12),
          fg: AppColors.info,
        );
      case StatusTone.pending:
        return (
          bg: AppColors.accentSoft,
          fg: AppColors.accentDark,
        );
      case StatusTone.neutral:
        return (
          bg: AppColors.surfaceAlt,
          fg: AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.xs + 2,
      ),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconXs, color: c.fg),
            const SizedBox(width: AppSizes.xs),
          ],
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(color: c.fg),
          ),
        ],
      ),
    );
  }
}
