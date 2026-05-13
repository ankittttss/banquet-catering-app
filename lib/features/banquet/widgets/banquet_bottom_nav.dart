import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../data/models/banquet_venue.dart';

/// Which of the four primary operator destinations is currently visible.
enum BanquetNavTab { home, bookings, venues, inventory }

/// Persistent 4-tab bottom navigation for the banquet operator role.
///
/// Plugged into each primary screen via `AppScaffold.bottomBar`. Drill-
/// down pages like the booking-detail screen deliberately omit it so
/// the action bar (Accept / Decline / Assign manager) stays the only
/// affordance at the bottom of the page.
///
/// Tapping a tab routes via `context.go(...)` so the back-stack stays
/// flat — switching between tabs doesn't accumulate Navigator pages.
class BanquetBottomNav extends ConsumerWidget {
  const BanquetBottomNav({super.key, required this.active});

  final BanquetNavTab active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(banquetInboxProvider);
    final pendingCount = inbox.valueOrNull
            ?.where((e) => e.status == BanquetEventStatus.pending)
            .length ??
        0;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: PhosphorIconsFill.house,
                  label: 'Home',
                  selected: active == BanquetNavTab.home,
                  onTap: () {
                    if (active == BanquetNavTab.home) return;
                    context.go(AppRoutes.banquetHome);
                  },
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIconsBold.tray,
                  label: 'Bookings',
                  selected: active == BanquetNavTab.bookings,
                  badge: pendingCount > 0 ? pendingCount : null,
                  onTap: () {
                    if (active == BanquetNavTab.bookings) return;
                    context.go(AppRoutes.banquetInbox);
                  },
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIconsBold.buildings,
                  label: 'Venues',
                  selected: active == BanquetNavTab.venues,
                  onTap: () {
                    if (active == BanquetNavTab.venues) return;
                    context.go(AppRoutes.banquetVenues);
                  },
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: PhosphorIconsBold.package,
                  label: 'Inventory',
                  selected: active == BanquetNavTab.inventory,
                  onTap: () {
                    if (active == BanquetNavTab.inventory) return;
                    context.go(AppRoutes.banquetInventory);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusPill),
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: AppTextStyles.captionBold.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
