import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final shortId = orderId.length > 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();

    return AppScaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsDuotone.checkCircle,
                color: AppColors.success,
                size: 72,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(),
            const SizedBox(height: AppSizes.xl),
            Text('Booking requested!', style: AppTextStyles.display)
                .animate()
                .fadeIn(delay: 300.ms),
            const SizedBox(height: AppSizes.sm),
            Text(
              'Your booking reference',
              style: AppTextStyles.bodyMuted,
            ).animate().fadeIn(delay: 380.ms),
            const SizedBox(height: AppSizes.xs),
            Text(
              '#$shortId',
              style: AppTextStyles.heading1
                  .copyWith(color: AppColors.primary, letterSpacing: 1.5),
            ).animate().fadeIn(delay: 430.ms),
            const SizedBox(height: AppSizes.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.xxl),
              child: Text(
                'Our team will reach out shortly to confirm your event and share payment details.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMuted,
              ),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: AppSizes.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'View my events',
                    icon: PhosphorIconsBold.calendarCheck,
                    onPressed: () => context.go(AppRoutes.myEvents),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  PrimaryButton(
                    label: 'Back to home',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => context.go(AppRoutes.userHome),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
