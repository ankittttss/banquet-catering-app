import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/user_address.dart';
import '../../../shared/providers/address_providers.dart';

/// Bottom sheet: shows saved addresses + "Add new address" CTA.
/// Tapping a saved address flips [selectedAddressIdProvider], which
/// re-runs the home's nearby-restaurants query.
class AddressPickerSheet extends ConsumerWidget {
  const AddressPickerSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddressPickerSheet._(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider).valueOrNull ?? const [];
    final selected = ref.watch(activeAddressProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Text('Deliver to', style: AppTextStyles.heading1),
            const SizedBox(height: AppSizes.md),
            if (addresses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                child: Text(
                  'No saved addresses yet. Add one to get restaurants in your area.',
                  style: AppTextStyles.caption,
                ),
              )
            else
              for (final a in addresses)
                _Tile(
                  addr: a,
                  active: selected?.id == a.id,
                  onTap: () {
                    ref
                        .read(selectedAddressIdProvider.notifier)
                        .state = a.id;
                    Navigator.of(context).pop();
                  },
                ),
            const SizedBox(height: AppSizes.sm),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.addresses);
              },
              icon: const Icon(PhosphorIconsBold.plus, size: 16),
              label: const Text('Add a new address'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.md),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.addr,
    required this.active,
    required this.onTap,
  });
  final UserAddress addr;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: active ? AppColors.primarySoft : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Icon(
                    _iconFor(addr.label),
                    color: active ? Colors.white : AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(addr.label.label,
                              style: AppTextStyles.bodyBold),
                          if (addr.isDefault) ...[
                            const SizedBox(width: AppSizes.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.catGreenLt,
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Default',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.success,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        addr.shortLabel ?? addr.fullAddress,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (active)
                  const Icon(PhosphorIconsFill.checkCircle,
                      color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(AddressLabel l) => switch (l) {
        AddressLabel.home => PhosphorIconsFill.house,
        AddressLabel.work => PhosphorIconsFill.briefcase,
        AddressLabel.other => PhosphorIconsFill.mapPin,
      };
}
