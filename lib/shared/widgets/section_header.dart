import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';

/// Kicker + title + optional trailing action. Used above lists / sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.kicker,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSizes.pagePadding,
      vertical: AppSizes.md,
    ),
  });

  final String title;
  final String? kicker;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) ...[
                  Text(kicker!.toUpperCase(),
                      style: AppTextStyles.overline),
                  const SizedBox(height: AppSizes.xs),
                ],
                Text(title, style: AppTextStyles.heading1),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(subtitle!,
                      style: AppTextStyles.bodyMuted
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSizes.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
