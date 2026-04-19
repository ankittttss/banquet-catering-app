import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';

enum DeliveryNavTab { home, earnings, history, profile }

class DeliveryBottomNav extends StatelessWidget {
  const DeliveryBottomNav({super.key, required this.active});

  final DeliveryNavTab active;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
            child: Row(
              children: [
                Expanded(
                  child: _Item(
                    icon: PhosphorIconsFill.house,
                    label: 'Home',
                    selected: active == DeliveryNavTab.home,
                    onTap: () {
                      if (active == DeliveryNavTab.home) return;
                      context.go(AppRoutes.deliveryHome);
                    },
                  ),
                ),
                Expanded(
                  child: _Item(
                    icon: PhosphorIconsBold.currencyInr,
                    label: 'Earnings',
                    selected: active == DeliveryNavTab.earnings,
                    onTap: () {
                      if (active == DeliveryNavTab.earnings) return;
                      context.go(AppRoutes.deliveryEarnings);
                    },
                  ),
                ),
                Expanded(
                  child: _Item(
                    icon: PhosphorIconsBold.clockCounterClockwise,
                    label: 'History',
                    selected: active == DeliveryNavTab.history,
                    onTap: () {
                      if (active == DeliveryNavTab.history) return;
                      context.go(AppRoutes.deliveryHistory);
                    },
                  ),
                ),
                Expanded(
                  child: _Item(
                    icon: PhosphorIconsBold.userCircle,
                    label: 'Profile',
                    selected: active == DeliveryNavTab.profile,
                    onTap: () {
                      if (active == DeliveryNavTab.profile) return;
                      context.go(AppRoutes.deliveryProfile);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
