import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../providers/filters_providers.dart';
import 'primary_button.dart';

void showFiltersSheet(BuildContext context) {
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
    builder: (_) => const _FiltersSheet(),
  );
}

class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(menuFiltersProvider);
    final notifier = ref.read(menuFiltersProvider.notifier);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        0,
        AppSizes.pagePadding,
        MediaQuery.of(context).viewInsets.bottom + AppSizes.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Filters', style: AppTextStyles.heading1),
              const Spacer(),
              if (f.isActive)
                TextButton(
                  onPressed: notifier.reset,
                  child: Text('Clear all',
                      style: AppTextStyles.bodyBold
                          .copyWith(color: AppColors.error)),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Text('PREFERENCE', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          SwitchListTile.adaptive(
            value: f.vegOnly,
            onChanged: (_) => notifier.toggleVeg(),
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.veg, width: 1.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.veg,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Text('Veg only', style: AppTextStyles.bodyBold),
              ],
            ),
            subtitle: const Text('Show only vegetarian dishes'),
          ),
          const Divider(height: AppSizes.xl),
          Text('MAX PRICE', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Text('\u20B9 0', style: AppTextStyles.caption),
              Expanded(
                child: Slider(
                  value: f.maxPrice,
                  min: 50,
                  max: 500,
                  divisions: 9,
                  activeColor: AppColors.primary,
                  label: '\u20B9${f.maxPrice.toStringAsFixed(0)}',
                  onChanged: notifier.setMaxPrice,
                ),
              ),
              Text('\u20B9 ${f.maxPrice.toStringAsFixed(0)}',
                  style: AppTextStyles.bodyBold),
            ],
          ),
          const Divider(height: AppSizes.xl),
          Text('SORT BY', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            children: [
              _sortChip('Default', MenuSort.defaultOrder, f, notifier,
                  PhosphorIconsBold.sparkle),
              _sortChip('Price: low → high', MenuSort.priceAsc, f, notifier,
                  PhosphorIconsBold.sortAscending),
              _sortChip('Price: high → low', MenuSort.priceDesc, f, notifier,
                  PhosphorIconsBold.sortDescending),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
          PrimaryButton(
            label: 'Apply filters',
            icon: PhosphorIconsBold.checkCircle,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, MenuSort value, MenuFilters current,
      MenuFiltersController notifier, IconData icon) {
    final sel = current.sort == value;
    return InkWell(
      onTap: () => notifier.setSort(value),
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: sel ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: sel ? Colors.white : AppColors.textPrimary),
            const SizedBox(width: AppSizes.xs),
            Text(label,
                style: AppTextStyles.bodyBold.copyWith(
                  color: sel ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                )),
          ],
        ),
      ),
    );
  }
}
