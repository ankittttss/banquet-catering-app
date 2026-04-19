import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/user_address.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../widgets/address_search_sheet.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Saved addresses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.profile),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: () => _openEditor(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load addresses',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(addressesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.location_on_rounded,
              title: 'No saved addresses',
              message:
                  'Add your home, work, or venue addresses to speed up checkout.',
              actionLabel: 'Add address',
              onAction: () => _openEditor(context, ref),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
            children: [
              for (int i = 0; i < list.length; i++)
                _AddressRow(
                  address: list[i],
                  onEdit: () => _openEditor(context, ref, existing: list[i]),
                  onDelete: () => _confirmDelete(context, ref, list[i]),
                  onSetDefault: () async {
                    HapticFeedback.selectionClick();
                    await _setDefault(ref, list[i]);
                  },
                ).animate().fadeIn(duration: 220.ms, delay: (30 * i).ms),
              const SizedBox(height: AppSizes.lg),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding,
                ),
                child: OutlinedButton.icon(
                  onPressed: () => _openEditor(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add new address'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _setDefault(WidgetRef ref, UserAddress a) async {
    try {
      await ref.read(addressRepositoryProvider).setDefault(a.userId, a.id);
      ref.invalidate(addressesProvider);
    } catch (_) {
      // ignore — UI reflects last successful state
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    UserAddress a,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove address?'),
        content: Text(a.fullAddress),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(addressRepositoryProvider).delete(a.id);
      ref.invalidate(addressesProvider);
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    UserAddress? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      builder: (_) => _Editor(existing: existing),
    );
    ref.invalidate(addressesProvider);
  }
}

// ───────────────────────── Address row ─────────────────────────

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onSetDefault,
  });

  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  (IconData, Color, Color) _iconStyle() {
    switch (address.label) {
      case AddressLabel.home:
        return (Icons.home_rounded, AppColors.primarySoft, AppColors.primary);
      case AddressLabel.work:
        return (
          Icons.business_rounded,
          AppColors.catBlueLt,
          AppColors.catBlue,
        );
      case AddressLabel.other:
        return (
          Icons.location_on_rounded,
          AppColors.surfaceAlt,
          AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _iconStyle();
    return InkWell(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(address.label.label,
                          style: AppTextStyles.bodyBold),
                      if (address.isDefault) ...[
                        const SizedBox(width: AppSizes.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusXs),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: AppTextStyles.captionBold.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address.fullAddress,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                  if (!address.isDefault) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: onSetDefault,
                      child: Text(
                        'Set as default',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textMuted, size: 20),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Editor bottom-sheet ─────────────────────────

class _Editor extends ConsumerStatefulWidget {
  const _Editor({this.existing});
  final UserAddress? existing;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late AddressLabel _label;
  late TextEditingController _addrCtrl;
  bool _isDefault = false;
  bool _saving = false;

  // Coordinates from the Photon picker — kept separately so we don't lose
  // them if the user tweaks the address text afterwards (e.g. adding house
  // number, landmark).
  double? _lat;
  double? _lng;
  String? _shortLabel;

  @override
  void initState() {
    super.initState();
    _label = widget.existing?.label ?? AddressLabel.home;
    _addrCtrl =
        TextEditingController(text: widget.existing?.fullAddress ?? '');
    _isDefault = widget.existing?.isDefault ?? false;
    _lat = widget.existing?.latitude;
    _lng = widget.existing?.longitude;
    _shortLabel = widget.existing?.shortLabel;
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    super.dispose();
  }

  Future<void> _openSearch() async {
    final result = await AddressSearchSheet.show(context);
    if (result == null || !mounted) return;
    setState(() {
      _addrCtrl.text = result.displayAddress;
      _lat = result.latitude;
      _lng = result.longitude;
      _shortLabel = result.shortLabel;
    });
  }

  Future<void> _save() async {
    final txt = _addrCtrl.text.trim();
    if (txt.length < 3) return;
    setState(() => _saving = true);
    try {
      await ref.read(addressRepositoryProvider).save(
            UserAddressInput(
              id: widget.existing?.id,
              label: _label,
              fullAddress: txt,
              isDefault: _isDefault,
              latitude: _lat,
              longitude: _lng,
              shortLabel: _shortLabel,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.pagePadding,
        right: AppSizes.pagePadding,
        top: AppSizes.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'Add address' : 'Edit address',
            style: AppTextStyles.heading1,
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            children: [
              for (final l in AddressLabel.values)
                ChoiceChip(
                  label: Text(l.label),
                  selected: _label == l,
                  onSelected: (_) => setState(() => _label = l),
                  selectedColor: AppColors.primarySoft,
                  backgroundColor: AppColors.surfaceAlt,
                  side: BorderSide(
                    color: _label == l
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  labelStyle: AppTextStyles.captionBold.copyWith(
                    color: _label == l
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          OutlinedButton.icon(
            onPressed: _openSearch,
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: AppColors.primary,
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md, vertical: AppSizes.md),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusSm),
              ),
            ),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text(
              _lat == null
                  ? 'Search an address'
                  : 'Change searched address',
              style: AppTextStyles.captionBold
                  .copyWith(color: AppColors.primary),
            ),
          ),
          if (_lat != null && _shortLabel != null) ...[
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                const Icon(Icons.place_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Pinned: $_shortLabel',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.success),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          TextField(
            controller: _addrCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'House / flat, street, city, PIN',
              hintStyle:
                  AppTextStyles.body.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            title: Text('Set as default',
                style: AppTextStyles.body.copyWith(fontSize: 13)),
          ),
          const SizedBox(height: AppSizes.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    widget.existing == null ? 'Add address' : 'Save',
                    style: AppTextStyles.buttonLabel
                        .copyWith(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
