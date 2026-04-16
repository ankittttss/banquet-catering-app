import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router/app_routes.dart';
import '../providers/cart_providers.dart';
import '../providers/home_providers.dart';
import '../providers/event_providers.dart';

enum UserNavTab { home, events, profile }

/// Bottom nav with center FAB + cart count badge.
class UserBottomNav extends ConsumerWidget {
  const UserBottomNav({super.key, required this.active});

  final UserNavTab active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: PhosphorIconsFill.house,
                        label: 'Home',
                        selected: active == UserNavTab.home,
                        onTap: () {
                          if (active == UserNavTab.home) return;
                          context.go(AppRoutes.userHome);
                        },
                        badge: cartCount > 0 ? cartCount : null,
                      ),
                    ),
                    const SizedBox(width: 56),
                    Expanded(
                      child: _NavItem(
                        icon: PhosphorIconsBold.calendarCheck,
                        label: 'Events',
                        selected: active == UserNavTab.events,
                        onTap: () {
                          if (active == UserNavTab.events) return;
                          context.go(AppRoutes.myEvents);
                        },
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: PhosphorIconsBold.userCircle,
                        label: 'Profile',
                        selected: active == UserNavTab.profile,
                        onTap: () {
                          if (active == UserNavTab.profile) return;
                          context.go(AppRoutes.profile);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -22,
                child: _CenterFab(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _openQuickPicker(context, ref);
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

void _openQuickPicker(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXl),
      ),
    ),
    builder: (ctx) {
      final types = ref.read(eventTypesProvider);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          AppSizes.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What are you planning?',
                style: AppTextStyles.heading1),
            const SizedBox(height: AppSizes.xs),
            Text('Pick a type — we\'ll pre-fill the rest.',
                style: AppTextStyles.bodyMuted),
            const SizedBox(height: AppSizes.lg),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: types.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSizes.md,
                mainAxisSpacing: AppSizes.md,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (_, i) {
                final t = types[i];
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(eventDraftProvider.notifier)
                        .setSession(t.defaultSession);
                    ref
                        .read(eventDraftProvider.notifier)
                        .setGuestCount(t.defaultGuestCount);
                    Navigator.of(ctx).pop();
                    context.push(AppRoutes.eventDetails);
                  },
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusLg),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusLg),
                      border: Border.all(
                        color: t.color.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.icon, color: t.color, size: 28),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          t.label,
                          style: AppTextStyles.captionBold
                              .copyWith(color: AppColors.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _CenterFab extends StatelessWidget {
  const _CenterFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: AppColors.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.surface, width: 4),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.36),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            PhosphorIconsBold.plus,
            color: Colors.white,
            size: 24,
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
    final color = selected ? AppColors.primary : AppColors.textSecondary;
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
                Icon(icon, color: color, size: 22),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusPill),
                        border: Border.all(
                            color: AppColors.surface, width: 1.5),
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
            const SizedBox(height: 2),
            Text(label,
                style:
                    AppTextStyles.captionBold.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
