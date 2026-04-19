import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/material_icon_map.dart';
import '../../../data/models/collection.dart';
import '../../../data/models/event_category.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/favorites_providers.dart';
import '../../../shared/providers/home_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/safe_net_image.dart';
import '../../../shared/widgets/user_bottom_nav.dart';
import '../widgets/address_picker_sheet.dart';

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(restaurantsProvider);
    ref.invalidate(eventCategoriesProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(addressesProvider);
    await ref.read(restaurantsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      padded: false,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: const [
            _LocationHeader(),
            SliverToBoxAdapter(child: _SearchBar()),
            SliverToBoxAdapter(child: _HeroBanner()),
            _SectionHeader(title: "What's the occasion?"),
            SliverToBoxAdapter(child: _EventCategoriesGrid()),
            SliverToBoxAdapter(child: SizedBox(height: AppSizes.md)),
            _SectionHeader(
              title: 'Curated for events',
              trailing: 'See all',
            ),
            SliverToBoxAdapter(child: _CollectionsScroll()),
            SliverToBoxAdapter(child: SizedBox(height: AppSizes.md)),
            SliverToBoxAdapter(child: _FilterChipsRow()),
            _SectionHeader(title: 'Restaurants nearby'),
            _RestaurantList(),
            SliverToBoxAdapter(child: SizedBox(height: AppSizes.xxxl)),
          ],
        ),
      ),
      bottomBar: const UserBottomNav(active: UserNavTab.home),
    );
  }
}

// ───────────────────────── Location header ─────────────────────────

class _LocationHeader extends ConsumerWidget {
  const _LocationHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = ref.watch(activeAddressProvider);
    final label = def?.label.label ?? 'Deliver to';
    final line = def?.shortLabel ?? def?.fullAddress ?? 'Set your address';

    return SliverAppBar(
      pinned: false,
      floating: true,
      snap: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      elevation: 0,
      toolbarHeight: 64,
      titleSpacing: AppSizes.pagePadding,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: InkWell(
              onTap: () => AddressPickerSheet.show(context),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Deliver to',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: AppTextStyles.heading2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                    ],
                  ),
                  if (def != null)
                    Text(
                      line,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          _AvatarButton(onTap: () => context.push(AppRoutes.profile)),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.person_outline_rounded,
            color: AppColors.textSecondary, size: 22),
      ),
    );
  }
}

// ───────────────────────── Search bar ─────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push(AppRoutes.search),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Container(
                height: 48,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        color: AppColors.textMuted, size: 22),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        'Search event caterers, cuisines…',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: AppColors.border,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    const Icon(Icons.mic_none_rounded,
                        color: AppColors.primary, size: 22),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              // Hook up full filter sheet in phase 2.
            },
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: const Icon(Icons.tune_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Hero banner ─────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                    ),
                    child: Text(
                      '🎉 EVENT CATERING',
                      style: AppTextStyles.captionBold.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'Order food for\nyour next event',
                    style: AppTextStyles.display.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'From 5 to 5,000 guests',
                    style: AppTextStyles.caption
                        .copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppSizes.md),
                  InkWell(
                    onTap: () => context.push(AppRoutes.eventDetails),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Plan your event',
                            style: AppTextStyles.bodyBold
                                .copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              color: AppColors.primary, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('🍽️', style: TextStyle(fontSize: 36)),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.05, end: 0),
    );
  }
}

// ───────────────────────── Section header ─────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          AppSizes.xl,
          AppSizes.pagePadding,
          AppSizes.md,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTextStyles.heading1),
            if (trailing != null)
              Text(
                trailing!,
                style: AppTextStyles.bodyBold
                    .copyWith(color: AppColors.primary, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Event categories grid ─────────────────────────

class _EventCategoriesGrid extends ConsumerWidget {
  const _EventCategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventCategoriesProvider);
    return async.when(
      loading: () => const _EventGridSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (cats) => Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cats.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: AppSizes.sm,
            crossAxisSpacing: AppSizes.sm,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (_, i) => _EventCategoryTile(category: cats[i]),
        ),
      ),
    );
  }
}

