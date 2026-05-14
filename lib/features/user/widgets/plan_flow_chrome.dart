import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';

/// Sticky header used across the 3-step plan-your-event flow. Renders the
/// back button, screen title, "Step N of 3 · Label", and a 3-segment
/// progress bar that fills based on [step].
class PlanFlowHeader extends StatelessWidget {
  const PlanFlowHeader({
    super.key,
    required this.title,
    required this.step,
    required this.stepLabel,
    this.subtitleOverride,
  });

  final String title;
  final int step;
  final String stepLabel;
  /// When set, replaces the default "Step N of 3 · {stepLabel}" line —
  /// used by sub-screens that aren't a top-level step (e.g. the recce
  /// booking, which is auxiliary to the main flow).
  final String? subtitleOverride;

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
                onTap: () => context.canPop()
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
                      subtitleOverride ?? 'Step $step of 3 · $stepLabel',
                      style:
                          AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              for (var i = 1; i <= 3; i++) ...[
                if (i > 1) const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.14),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                    ),
                  ),
                ),
              ],
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
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusMd),
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
