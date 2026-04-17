import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/menu_item.dart';
import '../providers/cart_providers.dart';
import 'menu_item_thumb.dart';
import 'primary_button.dart';
import 'veg_dot.dart';

/// Bottom sheet that lets the user pick portion / spice / add a note before
/// adding the item to the cart. Shows a live price preview.
Future<void> showMenuItemCustomizeSheet(
  BuildContext context, {
  required MenuItem item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXl),
      ),
    ),
    builder: (ctx) => _CustomizeBody(item: item),
  );
}

class _CustomizeBody extends ConsumerStatefulWidget {
  const _CustomizeBody({required this.item});
  final MenuItem item;

  @override
  ConsumerState<_CustomizeBody> createState() => _CustomizeBodyState();
}

class _CustomizeBodyState extends ConsumerState<_CustomizeBody> {
  Portion _portion = Portion.regular;
  SpiceLevel _spice = SpiceLevel.medium;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _unitPrice => widget.item.price * _portion.multiplier;

  void _addToCart() {
    HapticFeedback.lightImpact();
    ref.read(cartProvider.notifier).add(
          widget.item,
          customization: CartCustomization(
            portion: _portion,
            spice: _spice,
            notes: _notesCtrl.text.trim(),
          ),
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.item.name} added to cart'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MenuItemThumb(
                  name: item.name,
                  imageUrl: item.imageUrl,
                  isVeg: item.isVeg,
                  size: 72,
                  showVegDot: false,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          VegDot(isVeg: item.isVeg),
                          const SizedBox(width: AppSizes.xs + 2),
                          Expanded(
                            child: Text(item.name,
                                style: AppTextStyles.heading2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 2),
                        Text(item.description!,
                            style: AppTextStyles.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xl),
            _Section(title: 'PORTION'),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final p in Portion.values)
                  _Choice(
                    label: p.label,
                    trailing: p == Portion.regular
                        ? null
                        : '+${((p.multiplier - 1) * 100).toStringAsFixed(0)}%',
                    selected: _portion == p,
                    onTap: () => setState(() => _portion = p),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.xl),
            _Section(title: 'SPICE LEVEL'),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final s in SpiceLevel.values)
                  _Choice(
                    label: s.label,
                    selected: _spice == s,
                    onTap: () => setState(() => _spice = s),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.xl),
            _Section(title: 'NOTES FOR THE KITCHEN'),
            const SizedBox(height: AppSizes.sm),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              minLines: 2,
              maxLength: 140,
              decoration: const InputDecoration(
                hintText: 'e.g. less oil, no onions, serve cold',
                prefixIcon: Icon(PhosphorIconsBold.note),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UNIT PRICE', style: AppTextStyles.overline),
                      const SizedBox(height: 2),
                      Text(Formatters.currency(_unitPrice),
                          style: AppTextStyles.totalAmount.copyWith(
                            fontSize: 22,
                            color: AppColors.primary,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                PrimaryButton(
                  label: 'Add to cart',
                  icon: PhosphorIconsBold.plus,
                  onPressed: _addToCart,
                  expand: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) =>
      Text(title, style: AppTextStyles.overline);
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSizes.xs),
              Text(
                trailing!,
                style: AppTextStyles.captionBold.copyWith(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.accentDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
