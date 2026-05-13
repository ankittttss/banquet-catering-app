import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer.dart';
import '../widgets/banquet_bottom_nav.dart';

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
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(PhosphorIconsBold.arrowLeft),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('Equipment & inventory'),
      ),
      bottomBar: const BanquetBottomNav(active: BanquetNavTab.inventory),
      body: venues.when(
        loading: () => const _InventoryLoading(),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(myBanquetVenuesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _NoVenuesState();
          }
          _venueId ??= list.first.id;
          final selectedVenue = list.firstWhere(
            (v) => v.id == _venueId,
            orElse: () => list.first,
          );
          return Column(
            children: [
              const SizedBox(height: AppSizes.md),
              if (list.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.pagePadding,
                  ),
                  child: _VenueDropdown(
                    venues: list,
                    selectedId: selectedVenue.id,
                    onChanged: (id) => setState(() => _venueId = id),
                  ),
                ),
              Expanded(
                child: _InventoryList(
                  venueId: selectedVenue.id,
                  venueName: selectedVenue.name,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoVenuesState extends StatelessWidget {
  const _NoVenuesState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: PhosphorIconsDuotone.buildings,
      title: 'No venues yet',
      message:
          'Inventory is scoped per venue. Ask an admin to provision your first banquet venue.',
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
          icon: const Icon(
            Icons.expand_more_rounded,
            color: AppColors.textMuted,
          ),
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
  const _InventoryList({
    required this.venueId,
    required this.venueName,
  });

  final String venueId;
  final String venueName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(banquetInventoryProvider(venueId));
    return items.when(
      loading: () => const _InventoryLoading(),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(banquetInventoryProvider(venueId)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const _EmptyInventoryState();
        }
        final stats = _InventoryStats.from(rows);
        final groups = _groupInventory(rows);
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(banquetInventoryProvider(venueId));
            await ref.read(banquetInventoryProvider(venueId).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              _InventoryHero(venueName: venueName, stats: stats),
              const SizedBox(height: AppSizes.lg),
              for (final entry in groups.entries) ...[
                _InventoryGroup(
                  venueId: venueId,
                  category: entry.key,
                  items: entry.value,
                ),
                const SizedBox(height: AppSizes.lg),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InventoryHero extends StatelessWidget {
  const _InventoryHero({required this.venueName, required this.stats});

  final String venueName;
  final _InventoryStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primarySoft,
            AppColors.accentSoft,
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  PhosphorIconsBold.package,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venueName,
                      style: AppTextStyles.heading2.copyWith(fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pricing and availability for customer add-ons.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Active',
                  value: '${stats.activeCount}/${stats.totalCount}',
                  icon: PhosphorIconsBold.checkCircle,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _StatTile(
                  label: 'Per guest',
                  value: '${stats.perGuestCount}',
                  icon: PhosphorIconsDuotone.users,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: _StatTile(
                  label: 'Starting',
                  value: stats.startingPrice == null
                      ? '--'
                      : Formatters.currency(stats.startingPrice!),
                  icon: PhosphorIconsDuotone.currencyInr,
                  color: AppColors.accentDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: AppSizes.sm),
          Text(
            value,
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InventoryGroup extends StatelessWidget {
  const _InventoryGroup({
    required this.venueId,
    required this.category,
    required this.items,
  });

  final String venueId;
  final _InventoryCategory category;
  final List<BanquetInventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final active = items.where((i) => i.isActive).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Icon(category.icon, color: category.color, size: 18),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(category.label, style: AppTextStyles.heading2),
            ),
            Text(
              '$active active',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                _InventoryItemRow(venueId: venueId, item: items[i]),
                if (i != items.length - 1)
                  const Divider(color: AppColors.divider, height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InventoryItemRow extends ConsumerWidget {
  const _InventoryItemRow({
    required this.venueId,
    required this.item,
  });

  final String venueId;
  final BanquetInventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = _categoryFor(item.itemType);
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(category.icon, color: category.color, size: 21),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: AppTextStyles.bodyBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    _PriceChip(item: item),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Row(
                  children: [
                    _StatusChip(
                      label: item.isActive ? 'Active' : 'Hidden',
                      color:
                          item.isActive ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      item.perGuest ? 'Charged per guest' : 'Flat charge',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Switch(
            value: item.isActive,
            activeColor: AppColors.success,
            onChanged: (value) async {
              await ref.read(banquetRepositoryProvider).updateInventoryItem(
                    itemId: item.id,
                    unitPrice: item.unitPrice,
                    perGuest: item.perGuest,
                    isActive: value,
                  );
              ref.invalidate(banquetInventoryProvider(venueId));
            },
          ),
          IconButton(
            tooltip: 'Edit item',
            icon: const Icon(PhosphorIconsBold.pencilSimple, size: 18),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _EditInventorySheet(
                venueId: venueId,
                item: item,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditInventorySheet extends ConsumerStatefulWidget {
  const _EditInventorySheet({
    required this.venueId,
    required this.item,
  });

  final String venueId;
  final BanquetInventoryItem item;

  @override
  ConsumerState<_EditInventorySheet> createState() =>
      _EditInventorySheetState();
}

class _EditInventorySheetState extends ConsumerState<_EditInventorySheet> {
  late final TextEditingController _priceCtrl;
  late bool _perGuest;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
      text: widget.item.unitPrice.toStringAsFixed(0),
    );
    _perGuest = widget.item.perGuest;
    _isActive = widget.item.isActive;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceCtrl.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(banquetRepositoryProvider).updateInventoryItem(
            itemId: widget.item.id,
            unitPrice: price,
            perGuest: _perGuest,
            isActive: _isActive,
          );
      ref.invalidate(banquetInventoryProvider(widget.venueId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inventory item updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.pagePadding,
        AppSizes.pagePadding,
        AppSizes.pagePadding + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit inventory', style: AppTextStyles.displaySm),
          const SizedBox(height: AppSizes.xs),
          Text(widget.item.label, style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSizes.lg),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Unit price',
              prefixText: 'Rs ',
            ),
          ),
          const SizedBox(height: AppSizes.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _perGuest,
            onChanged: (v) => setState(() => _perGuest = v),
            title: Text('Charge per guest', style: AppTextStyles.bodyBold),
            subtitle: Text(
              _perGuest
                  ? 'Price multiplies by guest count.'
                  : 'Price applies once per booking.',
              style: AppTextStyles.caption,
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            title: Text('Visible to customers', style: AppTextStyles.bodyBold),
            subtitle: Text(
              _isActive
                  ? 'Customers can select this add-on.'
                  : 'Hidden from customer checkout.',
              style: AppTextStyles.caption,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsBold.check, size: 16),
              label: Text(_saving ? 'Saving...' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.item});

  final BanquetInventoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        item.perGuest
            ? '${Formatters.currency(item.unitPrice)}/guest'
            : '${Formatters.currency(item.unitPrice)} flat',
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.primary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(
          color: color,
          fontSize: 10,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _EmptyInventoryState extends StatelessWidget {
  const _EmptyInventoryState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: PhosphorIconsDuotone.package,
      title: 'No inventory items yet',
      message:
          'Seed setup packages, service staff, and consumables so customers can add them during checkout.',
    );
  }
}

class _InventoryLoading extends StatelessWidget {
  const _InventoryLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShimmerBox(
                    width: 46,
                    height: 46,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(width: AppSizes.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 170, height: 18),
                        SizedBox(height: 8),
                        ShimmerBox(width: 230, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              const Row(
                children: [
                  Expanded(child: ShimmerStatCard()),
                  SizedBox(width: AppSizes.sm),
                  Expanded(child: ShimmerStatCard()),
                  SizedBox(width: AppSizes.sm),
                  Expanded(child: ShimmerStatCard()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        for (var i = 0; i < 3; i++) ...[
          const ShimmerBox(width: 150, height: 16),
          const SizedBox(height: AppSizes.sm),
          const ShimmerBookingCard(),
          const SizedBox(height: AppSizes.lg),
        ],
      ],
    );
  }
}

class _InventoryStats {
  const _InventoryStats({
    required this.totalCount,
    required this.activeCount,
    required this.perGuestCount,
    required this.startingPrice,
  });

  final int totalCount;
  final int activeCount;
  final int perGuestCount;
  final double? startingPrice;

  factory _InventoryStats.from(List<BanquetInventoryItem> rows) {
    final active = rows.where((i) => i.isActive).toList(growable: false);
    double? minPrice;
    for (final item in active) {
      if (minPrice == null || item.unitPrice < minPrice) {
        minPrice = item.unitPrice;
      }
    }
    return _InventoryStats(
      totalCount: rows.length,
      activeCount: active.length,
      perGuestCount: rows.where((i) => i.perGuest).length,
      startingPrice: minPrice,
    );
  }
}

class _InventoryCategory {
  const _InventoryCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

Map<_InventoryCategory, List<BanquetInventoryItem>> _groupInventory(
  List<BanquetInventoryItem> rows,
) {
  final grouped = <String, List<BanquetInventoryItem>>{};
  for (final item in rows) {
    final category = _categoryFor(item.itemType);
    grouped.putIfAbsent(category.key, () => <BanquetInventoryItem>[]).add(item);
  }
  final result = <_InventoryCategory, List<BanquetInventoryItem>>{};
  for (final key in ['setup', 'service', 'consumables', 'other']) {
    final items = grouped[key];
    if (items == null || items.isEmpty) continue;
    result[_categoryForKey(key)] = items;
  }
  return result;
}

_InventoryCategory _categoryFor(String itemType) {
  if (itemType.contains('setup')) return _categoryForKey('setup');
  if (itemType.contains('service')) return _categoryForKey('service');
  if (itemType.contains('water') || itemType.contains('bottle')) {
    return _categoryForKey('consumables');
  }
  return _categoryForKey('other');
}

_InventoryCategory _categoryForKey(String key) {
  switch (key) {
    case 'setup':
      return const _InventoryCategory(
        key: 'setup',
        label: 'Setup packages',
        icon: PhosphorIconsDuotone.package,
        color: AppColors.primary,
      );
    case 'service':
      return const _InventoryCategory(
        key: 'service',
        label: 'Service staff',
        icon: PhosphorIconsDuotone.users,
        color: AppColors.info,
      );
    case 'consumables':
      return const _InventoryCategory(
        key: 'consumables',
        label: 'Consumables',
        icon: PhosphorIconsDuotone.drop,
        color: AppColors.success,
      );
    default:
      return const _InventoryCategory(
        key: 'other',
        label: 'Other add-ons',
        icon: PhosphorIconsDuotone.handshake,
        color: AppColors.accentDark,
      );
  }
}
