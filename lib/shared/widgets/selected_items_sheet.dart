import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/restaurant.dart';
import '../providers/cart_providers.dart';
import '../providers/event_providers.dart';
import '../providers/menu_providers.dart';

/// Shows the "selected items" popup — a quick, grouped-by-restaurant view of
/// everything currently in the cart, with inline quantity + remove controls.
/// Used on menu-like screens so the user can see and edit their selection
/// without leaving the page. Auto-dismisses when the cart becomes empty.
Future<void> showSelectedItemsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SelectedItemsSheet(),
  );
}

class _SelectedItemsSheet extends ConsumerWidget {
  const _SelectedItemsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(cartVendorGroupsProvider);
    final count = ref.watch(cartCountProvider);
    // Guest-scaled total so the popup matches the cart's item total.
    final total = ref.watch(cartBilledFoodTotalProvider);
    final guests = ref.watch(eventDraftProvider).guestCount;
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];

    // Close automatically once the last item is removed.
    if (groups.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    Restaurant? restaurantById(String id) {
      for (final r in restaurants) {
        if (r.id == id) return r;
      }
      return null;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.md, AppSizes.sm, AppSizes.sm, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: [
                        Text('Selected items', style: AppTextStyles.heading2),
                        const SizedBox(width: AppSizes.xs),
                        Text(
                          '$count ${count == 1 ? 'item' : 'items'}',
                          style: AppTextStyles.bodyMuted,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                      AppSizes.md, AppSizes.sm, AppSizes.md, AppSizes.md),
                  children: [
                    for (final g in groups) ...[
                      _GroupHeader(
                        name: restaurantById(g.restaurantId)?.name ?? 'Kitchen',
                        emoji:
                            restaurantById(g.restaurantId)?.heroEmoji ?? '🍽️',
                        lineCount: g.lineCount,
                      ),
                      for (final line in g.lines)
                        _SelectedLine(line: line, guestCount: guests),
                      const SizedBox(height: AppSizes.md),
                    ],
                  ],
                ),
              ),
              _Footer(total: total, guestCount: guests),
            ],
          ),
        );
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.name,
    required this.emoji,
    required this.lineCount,
  });
  final String name;
  final String emoji;
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.sm, bottom: AppSizes.xs),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSizes.xs),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyBold,
            ),
          ),
          Text(
            '$lineCount ${lineCount == 1 ? 'dish' : 'dishes'}',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _SelectedLine extends ConsumerWidget {
  const _SelectedLine({required this.line, required this.guestCount});
  final CartItem line;
  final int guestCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final isVeg = line.item.isVeg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _VegDot(isVeg: isVeg),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (line.portion != Portion.regular ||
                    line.notes.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (line.portion != Portion.regular) line.portion.label,
                        if (line.notes.trim().isNotEmpty) line.notes.trim(),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.currency(line.perGuestLineCost)}/guest'
                  ' × $guestCount',
                  style: AppTextStyles.caption,
                ),
                Text(
                  Formatters.currency(line.billedLineTotal(guestCount)),
                  style: AppTextStyles.captionBold
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          _QtyStepper(
            qty: line.qty,
            onMinus: () {
              HapticFeedback.selectionClick();
              notifier.bumpLine(line.signature, -1);
            },
            onPlus: () {
              HapticFeedback.selectionClick();
              notifier.bumpLine(line.signature, 1);
            },
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: AppColors.textMuted),
            onPressed: () {
              HapticFeedback.selectionClick();
              notifier.removeLine(line.signature);
            },
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepCell(icon: Icons.remove_rounded, onTap: onMinus),
          SizedBox(
            width: 26,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyBold,
            ),
          ),
          _StepCell(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepCell extends StatelessWidget {
  const _StepCell({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _VegDot extends StatelessWidget {
  const _VegDot({required this.isVeg});
  final bool? isVeg;

  @override
  Widget build(BuildContext context) {
    if (isVeg == null) return const SizedBox(width: 12);
    final color = isVeg! ? AppColors.success : AppColors.primary;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.total, required this.guestCount});
  final double total;
  final int guestCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Items subtotal · $guestCount '
                  '${guestCount == 1 ? 'guest' : 'guests'}',
                  style: AppTextStyles.caption,
                ),
                Text(
                  Formatters.currency(total),
                  style: AppTextStyles.heading2,
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.cart);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Go to cart',
                    style:
                        AppTextStyles.buttonLabel.copyWith(color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
