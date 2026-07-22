import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';

/// Sticky header used across the plan-your-event flow. Renders the back
/// button, screen title, and a neutral section label.
///
/// The subtitle deliberately shows the section name (e.g. "Venue"), NOT a
/// "Step N of M" count, and there is intentionally NO segmented progress bar:
/// the private-property branch adds property + setup screens after the venue
/// step, so any fixed denominator — or a fully-filled 2-of-2 bar on the venue
/// screen — would misstate how far along the customer actually is. The label
/// stays honest and count-free.
class PlanFlowHeader extends StatelessWidget {
  const PlanFlowHeader({
    super.key,
    required this.title,
    required this.stepLabel,
    this.subtitleOverride,
    this.onBack,
  });

  final String title;
  final String stepLabel;

  /// When set, replaces the default neutral section label — used by
  /// sub-screens that want a bespoke line (e.g. "Optional add-ons for your
  /// property").
  final String? subtitleOverride;

  /// Overrides the back button's default `pop → userHome fallback`. Edit mode
  /// uses this to fall back to the Event Plan on a direct deep link instead.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack ??
                    () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.userHome),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(AppSizes.sm),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 28,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.display.copyWith(
                        fontSize: 24,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleOverride ?? stepLabel,
                      style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom action bar shared by the plan-flow screens. Left side
/// shows a two-line label, right side shows a primary action button.
class PlanFlowFooter extends StatelessWidget {
  const PlanFlowFooter({
    super.key,
    required this.labelLine1,
    required this.labelLine2,
    required this.buttonLabel,
    required this.onPressed,
    this.labelLine2Color,
    this.trailingIcon = Icons.chevron_right_rounded,
    this.minButtonWidth = 150,
  });

  final String labelLine1;
  final String labelLine2;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final Color? labelLine2Color;
  final IconData? trailingIcon;
  final double minButtonWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labelLine1,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labelLine2,
                      style: AppTextStyles.heading2.copyWith(
                        color: labelLine2Color ?? AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.border,
                  minimumSize: Size(minButtonWidth, 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  // Pin alignment so the label/icon centers match even
                  // when the parent's intrinsic height shifts (default
                  // Row centers fine on most pixel ratios but the gap
                  // can look off on devices with non-integer DPI).
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      buttonLabel,
                      style: AppTextStyles.buttonLabel.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.0,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 6),
                      Icon(trailingIcon, color: Colors.white, size: 20),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
