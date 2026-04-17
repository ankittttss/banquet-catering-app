import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/errors/app_exception.dart';
import 'primary_button.dart';

/// Standard way to render a failed [AsyncValue] / future error. Accepts a raw
/// error — will classify via [asAppException] and show the matching icon +
/// message + retry affordance.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Use inside small regions (cards, list placeholders). Default is a full
  /// centered illustration.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ex = asAppException(error);
    final (icon, title) = _presentation(ex);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          children: [
            Icon(icon, color: AppColors.error, size: 20),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(title,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.error)),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.error, size: 40),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(title,
                style: AppTextStyles.heading2,
                textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.sm),
            Text(ex.message,
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSizes.xl),
              PrimaryButton(
                label: 'Try again',
                icon: PhosphorIconsBold.arrowClockwise,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (IconData, String) _presentation(AppException ex) {
    return switch (ex) {
      NetworkException() => (
          PhosphorIconsDuotone.wifiSlash,
          'Can\u2019t reach the server',
        ),
      AuthRequiredException() => (
          PhosphorIconsDuotone.lock,
          'Please sign in',
        ),
      PermissionException() => (
          PhosphorIconsDuotone.shield,
          'Not allowed',
        ),
      ValidationException() => (
          PhosphorIconsDuotone.warning,
          'Check your input',
        ),
      UnknownException() => (
          PhosphorIconsDuotone.warningOctagon,
          'Something went wrong',
        ),
    };
  }
}
