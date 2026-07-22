import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/router/app_routes.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/admin_restaurant_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/restaurant_card.dart';
import '../widgets/admin_ui.dart';
import '../widgets/menu_item_form_sheet.dart';

/// Per-restaurant management hub: lifecycle actions (publish / suspend /
/// archive / restore), live customer preview, "Edit details" into the wizard,
/// and the scoped menu manager. Redesigned to the indigo admin identity; all
/// lifecycle + menu mutations run through the real repositories.
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
    if (next == RestaurantStatus.suspended ||
        next == RestaurantStatus.archived) {
      final verb = next == RestaurantStatus.suspended ? 'Suspend' : 'Archive';
      final ok = await adminConfirm(
        context,
        title: '$verb "${r.name}"?',
        body: next == RestaurantStatus.suspended
            ? "Customers won't see it until you reactivate. Existing orders are unaffected."
            : 'It will be taken off the catalog. You can restore it to a draft later — nothing is deleted.',
        confirmLabel: verb,
        danger: true,
      );
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(adminRestaurantRepositoryProvider).setStatus(r.id, next);
      _refreshAll();
      if (!mounted) return;
      adminToast(
        context,
        switch (next) {
          RestaurantStatus.published => '"${r.name}" is now live',
          RestaurantStatus.suspended => '"${r.name}" suspended',
          RestaurantStatus.archived => '"${r.name}" archived',
          RestaurantStatus.draft => '"${r.name}" restored to draft',
        },
        success: next == RestaurantStatus.published,
      );
    } catch (e) {
      if (!mounted) return;
      // The phase34 publish gate speaks human — show it verbatim.
      adminToast(context, _errText(e));
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
    final saved = await MenuItemFormSheet.show(context,
        existing: existing, lockedRestaurant: r);
    if (saved == true) ref.invalidate(adminRestaurantMenuProvider(r.id));
  }

  Future<void> _toggleItem(MenuItem item, bool value) async {
    await ref
        .read(menuRepositoryProvider)
        .setMenuItemAvailability(id: item.id, isAvailable: value);
    ref.invalidate(adminRestaurantMenuProvider(widget.restaurantId));
    ref.invalidate(adminMenuItemsProvider);
    ref.invalidate(menuItemsProvider);
    if (mounted) {
      adminToast(
          context, value ? '"${item.name}" available' : '"${item.name}" hidden',
          success: value);
    }
  }

  Future<void> _deleteItem(MenuItem item) async {
    final ok = await adminConfirm(
      context,
      title: 'Delete "${item.name}"?',
      body: 'This permanently removes the dish.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await ref.read(menuRepositoryProvider).deleteMenuItem(item.id);
    ref.invalidate(adminRestaurantMenuProvider(widget.restaurantId));
    ref.invalidate(adminMenuItemsProvider);
    ref.invalidate(menuItemsProvider);
    if (mounted) adminToast(context, 'Dish deleted');
  }

  @override
  Widget build(BuildContext context) {
    final rAsync = ref.watch(adminRestaurantProvider(widget.restaurantId));

    return AdminScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminBar(
            title: rAsync.valueOrNull?.name ?? 'Manage restaurant',
            subtitle: rAsync.valueOrNull == null
                ? null
                : [
                    if ((rAsync.value!.cuisinesDisplay ?? '').isNotEmpty)
                      rAsync.value!.cuisinesDisplay!,
                    if (rAsync.value!.pricePerPlate != null)
                      '₹${rAsync.value!.pricePerPlate!.toStringAsFixed(0)}/plate',
                  ].join(' · '),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: rAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.indigo),
              ),
              // Without onRetry this was a dead end — a failed load left the
              // admin with no way back except leaving the screen.
              error: (e, _) => AppErrorView(error: e, onRetry: _refreshAll),
              data: (r) {
                if (r == null) {
                  return const AdminMessageState(
                    icon: PhosphorIconsBold.storefront,
                    title: 'Restaurant not found',
                    message: 'It may have been removed.',
                  );
                }
                return RefreshIndicator(
                  color: AdminColors.indigo,
                  onRefresh: () async => _refreshAll(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _LifecycleCard(
                        restaurant: r,
                        busy: _busy,
                        onAction: (next) => _setStatus(r, next),
                      ),
                      const SizedBox(height: 18),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 10),
                        child: AdminOverline('Customer preview'),
                      ),
                      RestaurantCard(restaurant: r, interactive: false),
                      const SizedBox(height: 10),
                      AdminButton(
                        label: 'Edit details',
                        variant: AdminBtn.soft,
                        expand: true,
                        leading: PhosphorIconsRegular.pencilSimple,
                        onPressed: _busy ? null : _editDetails,
                      ),
                      const SizedBox(height: 22),
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Lifecycle card ───────────────────────

class _LifecycleCard extends ConsumerWidget {
  const _LifecycleCard(
      {required this.restaurant, required this.busy, required this.onAction});
  final Restaurant restaurant;
  final bool busy;
  final ValueChanged<RestaurantStatus> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = restaurant;
    final s = adminStatusStyle(r.status);
    final items = ref.watch(adminRestaurantMenuProvider(r.id)).valueOrNull ??
        const <MenuItem>[];
    final missing =
        r.status == RestaurantStatus.draft ? _missingCount(r, items) : 0;

    final explain = switch (r.status) {
      RestaurantStatus.published =>
        'Visible to customers in search and event planning.',
      RestaurantStatus.draft => missing == 0
          ? 'Ready to publish — all checks pass.'
          : 'Hidden from customers. Complete the checklist to publish.',
      RestaurantStatus.suspended => 'Temporarily hidden from customers.',
      RestaurantStatus.archived => 'Removed from the catalog but not deleted.',
    };

    final actions = _actionsFor(r.status);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.fg.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: s.bg,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AdminBadge(status: r.status),
                    const Spacer(),
                    Text(_updatedLabel(r),
                        style: AdminText.cap.copyWith(color: s.fg)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(explain,
                    style: AdminText.body.copyWith(color: AdminColors.tx)),
              ],
            ),
          ),
          Container(
            color: AdminColors.card,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  Expanded(
                    child: AdminButton(
                      label: actions[i].$1,
                      variant: actions[i].$3,
                      expand: true,
                      disabled: busy,
                      onPressed: () => onAction(actions[i].$2),
                    ),
                  ),
                  if (i != actions.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          if (missing > 0)
            Container(
              color: AdminColors.card,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.info,
                      size: 14, color: AdminColors.susp),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '$missing item(s) block publishing — open the editor to finish.',
                      style: AdminText.cap.copyWith(
                          color: AdminColors.susp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static int _missingCount(Restaurant r, List<MenuItem> items) {
    var n = 0;
    if (r.name.trim().isEmpty) n++;
    if ((r.pricePerPlate ?? 0) <= 0) n++;
    if ((r.minGuests ?? 0) <= 0) n++;
    if ((r.address?.trim().isEmpty ?? true) ||
        r.latitude == null ||
        r.longitude == null) n++;
    final noImage =
        (r.logoUrl?.isEmpty ?? true) && (r.coverImageUrl?.isEmpty ?? true);
    if (noImage) n++;
    if (!items.any((m) => m.isAvailable)) n++;
    return n;
  }

  static String _updatedLabel(Restaurant r) {
    final d = switch (r.status) {
      RestaurantStatus.published => r.publishedAt,
      RestaurantStatus.archived => r.archivedAt,
      _ => r.updatedAt,
    };
    if (d == null) return '';
    final prefix = switch (r.status) {
      RestaurantStatus.published => 'Live since ',
      RestaurantStatus.archived => 'Archived ',
      _ => 'Updated ',
    };
    return '$prefix${d.day}/${d.month}/${d.year}';
  }

  /// (label, target status, variant) per lifecycle state.
  static List<(String, RestaurantStatus, AdminBtn)> _actionsFor(
          RestaurantStatus s) =>
      switch (s) {
        RestaurantStatus.draft => const [
            ('Publish now', RestaurantStatus.published, AdminBtn.primary),
            ('Archive', RestaurantStatus.archived, AdminBtn.ghost),
          ],
        RestaurantStatus.published => const [
            ('Suspend', RestaurantStatus.suspended, AdminBtn.ghost),
            ('Archive', RestaurantStatus.archived, AdminBtn.ghost),
          ],
        RestaurantStatus.suspended => const [
            ('Reactivate', RestaurantStatus.published, AdminBtn.primary),
            ('Archive', RestaurantStatus.archived, AdminBtn.ghost),
          ],
        RestaurantStatus.archived => const [
            ('Restore to draft', RestaurantStatus.draft, AdminBtn.primary),
          ],
      };
}

// ─────────────────────── Menu section ───────────────────────

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
    // Category names for the "Starters · ₹220" sub-line on each dish row.
    final categoryNames = <String, String>{
      for (final c in ref.watch(menuCategoriesProvider).valueOrNull ??
          const <MenuCategory>[])
        c.id: c.name,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AdminOverline(
                  'Menu · $available available of ${items.length}'),
            ),
            GestureDetector(
              onTap: onAdd,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsBold.plus,
                      size: 16, color: AdminColors.indigo600),
                  SizedBox(width: 4),
                  Text('Add',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.indigo600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (itemsAsync.isLoading && items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(
                child: CircularProgressIndicator(color: AdminColors.indigo)),
          )
        else if (items.isEmpty)
          AdminCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AdminColors.indigo050,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(PhosphorIconsDuotone.forkKnife,
                      size: 26, color: AdminColors.indigo),
                ),
                const SizedBox(height: 12),
                const Text('No dishes yet', style: AdminText.h2),
                const SizedBox(height: 4),
                const Text('Add at least one available dish before publishing.',
                    textAlign: TextAlign.center, style: AdminText.cap),
                const SizedBox(height: 14),
                AdminButton(
                  label: 'Add dish',
                  size: 'sm',
                  leading: PhosphorIconsBold.plus,
                  onPressed: onAdd,
                ),
              ],
            ),
          )
        else
          for (final item in items) ...[
            _DishRow(
                item: item,
                categoryName: categoryNames[item.categoryId],
                onEdit: onEdit,
                onToggle: onToggle,
                onDelete: onDelete),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.item,
    required this.categoryName,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final MenuItem item;

  /// Resolved category label ("Starters"); null while categories load or if
  /// the dish points at a category that no longer exists.
  final String? categoryName;
  final ValueChanged<MenuItem> onEdit;
  final void Function(MenuItem, bool) onToggle;
  final ValueChanged<MenuItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: item.isAvailable ? 1 : 0.6,
      child: AdminCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            AdminVegMark(isVeg: item.isVeg),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => onEdit(item),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminText.h3),
                    const SizedBox(height: 2),
                    Text(
                      categoryName == null
                          ? '₹${item.price.toStringAsFixed(0)}'
                          : '$categoryName · ₹${item.price.toStringAsFixed(0)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.cap,
                    ),
                  ],
                ),
              ),
            ),
            AdminToggle(
                value: item.isAvailable, onChanged: (v) => onToggle(item, v)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.trash,
                  size: 18, color: AdminColors.tx3),
              onPressed: () => onDelete(item),
            ),
          ],
        ),
      ),
    );
  }
}
