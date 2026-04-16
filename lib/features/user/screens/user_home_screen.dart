import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/home_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/user_bottom_nav.dart';
import 'my_events_screen.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

// ===========================================================================
// Screen
// ===========================================================================

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(restaurantsProvider);
    ref.invalidate(myOrdersStreamProvider);
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
          slivers: [
            const _Header(),
            const SliverToBoxAdapter(child: _Greeting()),
            const SliverToBoxAdapter(child: _SearchBar()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xl)),

            const _SectionTitle(
                overline: 'WHAT ARE YOU PLANNING', title: 'Event types'),
            SliverToBoxAdapter(child: _EventTypeCarousel()),

            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xl)),
            const SliverToBoxAdapter(child: _BannerCarousel()),

            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xl)),
            const _SectionTitle(
                overline: 'BROWSE BY', title: 'Cuisines'),
            SliverToBoxAdapter(child: _CuisineStrip()),

            SliverToBoxAdapter(child: _UpcomingEventSection()),

            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xl)),
            const _SectionTitle(
                overline: 'HANDPICKED FOR YOU',
                title: 'Popular restaurants',
                trailingLabel: 'View all'),
            SliverToBoxAdapter(child: _PopularRestaurants()),

            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xl)),
            const _SectionTitle(
                overline: 'WHY DAWAT', title: 'What you get'),
            SliverToBoxAdapter(child: _FeatureStrip()),

            SliverToBoxAdapter(child: _TrustStrip()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xxxl)),
          ],
        ),
      ),
      bottomBar: const UserBottomNav(active: UserNavTab.home),
    );
  }
}

// ===========================================================================
// Header (location + title + profile)
// ===========================================================================

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = ref.watch(defaultAddressProvider);
    final addressLabel = def?.label.label ?? 'Add address';
    final fullLine = def?.fullAddress ?? 'Set a venue to plan an event';

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: AppColors.pageBg,
      surfaceTintColor: AppColors.pageBg,
      elevation: 0,
      toolbarHeight: 64,
      titleSpacing: AppSizes.pagePadding,
      title: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        onTap: () => context.push(AppRoutes.addresses),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(PhosphorIconsFill.mapPin,
                    color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(addressLabel.toUpperCase(),
                            style: AppTextStyles.overline
                                .copyWith(fontSize: 10)),
                        const SizedBox(width: AppSizes.xs),
                        const Icon(PhosphorIconsBold.caretDown,
                            size: 10, color: AppColors.textSecondary),
                      ],
                    ),
                    Text(
                      fullLine,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSizes.pagePadding),
          child: _ProfileAvatar(onTap: () => context.push(AppRoutes.profile)),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final seed = profile?.name ?? profile?.email ?? 'U';
    final initial = seed.trim().isEmpty ? 'U' : seed.trim()[0].toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

// ===========================================================================
// Greeting
// ===========================================================================

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final first = (profile?.name?.split(' ').first.trim().isNotEmpty ?? false)
        ? profile!.name!.split(' ').first
        : (profile?.email?.split('@').first ?? 'there');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_greeting()},',
              style: AppTextStyles.bodyMuted.copyWith(fontSize: 14)),
          const SizedBox(height: 2),
          Text('Let\'s plan something,',
              style: AppTextStyles.display.copyWith(fontSize: 26, height: 1.1)),
          Text(first,
              style: AppTextStyles.display.copyWith(
                  fontSize: 26, height: 1.1, color: AppColors.primary)),
        ],
      ),
    ).animate().fadeIn(duration: 340.ms).slideY(begin: 0.08, end: 0);
  }
}

// ===========================================================================
// Search bar
// ===========================================================================

class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsBold.magnifyingGlass,
                color: AppColors.primary, size: 20),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: TextField(
                onChanged: (v) =>
                    ref.read(homeSearchProvider.notifier).state = v,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: 'Search dishes, cuisines, restaurants…',
                  hintStyle: AppTextStyles.body
                      .copyWith(color: AppColors.textMuted),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: AppColors.border,
            ),
            const SizedBox(width: AppSizes.sm),
            const Icon(PhosphorIconsBold.sliders,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 340.ms);
  }
}