class _EventCategoryTile extends ConsumerWidget {
  const _EventCategoryTile({required this.category});
  final EventCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = AppColors.fromHex(category.bgHex);
    final fg = AppColors.fromHex(category.iconHex, fallback: AppColors.primary);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        ref
            .read(eventDraftProvider.notifier)
            .setSession(category.defaultSession);
        ref
            .read(eventDraftProvider.notifier)
            .setGuestCount(category.defaultGuestCount);
        context.push(AppRoutes.eventDetails);
      },
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                materialIconByName(category.iconName),
                color: fg,
                size: 20,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              category.name,
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventGridSkeleton extends StatelessWidget {
  const _EventGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppSizes.sm,
          crossAxisSpacing: AppSizes.sm,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Collections scroll ─────────────────────────

class _CollectionsScroll extends ConsumerWidget {
  const _CollectionsScroll();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionsProvider);
    return async.when(
      loading: () => const SizedBox(height: 110),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) => SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pagePadding,
          ),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
          itemBuilder: (_, i) => _CollectionCard(collection: list[i]),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});
  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final bg =
        AppColors.fromHex(collection.bgHex, fallback: AppColors.primarySoft);
    final fg = AppColors.fromHex(collection.iconHex,
        fallback: AppColors.primary);
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        // Collection landing page ships in phase 2.
      },
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              materialIconByName(collection.iconName),
              color: fg,
              size: 26,
            ),
            const Spacer(),
            Text(
              collection.name,
              style: AppTextStyles.heading3.copyWith(fontSize: 14),
            ),
            if (collection.subtitle != null)
              Text(
                collection.subtitle!,
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Filter chips ─────────────────────────

class _FilterChipsRow extends ConsumerWidget {
  const _FilterChipsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(homeSortProvider);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
        ),
        itemCount: HomeSort.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (_, i) {
          final sort = HomeSort.values[i];
          final isOn = sort == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(homeSortProvider.notifier).state = sort;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: BoxDecoration(
                color: isOn ? AppColors.textPrimary : AppColors.surface,
                border: Border.all(
                  color: isOn ? AppColors.textPrimary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Text(
                sort.label,
                style: AppTextStyles.bodyBold.copyWith(
                  color: isOn ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Restaurant list ─────────────────────────

class _RestaurantList extends ConsumerWidget {
  const _RestaurantList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeRestaurantsProvider);
    return async.when(
      loading: () => const SliverToBoxAdapter(child: _RestaurantSkeleton()),
      error: (e, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Couldn\'t load restaurants',
            message: '$e',
            onAction: () => ref.invalidate(restaurantsProvider),
            actionLabel: 'Retry',
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.pagePadding),
              child: EmptyState(
                icon: Icons.restaurant_rounded,
                title: 'No restaurants yet',
                message: 'Try a different filter or come back soon.',
              ),
            ),
          );
        }
        return SliverList.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSizes.md),
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              i == 0 ? 0 : 0,
              AppSizes.pagePadding,
              0,
            ),
            child: _RestaurantCard(restaurant: list[i])
                .animate()
                .fadeIn(duration: 280.ms, delay: (40 * i).ms)
                .slideY(begin: 0.04, end: 0),
          ),
        );
      },
    );
  }
}

class _RestaurantCard extends ConsumerWidget {
  const _RestaurantCard({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(isFavoriteProvider(restaurant.id));
    final bg = AppColors.fromHex(restaurant.heroBgHex,
        fallback: AppColors.primarySoft);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(AppRoutes.restaurantDetailFor(restaurant.id));
        },
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusLg),
                ),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (restaurant.logoUrl != null)
                        SafeNetImage(
                          url: restaurant.logoUrl!,
                          errorBuilder: (_) => _emojiFallback(bg),
                        )
                      else
                        _emojiFallback(bg),
                      if (restaurant.tag != null)
                        Positioned(
                          top: AppSizes.sm,
                          left: AppSizes.sm,
                          child: _TagChip(text: restaurant.tag!),
                        ),
                      Positioned(
                        top: AppSizes.sm,
                        right: AppSizes.sm,
                        child: _FavButton(
                          active: isFav,
                          onTap: () => ref
                              .read(favoritesProvider.notifier)
                              .toggle(restaurant.id),
                        ),
                      ),
                      if (restaurant.minGuests != null)
                        Positioned(
                          bottom: AppSizes.sm,
                          right: AppSizes.sm,
                          child: _MinGuestsChip(
                              min: restaurant.minGuests!),
                        ),
                      if (restaurant.pricePerPlate != null)
                        Positioned(
                          bottom: AppSizes.sm,
                          left: AppSizes.sm,
                          child: _PriceChip(
                              pricePerPlate: restaurant.pricePerPlate!),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            restaurant.name,
                            style: AppTextStyles.heading2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (restaurant.rating != null)
                          _RatingChip(
                            rating: restaurant.rating!,
                            count: restaurant.ratingsCount,
                          ),
                      ],
                    ),
                    if (restaurant.cuisinesDisplay != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        restaurant.cuisinesDisplay!,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSizes.sm),
                    Container(
                      height: 1,
                      color: AppColors.divider,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: [
                        if (restaurant.deliveryEta.isNotEmpty) ...[
                          const Icon(Icons.schedule_rounded,
                              size: 14,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(restaurant.deliveryEta,
                              style: AppTextStyles.caption),
                          const SizedBox(width: AppSizes.sm),
                          const _Dot(),
                          const SizedBox(width: AppSizes.sm),
                        ],
                        const Icon(Icons.currency_rupee_rounded,
                            size: 13, color: AppColors.textSecondary),
                        Text(
                          '${restaurant.pricePerPlate?.toStringAsFixed(0) ?? '—'}/plate',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emojiFallback(Color bg) => Container(
        color: bg,
        alignment: Alignment.center,
        child: Text(
          restaurant.heroEmoji ?? '🍽️',
          style: const TextStyle(fontSize: 56),
        ),
      );
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.captionBold.copyWith(
          color: Colors.white,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 18,
          color: active ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _MinGuestsChip extends StatelessWidget {
  const _MinGuestsChip({required this.min});
  final int min;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.catGreenLt,
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
      child: Text(
        'Min $min guests',
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.catGreen,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.pricePerPlate});
  final double pricePerPlate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '₹${pricePerPlate.toStringAsFixed(0)}/plate',
        style: AppTextStyles.bodyBold.copyWith(
          color: AppColors.primary,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, this.count});
  final double rating;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final bg =
        rating >= 4.0 ? AppColors.success : AppColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppSizes.radiusXs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: AppTextStyles.captionBold.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.star_rounded, color: Colors.white, size: 13),
            ],
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            _formatCount(count!),
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) {
      return '(${(n / 1000).toStringAsFixed(1)}K)';
    }
    return '($n)';
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.border,
          shape: BoxShape.circle,
        ),
      );
}

class _RestaurantSkeleton extends StatelessWidget {
  const _RestaurantSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.md),
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
