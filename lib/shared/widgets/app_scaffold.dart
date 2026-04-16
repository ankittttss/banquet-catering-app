import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

/// Scaffold with consistent page padding + optional bottom sheet/footer area.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomBar,
    this.floatingActionButton,
    this.padded = true,
    this.backgroundColor,
    this.safeBottom = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final bool padded;
  final Color? backgroundColor;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (padded) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.pageBg,
      appBar: appBar,
      body: SafeArea(
        top: appBar == null,
        bottom: safeBottom && bottomBar == null,
        child: content,
      ),
      bottomNavigationBar: bottomBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
