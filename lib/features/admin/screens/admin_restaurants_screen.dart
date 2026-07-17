import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/admin_restaurant_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../widgets/restaurant_status_badge.dart';

// Same deep-indigo chrome as the admin console.
const _indigo = Color(0xFF4338CA);

/// Admin catalog: every restaurant in every lifecycle state, searched and
/// paginated server-side (the catalog holds 1000+ rows). Entry point for
/// onboarding (FAB) and per-restaurant management (row tap).
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
  }

  void _onStatusChanged(RestaurantStatus? status) {
    ref.read(adminRestaurantPageProvider.notifier).state = 0;
    ref.read(adminRestaurantStatusFilterProvider.notifier).state = status;
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(adminRestaurantListProvider);
    final statusFilter = ref.watch(adminRestaurantStatusFilterProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Restaurants'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('Add restaurant'),
        onPressed: () => context.push(AppRoutes.adminRestaurantNew),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.sm,
              AppSizes.pagePadding,
              0,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search restaurants…',
                prefixIcon: const Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 20,
                ),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(PhosphorIconsRegular.x, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          _StatusChips(active: statusFilter, onChanged: _onStatusChanged),
          const SizedBox(height: AppSizes.xs),
          Expanded(
            child: pageAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorView(error: e),
              data: (page) {
                if (page.items.isEmpty) {
                  return EmptyState(
                    title: 'No restaurants found',
                    message: statusFilter == null
                        ? 'Tap "Add restaurant" to onboard your first kitchen.'
                        : 'Nothing with status "${statusFilter.label}" matches.',
                    icon: PhosphorIconsDuotone.storefront,
                  );
                }
                return RefreshIndicator(
                  color: _indigo,
                  onRefresh: () async =>
                      ref.invalidate(adminRestaurantListProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      AppSizes.xs,
                      AppSizes.pagePadding,
                      96, // clear the FAB
                    ),
                    itemCount: page.items.length + 1,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (_, i) {
                      if (i == page.items.length) {
                        return _PageFooter(
                          total: page.total,
                          page: page.page,
                          pageCount: page.pageCount,
                          hasPrev: page.hasPrev,
                          hasNext: page.hasNext,
                          onPage: (p) => ref
                              .read(adminRestaurantPageProvider.notifier)
                              .state = p,
                        );
                      }
                      return _RestaurantRow(restaurant: page.items[i]);
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

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.active, required this.onChanged});

  final RestaurantStatus? active;
  final ValueChanged<RestaurantStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Row(
        children: [
          _chip(
              label: 'All',
              selected: active == null,
              onTap: () => onChanged(null)),
          for (final s in RestaurantStatus.values)
            _chip(
              label: s.label,
              selected: active == s,
              onTap: () => onChanged(s),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? _indigo : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _indigo : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantRow extends StatelessWidget {
  const _RestaurantRow({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return InkWell(
      onTap: () => context.push(AppRoutes.adminRestaurantFor(r.id)),
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _Thumb(restaurant: r),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      RestaurantStatusBadge(status: r.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((r.cuisinesDisplay ?? '').isNotEmpty)
                        r.cuisinesDisplay!,
                      if (r.pricePerPlate != null)
                        '₹${r.pricePerPlate!.toStringAsFixed(0)}/plate',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                  if (r.updatedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Updated ${_ago(r.updatedAt!)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            const Icon(
              PhosphorIconsBold.caretRight,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
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
    final emoji = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.fromHex(
          restaurant.heroBgHex,
          fallback: AppColors.surfaceAlt,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        restaurant.heroEmoji ?? '🍽️',
        style: const TextStyle(fontSize: 22),
      ),
    );
    final url = restaurant.logoUrl;
    if (url == null || url.isEmpty) return emoji;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => emoji,
      ),
    );
  }
}

class _PageFooter extends StatelessWidget {
  const _PageFooter({
    required this.total,
    required this.page,
    required this.pageCount,
    required this.hasPrev,
    required this.hasNext,
    required this.onPage,
  });

  final int total;
  final int page;
  final int pageCount;
  final bool hasPrev;
  final bool hasNext;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.caretLeft, size: 18),
            color: hasPrev ? _indigo : AppColors.textMuted,
            onPressed: hasPrev ? () => onPage(page - 1) : null,
          ),
          Text(
            'Page ${page + 1} of $pageCount · $total total',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsBold.caretRight, size: 18),
            color: hasNext ? _indigo : AppColors.textMuted,
            onPressed: hasNext ? () => onPage(page + 1) : null,
          ),
        ],
      ),
    );
  }
}
