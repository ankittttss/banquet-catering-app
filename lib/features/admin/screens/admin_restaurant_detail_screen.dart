import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/admin_restaurant_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/restaurant_card.dart';
import '../../../shared/widgets/veg_dot.dart';
import '../widgets/menu_item_form_sheet.dart';
import '../widgets/restaurant_status_badge.dart';

// Admin console indigo.
const _indigo = Color(0xFF4338CA);

/// Per-restaurant management hub: live customer preview, lifecycle actions
/// (publish / suspend / archive / restore), "Edit details" into the wizard,
/// and the scoped menu manager.
class AdminRestaurantDetailScreen extends ConsumerStatefulWidget {
  const AdminRestaurantDetailScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<AdminRestaurantDetailScreen> createState() =>
      _AdminRestaurantDetailScreenState();
}

class _AdminRestaurantDetailScreenState
    extends ConsumerState<AdminRestaurantDetailScreen> {
  bool _busy = false;

  void _refreshAll() {
    ref.invalidate(adminRestaurantProvider(widget.restaurantId));
    ref.invalidate(adminRestaurantMenuProvider(widget.restaurantId));
    ref.invalidate(adminRestaurantListProvider);
    // Customer world — lifecycle changes show up without an app restart.
    ref.invalidate(restaurantsProvider);
    ref.invalidate(menuItemsProvider);
  }

  Future<void> _setStatus(Restaurant r, RestaurantStatus next) async {
    // Suspend/archive take a restaurant away from customers — confirm.
    if (next == RestaurantStatus.suspended ||
        next == RestaurantStatus.archived) {
      final verb = next == RestaurantStatus.suspended ? 'Suspend' : 'Archive';
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$verb "${r.name}"?'),
          content: Text(
            next == RestaurantStatus.suspended
                ? 'The restaurant is hidden from customers until you '
                    'reactivate it. Existing orders are not affected.'
                : 'The restaurant is taken off the catalog. You can restore '
                    'it to a draft later — nothing is deleted.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(verb),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(adminRestaurantRepositoryProvider).setStatus(r.id, next);
      _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (next) {
            RestaurantStatus.published => '"${r.name}" is live for customers',
            RestaurantStatus.suspended => '"${r.name}" suspended — hidden '
                'from customers',
            RestaurantStatus.archived => '"${r.name}" archived',
            RestaurantStatus.draft => '"${r.name}" restored to draft',
          }),
          backgroundColor:
              next == RestaurantStatus.published ? AppColors.success : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // The phase34 publish gate speaks human — show it verbatim.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errText(e)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _errText(Object e) {
    if (e is PostgrestException) return e.message;
    final s = e.toString();
    if (s.startsWith('Bad state: ')) return s.substring('Bad state: '.length);
    return s.split('\n').first;
  }

  Future<void> _editDetails() async {
    await context.push(AppRoutes.adminRestaurantEditFor(widget.restaurantId));
    _refreshAll();
  }

  Future<void> _addOrEditItem(Restaurant r, {MenuItem? existing}) async {
    final saved = await MenuItemFormSheet.show(
      context,
      existing: existing,
      lockedRestaurant: r,
    );
    if (saved == true) {
      ref.invalidate(adminRestaurantMenuProvider(r.id));
    }
  }

  Future<void> _toggleItem(MenuItem item, bool value) async {
    await ref
        .read(menuRepositoryProvider)
        .setMenuItemAvailability(id: item.id, isAvailable: value);
    ref.invalidate(adminRestaurantMenuProvider(widget.restaurantId));
    ref.invalidate(adminMenuItemsProvider);
    ref.invalidate(menuItemsProvider);
  }

  Future<void> _deleteItem(MenuItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${item.name}"?'),
        content: const Text('This permanently removes the dish.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(menuRepositoryProvider).deleteMenuItem(item.id);
    ref.invalidate(adminRestaurantMenuProvider(widget.restaurantId));
    ref.invalidate(adminMenuItemsProvider);
    ref.invalidate(menuItemsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final rAsync = ref.watch(adminRestaurantProvider(widget.restaurantId));

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: Text(rAsync.valueOrNull?.name ?? 'Manage restaurant'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: rAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e),
        data: (r) {
          if (r == null) {
            return const EmptyState(
              title: 'Restaurant not found',
              message: 'It may have been removed.',
              icon: PhosphorIconsDuotone.storefront,
            );
          }
          return RefreshIndicator(
            color: _indigo,
            onRefresh: () async => _refreshAll(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.xxl,
              ),
              children: [
                _StatusCard(
                  restaurant: r,
                  busy: _busy,
                  onAction: (next) => _setStatus(r, next),
                ),
                const SizedBox(height: AppSizes.lg),
                Row(
                  children: [
                    Text('Customer preview', style: AppTextStyles.heading2),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _busy ? null : _editDetails,
                      icon: const Icon(
                        PhosphorIconsRegular.pencilSimple,
                        size: 16,
                        color: _indigo,
                      ),
                      label: Text(
                        'Edit details',
                        style: AppTextStyles.buttonLabel
                            .copyWith(color: _indigo, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                RestaurantCard(restaurant: r, interactive: false),
                const SizedBox(height: AppSizes.lg),
                _MenuSection(
                  restaurant: r,
                  onAdd: () => _addOrEditItem(r),
                  onEdit: (item) => _addOrEditItem(r, existing: item),
                  onToggle: _toggleItem,
                  onDelete: _deleteItem,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Status / lifecycle card ─────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.restaurant,
    required this.busy,
    required this.onAction,
  });

  final Restaurant restaurant;
  final bool busy;
  final ValueChanged<RestaurantStatus> onAction;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RestaurantStatusBadge(status: r.status),
              const Spacer(),
              Text(
                switch (r.status) {
                  RestaurantStatus.published when r.publishedAt != null =>
                    'Live since ${_date(r.publishedAt!)}',
                  RestaurantStatus.archived when r.archivedAt != null =>
                    'Archived ${_date(r.archivedAt!)}',
                  _ when r.updatedAt != null =>
                    'Updated ${_date(r.updatedAt!)}',
                  _ => '',
                },
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            switch (r.status) {
              RestaurantStatus.draft =>
                'Hidden from customers. Publish when the profile and menu '
                    'are ready.',
              RestaurantStatus.published =>
                'Visible to customers on the home feed and search.',
              RestaurantStatus.suspended =>
                'Temporarily hidden from customers. Reactivate anytime.',
              RestaurantStatus.archived =>
                'Off the catalog. Restore to draft to work on it again.',
            },
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              for (final (label, target, primary) in _actionsFor(r.status)) ...[
                Expanded(
                  child: primary
                      ? FilledButton(
                          onPressed: busy ? null : () => onAction(target),
                          style: FilledButton.styleFrom(
                            backgroundColor: _indigo,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusSm),
                            ),
                          ),
                          child: Text(
                            label,
                            style: AppTextStyles.buttonLabel
                                .copyWith(color: Colors.white, fontSize: 13),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: busy ? null : () => onAction(target),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusSm),
                            ),
                          ),
                          child: Text(
                            label,
                            style: AppTextStyles.buttonLabel.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: AppSizes.sm),
              ],
            ]..removeLast(),
          ),
        ],
      ),
    );
  }

  /// (label, target status, is-primary) per lifecycle state.
  List<(String, RestaurantStatus, bool)> _actionsFor(RestaurantStatus s) =>
      switch (s) {
        RestaurantStatus.draft => const [
            ('Publish', RestaurantStatus.published, true),
            ('Archive', RestaurantStatus.archived, false),
          ],
        RestaurantStatus.published => const [
            ('Suspend', RestaurantStatus.suspended, false),
            ('Archive', RestaurantStatus.archived, false),
          ],
        RestaurantStatus.suspended => const [
            ('Reactivate', RestaurantStatus.published, true),
            ('Archive', RestaurantStatus.archived, false),
          ],
        RestaurantStatus.archived => const [
            ('Restore to draft', RestaurantStatus.draft, true),
          ],
      };

  static String _date(DateTime t) => '${t.day}/${t.month}/${t.year}';
}

// ───────────────────────── Menu section ─────────────────────────

class _MenuSection extends ConsumerWidget {
  const _MenuSection({
    required this.restaurant,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Restaurant restaurant;
  final VoidCallback onAdd;
  final ValueChanged<MenuItem> onEdit;
  final void Function(MenuItem, bool) onToggle;
  final ValueChanged<MenuItem> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(adminRestaurantMenuProvider(restaurant.id));
    final items = itemsAsync.valueOrNull ?? const <MenuItem>[];
    final available = items.where((i) => i.isAvailable).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Menu · $available available of ${items.length}',
                style: AppTextStyles.heading2,
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: onAdd,
              icon: const Icon(PhosphorIconsBold.plus, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        if (itemsAsync.isLoading && items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.xl),
              child: CircularProgressIndicator(),
            ),
          )
        else if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Text(
              'No dishes yet — add at least one available item before '
              'publishing.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          )
        else
          for (final item in items) ...[
            InkWell(
              onTap: () => onEdit(item),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    VegDot(isVeg: item.isVeg),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyBold,
                          ),
                          Text(
                            '₹${item.price.toStringAsFixed(0)}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                      color: AppColors.textMuted,
                      onPressed: () => onDelete(item),
                    ),
                    Switch.adaptive(
                      value: item.isAvailable,
                      activeThumbColor: _indigo,
                      onChanged: (v) => onToggle(item, v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
      ],
    );
  }
}
