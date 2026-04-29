import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// Equipment + supplies the banquet sells on top of food cost
/// (water bottles, setup packages, premium service staff, etc.).
/// Scoped per venue — each venue has its own catalog.
class BanquetInventoryScreen extends ConsumerStatefulWidget {
  const BanquetInventoryScreen({super.key});

  @override
  ConsumerState<BanquetInventoryScreen> createState() =>
      _BanquetInventoryScreenState();
}

class _BanquetInventoryScreenState
    extends ConsumerState<BanquetInventoryScreen> {
  String? _venueId;

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(myBanquetVenuesProvider);
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Equipment & inventory'),
      ),
      body: venues.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load venues: $e',
              style: AppTextStyles.caption),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: Text(
                  'No venues yet. Inventory is scoped per venue.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMuted,
                ),
              ),
            );
          }
          // Default to the first venue once loaded.
          _venueId ??= list.first.id;
          final selectedVenue =
              list.firstWhere((v) => v.id == _venueId, orElse: () => list.first);
          return Column(
            children: [
              const SizedBox(height: AppSizes.md),
              if (list.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pagePadding),
                  child: _VenueDropdown(
                    venues: list,
                    selectedId: selectedVenue.id,
                    onChanged: (id) => setState(() => _venueId = id),
                  ),
                ),
              Expanded(child: _InventoryList(venueId: selectedVenue.id)),
            ],
          );
        },
      ),
    );
  }
}

class _VenueDropdown extends StatelessWidget {
  const _VenueDropdown({
    required this.venues,
    required this.selectedId,
    required this.onChanged,
  });
  final List<BanquetVenue> venues;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded,
              color: AppColors.textMuted),
          items: [
            for (final v in venues)
              DropdownMenuItem(
                value: v.id,
                child: Text(v.name, style: AppTextStyles.body),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _InventoryList extends ConsumerWidget {
  const _InventoryList({required this.venueId});
  final String venueId;

  IconData _iconFor(String itemType) {
    switch (itemType) {
      case 'water_bottle':
        return PhosphorIconsDuotone.drop;
      case 'setup_basic':
      case 'setup_premium':
        return PhosphorIconsDuotone.package;
      case 'service_premium':
      case 'service_boy':
        return PhosphorIconsDuotone.users;
      default:
        return PhosphorIconsDuotone.handshake;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(banquetInventoryProvider(venueId));
    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          Center(child: Text('Could not load inventory: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsDuotone.package,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: AppSizes.md),
                  Text('No inventory items yet',
                      style: AppTextStyles.heading3),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'An admin can seed water bottles, setup packages, and service staff charges for this venue.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
          itemBuilder: (_, i) {
            final item = rows[i];
            return AppCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(_iconFor(item.itemType),
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.label, style: AppTextStyles.bodyBold),
                        const SizedBox(height: 2),
                        Text(
                          item.perGuest
                              ? '${Formatters.currency(item.unitPrice)} per guest'
                              : '${Formatters.currency(item.unitPrice)} flat',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (!item.isActive)
                    Text('Inactive',
                        style: AppTextStyles.captionBold
                            .copyWith(color: AppColors.textMuted)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
