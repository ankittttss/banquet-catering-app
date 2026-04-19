import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_scaffold.dart';

class DeliveryCompletedScreen extends StatelessWidget {
  const DeliveryCompletedScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.catGreenLt,
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsFill.confetti,
                  color: AppColors.success, size: 48),
            ).animate().scale(
                  duration: 400.ms,
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                ),
            const SizedBox(height: AppSizes.lg),
            Text('Delivery complete!', style: AppTextStyles.display)
                .animate()
                .fadeIn(delay: 150.ms, duration: 300.ms),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Order #$assignmentId delivered successfully',
              style: AppTextStyles.caption,
            ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
            const SizedBox(height: AppSizes.xl),
            Row(
              children: const [
                Expanded(
                  child: _Stat(
                    label: 'Earned',
                    value: '+₹85',
                    color: AppColors.success,
                    bg: AppColors.catGreenLt,
                  ),
                ),
                SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _Stat(
                    label: 'Distance',
                    value: '4.2 km',
                    color: AppColors.accent,
                    bg: AppColors.catGoldLt,
                  ),
                ),
                SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _Stat(
                    label: 'Duration',
                    value: '28 min',
                    color: AppColors.info,
                    bg: AppColors.catBlueLt,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 320.ms, duration: 350.ms),
            const SizedBox(height: AppSizes.xl),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.deliveryHome),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: Text(
                  'Go online for more orders',
                  style: AppTextStyles.buttonLabel
                      .copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: OutlinedButton(
                onPressed: () => context.go(AppRoutes.deliveryHome),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: Text('Back to home',
                    style: AppTextStyles.buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });
  final String label;
  final String value;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.displaySm.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.captionBold
                .copyWith(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
