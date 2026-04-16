import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/constants/app_colors.dart';

/// Thin wrapper around [Skeletonizer] with banquet-tuned colors.
/// Usage: `AppSkeleton(loading: isLoading, child: ... real widget tree ...)`
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    required this.loading,
    required this.child,
    this.enableSwitchAnimation = true,
  });

  final bool loading;
  final Widget child;
  final bool enableSwitchAnimation;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: loading,
      enableSwitchAnimation: enableSwitchAnimation,
      effect: ShimmerEffect(
        baseColor: AppColors.surfaceAlt,
        highlightColor: AppColors.primarySoft,
        duration: const Duration(milliseconds: 1200),
      ),
      child: child,
    );
  }
}
