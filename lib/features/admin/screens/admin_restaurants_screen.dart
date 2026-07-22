import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/router/app_routes.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/admin_restaurant_providers.dart';
import '../widgets/admin_ui.dart';

/// Admin catalog: every restaurant in every lifecycle state, searched and
/// paginated server-side. Entry point for onboarding (FAB) and per-restaurant
/// management (row tap). Redesigned to the imported indigo identity.
class AdminRestaurantsScreen extends ConsumerStatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  ConsumerState<AdminRestaurantsScreen> createState() =>
      _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState
    extends ConsumerState<AdminRestaurantsScreen> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl =
        TextEditingController(text: ref.read(adminRestaurantSearchProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Debounced so we don't fire a server query per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(adminRestaurantPageProvider.notifier).state = 0;
      ref.read(adminRestaurantSearchProvider.notifier).state = value;
    });
    setState(() {}); // reflect the clear-button visibility immediately
  }

  void _onStatusChanged(RestaurantStatus? status) {
    ref.read(adminRestaurantPageProvider.notifier).state = 0;
    ref.read(adminRestaurantStatusFilterProvider.notifier).state = status;
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(adminRestaurantListProvider);
    final statusFilter = ref.watch(adminRestaurantStatusFilterProvider);

    final subtitle = pageAsync.maybeWhen(
      data: (p) => 'Page ${p.page + 1} of ${p.pageCount} · ${p.total} total',
      orElse: () => null,
    );

    return AdminScaffold(
      active: AdminNav.kitchens,
      floatingActionButton: AdminFab(
        label: 'Add',
        onTap: () => context.push(AppRoutes.adminRestaurantNew),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminBar(
            title: 'Restaurants',
            subtitle: subtitle,
            onBack: () => context.pop(),
            trailing: AdminIconButton(
              icon: PhosphorIconsBold.arrowClockwise,
              onTap: () => ref.invalidate(adminRestaurantListProvider),
            ),
          ),
          _SearchAndFilters(
            controller: _searchCtrl,
            onSearch: _onSearchChanged,
            onClear: () {
              _searchCtrl.clear();
              _onSearchChanged('');
            },
            active: statusFilter,
            onStatus: _onStatusChanged,
          ),
          Expanded(
            child: pageAsync.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: [for (var i = 0; i < 5; i++) const _RowSkeleton()],
              ),
              error: (e, _) => AdminMessageState(
                icon: PhosphorIconsBold.warning,
                iconFg: AdminColors.danger,
                iconBg: AdminColors.dangerBg,
                title: "Couldn't load kitchens",
                message: 'Check your connection and try again.',
                action: AdminButton(
                  label: 'Retry',
                  leading: PhosphorIconsBold.arrowClockwise,
                  onPressed: () => ref.invalidate(adminRestaurantListProvider),
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return AdminMessageState(
                    icon: PhosphorIconsBold.magnifyingGlass,
                    title: 'No kitchens found',
                    message: statusFilter == null
                        ? 'Tap "Add" to onboard your first kitchen.'
                        : 'Nothing with status "${statusFilter.label}" matches.',
                  );
                }
                return RefreshIndicator(
                  color: AdminColors.indigo,
                  onRefresh: () async =>
                      ref.invalidate(adminRestaurantListProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Reserve room for the pinned "Onboard" button so it never
                    // covers the last kitchen card.
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      AdminScaffold.fabScrollPadding,
                    ),
                    itemCount: page.items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == page.items.length) {
                        return _Pager(
                          page: page.page,
                          pageCount: page.pageCount,
                          hasPrev: page.hasPrev,
                          hasNext: page.hasNext,
                          onPage: (p) => ref
                              .read(adminRestaurantPageProvider.notifier)
                              .state = p,
                        );
                      }
                      return _KitchenRow(restaurant: page.items[i]);
                    },
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

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.onSearch,
    required this.onClear,
    required this.active,
    required this.onStatus,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final RestaurantStatus? active;
  final ValueChanged<RestaurantStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(bottom: BorderSide(color: AdminColors.line)),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: AdminColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.line),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.magnifyingGlass,
                    size: 18, color: AdminColors.tx3),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onSearch,
                    textInputAction: TextInputAction.search,
                    style: adminTextStyle,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search kitchens, cuisines…',
                      hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AdminColors.tx3),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(PhosphorIconsRegular.x,
                        size: 16, color: AdminColors.tx3),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                    label: 'All',
                    selected: active == null,
                    onTap: () => onStatus(null)),
                for (final s in RestaurantStatus.values)
                  _FilterChip(
                    label: s.label,
                    selected: active == s,
                    onTap: () => onStatus(s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AdminColors.indigo050 : AdminColors.card,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: selected ? AdminColors.indigo : AdminColors.line,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AdminColors.indigo600 : AdminColors.tx2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KitchenRow extends StatelessWidget {
  const _KitchenRow({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final meta = [
      if ((r.cuisinesDisplay ?? '').isNotEmpty) r.cuisinesDisplay!,
      if (r.pricePerPlate != null)
        '₹${r.pricePerPlate!.toStringAsFixed(0)}/plate',
    ].join(' · ');
    return AdminCard(
      onTap: () => context.push(AppRoutes.adminRestaurantFor(r.id)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _Thumb(restaurant: r),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.h2),
                    ),
                    const SizedBox(width: 8),
                    AdminBadge(status: r.status, small: true),
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminText.cap),
                ],
                if (r.updatedAt != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.clock,
                          size: 12, color: AdminColors.tx3),
                      const SizedBox(width: 5),
                      Text('Updated ${_ago(r.updatedAt!)}',
                          style: AdminText.cap),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(PhosphorIconsBold.caretRight,
              size: 18, color: AdminColors.tx3),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 30) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final emojiTile = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AdminColors.indigo050,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(restaurant.heroEmoji ?? '🍽️',
          style: const TextStyle(fontSize: 24)),
    );
    final url = restaurant.logoUrl;
    if (url == null || url.isEmpty) return emojiTile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => emojiTile,
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSkeleton(width: 48, height: 48, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SizedBox(height: 3),
                AdminSkeleton(width: 150, height: 14),
                SizedBox(height: 8),
                AdminSkeleton(width: 220, height: 11),
                SizedBox(height: 8),
                AdminSkeleton(width: 100, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageCount,
    required this.hasPrev,
    required this.hasNext,
    required this.onPage,
  });
  final int page;
  final int pageCount;
  final bool hasPrev;
  final bool hasNext;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PageBtn(
              label: 'Prev', enabled: hasPrev, onTap: () => onPage(page - 1)),
          Text('Page ${page + 1} of $pageCount', style: AdminText.cap),
          _PageBtn(
              label: 'Next', enabled: hasNext, onTap: () => onPage(page + 1)),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  const _PageBtn(
      {required this.label, required this.enabled, required this.onTap});
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminColors.line),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: enabled ? AdminColors.tx : AdminColors.tx3)),
          ),
        ),
      ),
    );
  }
}
