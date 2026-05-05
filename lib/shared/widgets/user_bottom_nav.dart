import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../providers/cart_providers.dart';

enum UserNavTab { home, events, cart, orders, profile }

/// 5-tab bottom nav — Zomato-style. Inline cart-peek banner appears
/// above the bar whenever the cart has items.
class UserBottomNav extends ConsumerWidget {
  const UserBottomNav({super.key, required this.active});

  final UserNavTab active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartCountProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cartCount > 0 && active != UserNavTab.cart) const _InlineCartPeek(),
        _NavBar(active: active, cartCount: cartCount),
      ],
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.active, required this.cartCount});

  final UserNavTab active;
  final int cartCount;

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
                  child: _NavItem(
                    icon: PhosphorIconsFill.house,
                    label: 'Home',
                    selected: active == UserNavTab.home,
                    onTap: () {
                      if (active == UserNavTab.home) return;
                      context.go(AppRoutes.userHome);
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: PhosphorIconsBold.confetti,
                    label: 'Events',
                    selected: active == UserNavTab.events,
                    onTap: () {
                      if (active == UserNavTab.events) return;
                      context.push(AppRoutes.eventDetails);
                    },
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: PhosphorIconsBold.shoppingBag,
                    label: 'Cart',
                    selected: active == UserNavTab.cart,
                    onTap: () {
                      if (active == UserNavTab.cart) return;
                      context.push(AppRoutes.cart);
                    },
                    badge: cartCount > 0 ? cartCount : null,
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: PhosphorIconsBold.receipt,
                    label: 'Orders',
                    selected: active == UserNavTab.orders,
                    onTap: () {
                      if (active == UserNavTab.orders) return;
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

class _InlineCartPeek extends ConsumerWidget {
  const _InlineCartPeek();

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard cart?'),
        content: const Text('This will remove all items from your cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider);
    final total = ref.watch(cartFoodTotalProvider);
    final kitchens = ref
        .watch(cartProvider)
        .map((c) => c.item.restaurantId)
        .toSet()
        .length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(AppRoutes.cart),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.md,
            AppSizes.sm,
            AppSizes.md,
            AppSizes.sm,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(
                  PhosphorIconsFill.shoppingBag,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'item' : 'items'}'
                  '${kitchens > 1 ? ' · $kitchens kitchens' : ''} · '
                  '${Formatters.currency(total)}',
                  style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Primary CTA — solid white pill so "View cart" reads as the
              // unmistakable main action.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'View cart',
                  style: AppTextStyles.captionBold
                      .copyWith(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              // Secondary discard control — visually detached via a darker
              // bubble + smaller icon so it can't be mistaken for the
              // primary CTA. Inner InkWell consumes the tap before it
              // reaches the outer "open cart" gesture.
              Tooltip(
                message: 'Discard cart',
                child: InkWell(
                  onTap: () => _confirmDiscard(context, ref),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIconsBold.x,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
