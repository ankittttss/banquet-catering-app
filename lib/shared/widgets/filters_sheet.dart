import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return SingleChildScrollView(
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
                TextButton.icon(
                  onPressed: notifier.reset,
                  icon: const Icon(PhosphorIconsBold.arrowCounterClockwise,
                      size: 14),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),

          // Dietary preference
          _SectionLabel('DIETARY PREFERENCE'),
          const SizedBox(height: AppSizes.sm),
          _VegOnlyCard(
            value: f.vegOnly,
            onToggle: () {
              HapticFeedback.selectionClick();
              notifier.toggleVeg();
            },
          ),

          const SizedBox(height: AppSizes.xl),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SectionLabel('MAX PRICE PER ITEM'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusPill),
                ),
                child: Text(
                  '\u20B9 ${f.maxPrice.toStringAsFixed(0)}',
                  style: AppTextStyles.captionBold
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: f.maxPrice,
              min: 50,
              max: 500,
              divisions: 9,
              onChanged: notifier.setMaxPrice,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\u20B9 50', style: AppTextStyles.caption),
              Text('\u20B9 500', style: AppTextStyles.caption),
            ],
          ),

          const SizedBox(height: AppSizes.xl),

          // Sort
          _SectionLabel('SORT BY'),
          const SizedBox(height: AppSizes.sm),
          _SortOption(
            label: 'Recommended',
            helper: 'Our pick for your event',
            icon: PhosphorIconsDuotone.sparkle,
            value: MenuSort.defaultOrder,
            current: f.sort,
            onPick: notifier.setSort,
          ),
          const SizedBox(height: AppSizes.xs),
          _SortOption(
            label: 'Price \u2014 low to high',
            helper: 'Budget-friendly first',
            icon: PhosphorIconsDuotone.sortAscending,
            value: MenuSort.priceAsc,
            current: f.sort,
            onPick: notifier.setSort,
          ),
          const SizedBox(height: AppSizes.xs),
          _SortOption(
            label: 'Price \u2014 high to low',
            helper: 'Premium dishes first',
            icon: PhosphorIconsDuotone.sortDescending,
            value: MenuSort.priceDesc,
            current: f.sort,
            onPick: notifier.setSort,
          ),

          const SizedBox(height: AppSizes.xl),
          PrimaryButton(
            label: 'Show results',
            icon: PhosphorIconsBold.checkCircle,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.overline);
  }
}

class _VegOnlyCard extends StatelessWidget {
  const _VegOnlyCard({required this.value, required this.onToggle});
  final bool value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: value
              ? AppColors.veg.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: value
                ? AppColors.veg.withValues(alpha: 0.6)
                : AppColors.border,
            width: value ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            _VegSymbol(active: value),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Veg only', style: AppTextStyles.bodyBold),
                  const SizedBox(height: 2),
                  Text('Hide non-vegetarian dishes',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: (_) => onToggle(),
              activeThumbColor: AppColors.veg,
            ),
          ],
        ),
      ),
    );
  }
}

class _VegSymbol extends StatelessWidget {
  const _VegSymbol({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.veg : AppColors.textMuted;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.helper,
    required this.icon,
    required this.value,
    required this.current,
    required this.onPick,
  });
  final String label;
  final String helper;
  final IconData icon;
  final MenuSort value;
  final MenuSort current;
  final ValueChanged<MenuSort> onPick;

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onPick(value);
      },
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyBold),
                  Text(helper, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (selected)
              const Icon(
                PhosphorIconsFill.checkCircle,
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
