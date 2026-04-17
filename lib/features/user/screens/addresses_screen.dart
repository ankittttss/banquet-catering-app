import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/user_address.dart';
import '../../../shared/presentation/address_label_presentation.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/status_badge.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(addressesProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
            error: e, onRetry: () => ref.invalidate(addressesProvider)),
        data: (addresses) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              const SizedBox(height: AppSizes.sm),
              if (addresses.isEmpty)
                const SizedBox(
                  height: 360,
                  child: EmptyState(
                    title: 'No saved addresses',
                    message:
                        'Save your home, work and other venues — reuse them when planning events.',
                    icon: Icons.place_outlined,
                  ),
                )
              else
                for (int i = 0; i < addresses.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.md),
                    child: _AddressTile(address: addresses[i])
                        .animate(delay: (i * 60).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.06, end: 0),
                  ),
            ],
          );
        },
      ),
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: PrimaryButton(
            label: 'Add new address',
            icon: PhosphorIconsBold.plusCircle,
            onPressed: () => _openEditor(context, ref, null),
          ),
        ),
      ),
    );
  }
}

Future<void> _openEditor(
    BuildContext context, WidgetRef ref, UserAddress? existing) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXl),
      ),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _AddressEditor(existing: existing),
    ),
  );
}

class _AddressTile extends ConsumerWidget {
  const _AddressTile({required this.address});
  final UserAddress address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => _openEditor(context, ref, address),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(address.label.icon,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(address.label.label,
                            style: AppTextStyles.heading3),
                        if (address.isDefault) ...[
                          const SizedBox(width: AppSizes.sm),
                          const StatusBadge(
                            label: 'DEFAULT',
                            tone: StatusTone.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.fullAddress,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(PhosphorIconsBold.trash,
                    size: 20, color: AppColors.error),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          if (!address.isDefault) ...[
            const Divider(height: AppSizes.xl),
            TextButton.icon(
              onPressed: () async {
                await ref
                    .read(addressRepositoryProvider)
                    .setDefault(address.userId, address.id);
                ref.invalidate(addressesProvider);
              },
              icon: const Icon(PhosphorIconsBold.star, size: 16),
              label: const Text('Make default'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(address.fullAddress),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(addressRepositoryProvider).delete(address.id);
    ref.invalidate(addressesProvider);
  }
}

// ---------------------------------------------------------------------------

class _AddressEditor extends ConsumerStatefulWidget {
  const _AddressEditor({required this.existing});
  final UserAddress? existing;

  @override
  ConsumerState<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends ConsumerState<_AddressEditor> {
  late AddressLabel _label;
  late TextEditingController _addressCtrl;
  late bool _isDefault;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _label = widget.existing?.label ?? AddressLabel.home;
    _addressCtrl =
        TextEditingController(text: widget.existing?.fullAddress ?? '');
    _isDefault = widget.existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_addressCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(addressRepositoryProvider);
      await repo.save(UserAddressInput(
        id: widget.existing?.id,
        label: _label,
        fullAddress: _addressCtrl.text.trim(),
        isDefault: _isDefault,
      ));
      ref.invalidate(addressesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.lg,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isNew ? 'Add address' : 'Edit address',
              style: AppTextStyles.heading1),
          const SizedBox(height: AppSizes.lg),
          Text('LABEL', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            children: [
              for (final l in AddressLabel.values)
                ChoiceChip(
                  label: Text(l.label),
                  selected: _label == l,
                  onSelected: (_) => setState(() => _label = l),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Text('ADDRESS', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          TextField(
            controller: _addressCtrl,
            maxLines: 3,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: 'House / street / city / pincode',
              prefixIcon: Icon(PhosphorIconsBold.mapPin),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          SwitchListTile.adaptive(
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
            title: const Text('Set as default address'),
            subtitle: const Text('Pre-filled when planning a new event'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSizes.lg),
          PrimaryButton(
            label: isNew ? 'Save address' : 'Save changes',
            icon: PhosphorIconsBold.checkCircle,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