// ===========================================================================
// Section title
// ===========================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.overline,
    required this.title,
    this.trailingLabel,
  });

  final String overline;
  final String title;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          AppSizes.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(overline, style: AppTextStyles.overline),
                  const SizedBox(height: 2),
                  Text(title, style: AppTextStyles.heading1),
                ],
              ),
            ),
            if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: AppTextStyles.captionBold
                    .copyWith(color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Event type carousel (round tiles)
// ===========================================================================

class _EventTypeCarousel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(eventTypesProvider);
    final selected = ref.watch(selectedEventTypeProvider);
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.md),
        itemCount: types.length,
        itemBuilder: (_, i) {
          final t = types[i];
          final isSelected = selected == t.id;
          return _EventTypeTile(
            type: t,
            selected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(selectedEventTypeProvider.notifier).state = t.id;
              // Pre-fill the event draft with this type's defaults.
              ref
                  .read(eventDraftProvider.notifier)
                  .setSession(t.defaultSession);
              ref
                  .read(eventDraftProvider.notifier)
                  .setGuestCount(t.defaultGuestCount);
              context.push(AppRoutes.eventDetails);
            },
          )
              .animate(delay: (i * 40).ms)
              .fadeIn(duration: 320.ms)
              .slideX(begin: 0.15, end: 0);
        },
      ),
    );
  }
}

class _EventTypeTile extends StatelessWidget {
  const _EventTypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final EventType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: type.color, width: 2.2)
        : Border.all(color: AppColors.border);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: SizedBox(
        width: 86,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: type.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: border,
              ),
              child: Icon(type.icon, color: type.color, size: 32),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              type.label,
              style: AppTextStyles.captionBold
                  .copyWith(color: AppColors.textPrimary, fontSize: 12),
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

// ===========================================================================
// Banner carousel (auto-rotates)
// ===========================================================================

class _BannerCarousel extends ConsumerStatefulWidget {
  const _BannerCarousel();

