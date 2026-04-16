import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, ghost }

enum AppButtonSize { md, sm }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final height = size == AppButtonSize.md
        ? AppSizes.buttonHeight
        : AppSizes.buttonHeightSm;

    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.primary
                  ? Colors.white
                  : AppColors.primary,
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.iconSm),
                const SizedBox(width: AppSizes.sm),
              ],
              Text(label, style: AppTextStyles.buttonLabel),
            ],
          );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: loading ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.secondary => OutlinedButton(
          onPressed: loading ? null : onPressed,
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: loading ? null : onPressed,
          child: child,
        ),
    };

    // `expand: true` stretches to parent's available width when the parent
    // bounds it, otherwise falls back to intrinsic width. We NEVER pass
    // `double.infinity` because that crashes inside unbounded-width contexts
    // (e.g. Center or Column cross-axis without a width constraint).
    if (expand) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isFinite) {
            return SizedBox(
              width: constraints.maxWidth,
              height: height,
              child: button,
            );
          }
          // Unbounded parent — use intrinsic width.
          return IntrinsicWidth(
            child: SizedBox(height: height, child: button),
          );
        },
      );
    }
    return IntrinsicWidth(
      child: SizedBox(height: height, child: button),
    );
  }
}
