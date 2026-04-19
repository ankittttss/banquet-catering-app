import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';

class PickupChecklistScreen extends ConsumerStatefulWidget {
  const PickupChecklistScreen({super.key, required this.assignmentId});
  final String assignmentId;

  @override
  ConsumerState<PickupChecklistScreen> createState() => _State();
}

class _State extends ConsumerState<PickupChecklistScreen> {
  final _items = <_Item>[
    _Item('All items collected'),
    _Item('Packaging is sealed & intact'),
    _Item('Hot bag / insulation used'),
    _Item('Cutlery & napkins included'),
    _Item('Event setup items (plates, serving spoons)'),
  ];
  bool _busy = false;

  bool get _allChecked => _items.every((e) => e.checked);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Confirm pickup'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: AppSizes.lg),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.catGoldLt,
                borderRadius: BorderRadius.circular(AppSizes.radiusXl + 16),
              ),
              child: const Icon(PhosphorIconsFill.package,
                  color: AppColors.accent, size: 40),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Center(
            child: Text('Pickup checklist',
                style: AppTextStyles.displaySm),
          ),
          const SizedBox(height: AppSizes.xs),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSizes.xxxl),
            child: Text(
              'Verify these items before leaving the restaurant',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding),
            child: Column(
              children: [
                for (final item in _items)
                  _CheckRow(
                    item: item,
                    onTap: () =>
                        setState(() => item.checked = !item.checked),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding),
            child: SizedBox(
              height: AppSizes.buttonHeight,
              width: double.infinity,
              child: FilledButton(
                onPressed: (_allChecked && !_busy) ? _confirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor:
                      AppColors.success.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _busy
                          ? 'Saving…'
                          : 'Confirm pickup & start delivery',
                      style: AppTextStyles.buttonLabel
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Icon(PhosphorIconsBold.arrowRight,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xl),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    await ref
        .read(deliveryRepositoryProvider)
        .markPickedUp(widget.assignmentId);
    if (!mounted) return;
    context.pop();
  }
}

class _Item {
  _Item(this.label);
  final String label;
  bool checked = false;
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.item, required this.onTap});
  final _Item item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: item.checked
                    ? AppColors.success
                    : Colors.transparent,
                border: Border.all(
                  color: item.checked
                      ? AppColors.success
                      : AppColors.border,
                  width: 2,
                ),
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusXs + 2),
              ),
              child: item.checked
                  ? const Icon(PhosphorIconsBold.check,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(item.label, style: AppTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }
}