  @override
  ConsumerState<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends ConsumerState<_BannerCarousel> {
  final _ctrl = PageController(viewportFraction: 0.92);
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_page + 1) %
          ref.read(bannersProvider).length.clamp(1, 999);
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = ref.watch(bannersProvider);
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _BannerCard(banner: banners[i]),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color:
                      i == _page ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});
  final HomeBanner banner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: banner.imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: banner.accent),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    banner.accent.withValues(alpha: 0.95),
                    banner.accent.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsFill.sparkle,
                            color: Colors.white, size: 11),
                        const SizedBox(width: AppSizes.xs),
                        Text('FEATURED',
                            style: AppTextStyles.overline.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                letterSpacing: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    banner.title,
                    style: AppTextStyles.display.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    banner.subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: AppSizes.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(banner.ctaLabel,
                            style: AppTextStyles.captionBold
                                .copyWith(color: banner.accent)),
                        const SizedBox(width: AppSizes.xs),
                        Icon(PhosphorIconsBold.arrowRight,
                            size: 12, color: banner.accent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Cuisine strip
// ===========================================================================

class _CuisineStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuisines = ref.watch(cuisinesProvider);
    final selected = ref.watch(selectedCuisineProvider);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
        itemCount: cuisines.length,
        itemBuilder: (_, i) {
          final c = cuisines[i];
          final isSel = selected == c.id;
          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(selectedCuisineProvider.notifier).state =
                  isSel ? null : c.id;
            },
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.xs + 2,
              ),
              decoration: BoxDecoration(
                color: isSel ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                border: Border.all(
                  color: isSel ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: AppSizes.xs + 2),
                  Text(
                    c.label,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: isSel ? Colors.white : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Upcoming event (existing, refined)
// ===========================================================================

class _UpcomingEventSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersStreamProvider);
    return orders.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final upcoming = list
            .where((o) =>
                o.orderStatus != OrderStatus.cancelled &&
                o.orderStatus != OrderStatus.delivered)
            .toList()
          ..sort((a, b) {
            final ad = a.eventDate ?? DateTime(2100);
            final bd = b.eventDate ?? DateTime(2100);
            return ad.compareTo(bd);
          });
        if (upcoming.isEmpty) return const SizedBox.shrink();
        final next = upcoming.first;
        final days = next.eventDate == null
            ? null
            : next.eventDate!.difference(DateTime.now()).inDays;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.xl,
            AppSizes.pagePadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR NEXT EVENT', style: AppTextStyles.overline),
              const SizedBox(height: AppSizes.sm),
              AppCard(
                onTap: () =>
                    context.push(AppRoutes.orderDetailFor(next.id)),
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: const Icon(
                        PhosphorIconsDuotone.calendarCheck,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            next.eventDate == null
                                ? 'Date TBD'
                                : Formatters.date(next.eventDate!),
                            style: AppTextStyles.heading2,
                          ),
                          if (days != null)
                            Text(
                              days == 0
                                  ? 'Today'
                                  : days == 1
                                      ? 'Tomorrow'
                                      : 'In $days days',
                              style: AppTextStyles.captionBold.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          if (next.location != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              next.location!,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusBadge(
                          label: next.orderStatus.label,
                          tone: _tone(next.orderStatus),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        const Icon(PhosphorIconsBold.caretRight,
                            color: AppColors.textMuted, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  StatusTone _tone(OrderStatus s) => switch (s) {
        OrderStatus.placed => StatusTone.pending,
        OrderStatus.confirmed => StatusTone.info,
        OrderStatus.preparing => StatusTone.info,
        OrderStatus.dispatched => StatusTone.warning,
        OrderStatus.delivered => StatusTone.success,
        OrderStatus.cancelled => StatusTone.error,
      };
}

// ===========================================================================
// Popular restaurants carousel
// ===========================================================================

class _PopularRestaurants extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(popularRestaurantsProvider);
    return restaurants.when(
      loading: () => _loading(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Text('$e', style: AppTextStyles.caption),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding),
            child: Text(
              'Restaurants coming soon.',
              style: AppTextStyles.bodyMuted,
            ),
          );
        }
        return SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding),
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSizes.md),
            itemCount: list.length,
            itemBuilder: (_, i) => _RestaurantCard(restaurant: list[i])
                .animate(delay: (i * 60).ms)
                .fadeIn(duration: 320.ms)
                .slideX(begin: 0.12, end: 0),
          ),
        );
      },
    );
  }

  Widget _loading() {
    return AppSkeleton(
      loading: true,
      child: SizedBox(
        height: 248,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
          separatorBuilder: (_, __) => const SizedBox(width: AppSizes.md),
          itemCount: 3,
          itemBuilder: (_, __) => Container(
            width: 220,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 132,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppSizes.radiusLg),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 14,
                          width: 130,
                          color: AppColors.surfaceAlt),
                      const SizedBox(height: 8),
                      Container(
                          height: 10,
                          width: 90,
                          color: AppColors.surfaceAlt),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            // For v1 — just jump into event flow. In v2, open a detail sheet.
            context.push(AppRoutes.eventDetails);
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSizes.radiusLg),
                  ),
                  child: SizedBox(
                    height: 132,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (restaurant.logoUrl != null)
                          CachedNetworkImage(
                            imageUrl: restaurant.logoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallback(),
                          )
                        else
                          _fallback(),
                        Positioned(
                          top: AppSizes.sm,
                          right: AppSizes.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(
                                  AppSizes.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.white, size: 12),
                                const SizedBox(width: 2),
                                Text(
                                  '4.${(restaurant.name.length % 5) + 4}',
                                  style:
                                      AppTextStyles.captionBold.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.md,
                    AppSizes.sm,
                    AppSizes.md,
                    AppSizes.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: AppTextStyles.heading3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'North Indian · Mughlai',
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Row(
                        children: [
                          const Icon(PhosphorIconsBold.users,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Text('50+',
                              style: AppTextStyles.caption),
                          const SizedBox(width: AppSizes.sm),
                          const Icon(PhosphorIconsBold.currencyInr,
                              size: 12, color: AppColors.textSecondary),
                          Text('${600 + (restaurant.name.length * 15)}/plate',
                              style: AppTextStyles.captionBold),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        restaurant.name[0],
        style: AppTextStyles.display.copyWith(
          color: Colors.white,
          fontSize: 52,
        ),
      ),
    );
  }
}

// ===========================================================================
// Feature strip (horizontal chips)
// ===========================================================================

class _FeatureStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = <(IconData, String)>[
      (PhosphorIconsDuotone.forkKnife, 'Multi-cuisine menus'),
      (PhosphorIconsDuotone.users, 'Trained service staff'),
      (PhosphorIconsDuotone.table, 'Buffet setup included'),
      (PhosphorIconsDuotone.receipt, 'GST invoice'),
      (PhosphorIconsDuotone.shieldCheck, 'On-time delivery'),
    ];
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.md),
        itemCount: features.length,
        itemBuilder: (_, i) {
          final (icon, label) = features[i];
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: AppSizes.sm),
                Text(label, style: AppTextStyles.bodyBold),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Trust strip
// ===========================================================================

class _TrustStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.xl,
        AppSizes.pagePadding,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsDuotone.medal,
                color: AppColors.accentDark, size: 30),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trusted by 500+ hosts this year',
                      style: AppTextStyles.bodyBold),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      for (int i = 0; i < 5; i++)
                        const Icon(Icons.star_rounded,
                            color: AppColors.accentDark, size: 14),
                      const SizedBox(width: AppSizes.xs),
                      Text('4.9 · 2,100+ reviews',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.accentDark)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

