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
import '../../../data/models/event_draft.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/favorites_providers.dart';
import '../../../shared/providers/home_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/notification_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/safe_net_image.dart';
import '../../../shared/widgets/user_bottom_nav.dart';
import '../widgets/address_picker_sheet.dart';

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  final GlobalKey _restaurantsHeaderKey = GlobalKey();
  // The last `t` nonce we already scrolled for. Comparing per-click nonces
  // (rather than a bool) makes the scroll fire on every fresh visit, even
  // when go_router reuses the same UserHomeScreen state instance.
  String? _lastHandledNonce;

  Future<void> _refresh() async {
    ref.invalidate(restaurantsProvider);
    ref.invalidate(eventCategoriesProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(addressesProvider);
    await ref.read(restaurantsProvider.future);
  }

  void _maybeScrollToRestaurants() {
    final params = GoRouterState.of(context).uri.queryParameters;
    if (params['scrollTo'] != 'restaurants') return;
    final nonce = params['t'];
    if (nonce == null || nonce == _lastHandledNonce) return;
    final ctx = _restaurantsHeaderKey.currentContext;
    if (ctx == null) return;
    _lastHandledNonce = nonce;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeScrollToRestaurants());
    return AppScaffold(
      padded: false,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const _LocationHeader(),
            const SliverToBoxAdapter(child: _SearchBar()),
            const SliverToBoxAdapter(child: _HeroOrDraft()),
            const _SectionHeader(title: "What's the occasion?"),
            const SliverToBoxAdapter(child: _EventCategoriesGrid()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.md)),
            _SectionHeader(
              title: 'Curated for events',
              trailing: 'See all',
              onTrailingTap: () => context.push(AppRoutes.search),
            ),
            const SliverToBoxAdapter(child: _CollectionsScroll()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.md)),
            const SliverToBoxAdapter(child: _FilterChipsRow()),
            _SectionHeader(
              key: _restaurantsHeaderKey,
              title: 'Restaurants nearby',
            ),
            const _RestaurantList(),
            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xxxl)),
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
          const _NotificationBell(),
          const SizedBox(width: AppSizes.sm),
          _AvatarButton(
            avatarUrl: ref.watch(currentProfileProvider).valueOrNull?.avatarUrl,
            fallbackLabel:
                ref.watch(currentProfileProvider).valueOrNull?.name,
            onTap: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider);
    final hasUnread = count > 0;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(AppRoutes.notifications);
      },
      borderRadius: BorderRadius.circular(100),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceAlt,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Icon(
              hasUnread
                  ? Icons.notifications_rounded
                  : Icons.notifications_outlined,
              color: hasUnread ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
          ),
          if (hasUnread)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 220.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: 180.ms),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.onTap,
    this.avatarUrl,
    this.fallbackLabel,
  });
  final VoidCallback onTap;
  final String? avatarUrl;
  final String? fallbackLabel;

  String _initial() {
    final n = fallbackLabel?.trim() ?? '';
    if (n.isNotEmpty) return n[0].toUpperCase();
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = avatarUrl != null && avatarUrl!.isNotEmpty;
    Widget child;
    if (hasPhoto) {
      child = ClipOval(
        child: SizedBox(
          width: 42,
          height: 42,
          child: SafeNetImage(
            url: avatarUrl!,
            errorBuilder: (_) => _placeholder(),
            placeholder: (_) => _placeholder(),
          ),
        ),
      );
    } else {
      child = _placeholder();
    }
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
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _placeholder() {
    final initial = _initial();
    if (initial.isEmpty) {
      return const Icon(Icons.person_outline_rounded,
          color: AppColors.textSecondary, size: 22);
    }
    return Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.bodyBold.copyWith(
          color: AppColors.primary,
          fontSize: 16,
        ),
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
          _FilterButton(),
        ],
      ),
    );
  }
}

// ───────────────────────── Filter button + sheet ─────────────────────────

class _FilterButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(homeSortProvider);
    final hasFilter = selected != HomeSort.relevance;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _showFilterSheet(context, ref);
      },
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(Icons.tune_rounded,
                color: Colors.white, size: 22),
          ),
          if (hasFilter)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Cap at 85% so the sheet never owns the whole screen.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => const _FilterSheet(),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  static const _purple = Color(0xFF7C3AED);
  static const _purpleLt = Color(0xFFF3E8FF);
  static const _green = Color(0xFF1BA672);
  static const _greenLt = Color(0xFFEAFAF1);
  static const _orange = Color(0xFFE97A2B);
  static const _orangeLt = Color(0xFFFFF4EB);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(homeSortProvider);
    final hasFilter = selected != HomeSort.relevance;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: AppTextStyles.heading1.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personalize what you see',
                          style: AppTextStyles.bodyMuted
                              .copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (hasFilter)
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(homeSortProvider.notifier).state =
                            HomeSort.relevance;
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        'Clear all',
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const _FilterSectionLabel('Sort by'),
            _FilterGroup(
              options: const [
                _FilterOptionData(
                  sort: HomeSort.relevance,
                  icon: Icons.auto_awesome_rounded,
                  iconBg: _purpleLt,
                  iconColor: _purple,
                  description: "What's right for you",
                ),
                _FilterOptionData(
                  sort: HomeSort.rating,
                  icon: Icons.star_rounded,
                  iconBg: Color(0xFFFFF8E7),
                  iconColor: Color(0xFFC4922A),
                  description: 'Top-rated kitchens',
                ),
                _FilterOptionData(
                  sort: HomeSort.fastest,
                  icon: Icons.bolt_rounded,
                  iconBg: Color(0xFFFFF1F2),
                  iconColor: Color(0xFFE23744),
                  description: 'Quickest delivery first',
                ),
                _FilterOptionData(
                  sort: HomeSort.budget,
                  icon: Icons.payments_rounded,
                  iconBg: _greenLt,
                  iconColor: _green,
                  description: 'Lowest price per plate',
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            const _FilterSectionLabel('Quick filters'),
            _FilterGroup(
              options: const [
                _FilterOptionData(
                  sort: HomeSort.veg,
                  icon: Icons.eco_rounded,
                  iconBg: _greenLt,
                  iconColor: _green,
                  description: 'Only vegetarian kitchens',
                ),
                _FilterOptionData(
                  sort: HomeSort.offers,
                  icon: Icons.local_offer_rounded,
                  iconBg: _orangeLt,
                  iconColor: _orange,
                  description: 'Deals & discounts',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _FilterOptionData {
  const _FilterOptionData({
    required this.sort,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.description,
  });
  final HomeSort sort;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String description;
}

class _FilterGroup extends ConsumerWidget {
  const _FilterGroup({required this.options});
  final List<_FilterOptionData> options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              _FilterOptionRow(data: options[i]),
              if (i < options.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Divider(
                    height: 1,
                    color: AppColors.border.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterOptionRow extends ConsumerWidget {
  const _FilterOptionRow({required this.data});
  final _FilterOptionData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(homeSortProvider) == data.sort;
    return Material(
      color: on
          ? data.iconColor.withValues(alpha: 0.06)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(homeSortProvider.notifier).state = data.sort;
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, size: 18, color: data.iconColor),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.sort.label,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: on
                            ? AppColors.textPrimary
                            : AppColors.textPrimary,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.description,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: on ? data.iconColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: on
                        ? data.iconColor
                        : AppColors.border,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: on
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Hero or draft picker ─────────────────────────

/// Switches the hero spot between the marketing banner and a "Continue
/// planning" card whenever the user has an in-progress draft event.
class _HeroOrDraft extends ConsumerWidget {
  const _HeroOrDraft();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(eventDraftProvider);
    final progress = _DraftProgress.from(draft);
    if (!progress.hasStarted) return const _HeroBanner();
    return _DraftEventCard(draft: draft, progress: progress);
  }
}

// ───────────────────────── Draft event card ─────────────────────────

class _DraftEventCard extends StatelessWidget {
  const _DraftEventCard({required this.draft, required this.progress});
  final EventDraft draft;
  final _DraftProgress progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(AppRoutes.eventDetails);
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.heroGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CONTINUE PLANNING',
                      style: AppTextStyles.captionBold.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusPill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'DRAFT',
                        style: AppTextStyles.captionBold.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  progress.title,
                  style: AppTextStyles.display.copyWith(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.md,
                  runSpacing: 4,
                  children: [
                    _DraftMeta(
                      icon: Icons.calendar_today_outlined,
                      text: progress.dateText,
                    ),
                    _DraftMeta(
                      icon: Icons.group_outlined,
                      text: '${draft.guestCount} guests',
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusPill),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        progress.nextHint,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Continue',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.05, end: 0),
    );
  }
}

class _DraftMeta extends StatelessWidget {
  const _DraftMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.92)),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTextStyles.body.copyWith(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _DraftProgress {
  const _DraftProgress({
    required this.fraction,
    required this.title,
    required this.dateText,
    required this.nextHint,
    required this.hasStarted,
  });

  final double fraction;
  final String title;
  final String dateText;
  final String nextHint;
  final bool hasStarted;

  static _DraftProgress from(EventDraft d) {
    final hasStarted = d.session != null ||
        d.date != null ||
        (d.location != null && d.location!.trim().isNotEmpty) ||
        d.tierId != null ||
        d.banquetVenueId != null;

    final steps = <bool>[
      d.session != null,
      d.date != null,
      d.startTime != null && d.endTime != null,
      d.location != null && d.location!.trim().isNotEmpty,
      d.tierId != null,
      d.banquetVenueId != null,
    ];
    final filled = steps.where((e) => e).length;
    final fraction = filled / steps.length;

    String nextHint;
    if (d.session == null) {
      nextHint = 'Pick the session to start';
    } else if (d.date == null) {
      nextHint = 'Pick a date to lock pricing';
    } else if (d.startTime == null || d.endTime == null) {
      nextHint = 'Set the start & end time';
    } else if (d.location == null || d.location!.trim().isEmpty) {
      nextHint = 'Add the event address';
    } else if (d.tierId == null) {
      nextHint = 'Pick a tier that fits your budget';
    } else if (d.banquetVenueId == null) {
      nextHint = 'Pick a banquet venue to finish';
    } else {
      nextHint = 'Add dishes to finalise the menu';
    }

    return _DraftProgress(
      fraction: fraction,
      title: _composeTitle(d),
      dateText: _composeDate(d),
      nextHint: nextHint,
      hasStarted: hasStarted,
    );
  }

  static String _composeTitle(EventDraft d) {
    // Custom name takes priority — e.g. "Aanya's Sangeet" — and falls
    // back to a composed label only when the user hasn't named it yet.
    final custom = d.eventName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final session = d.session;
    if (session != null) return '$session for ${d.guestCount}';
    return 'Your event for ${d.guestCount}';
  }

  static String _composeDate(EventDraft d) {
    if (d.date == null) return 'Date not set';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dt = d.date!;
    final base =
        '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
    if (d.startTime == null) return base;
    final st = d.startTime!;
    final hour12 = st.hour % 12 == 0 ? 12 : st.hour % 12;
    final ampm = st.hour >= 12 ? 'PM' : 'AM';
    final mm = st.minute.toString().padLeft(2, '0');
    return '$base · $hour12:$mm $ampm';
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
  const _SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

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
              InkWell(
                onTap: onTrailingTap == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onTrailingTap!();
                      },
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.xs, vertical: AppSizes.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        trailing!,
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary, fontSize: 13),
                      ),
                      if (onTrailingTap != null) ...[
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.primary),
                      ],
                    ],
                  ),
                ),
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
            mainAxisSpacing: AppSizes.md,
            crossAxisSpacing: AppSizes.sm,
            // Image stays square; the label sits underneath. Aspect ratio
            // is tuned so 2-line names ("Get-together", "House Party") wrap
            // without overflowing the cell — 0.78 was too tight.
            childAspectRatio: 0.68,
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

  /// Hard-coded slug → Unsplash photo for each occasion. Picked from URLs
  /// already proven to load in this codebase (menu repo + onboarding +
  /// venue picker) so they're known-good. Swap freely — the tile falls
  /// back to the icon-on-tinted-bg design if the URL ever 404s.
  static const _imageBySlug = <String, String>{
    'birthday':
        'https://images.unsplash.com/photo-1558636508-e0db3814bd1d?auto=format&fit=crop&w=600&q=80',
    'wedding':
        'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=600&q=80',
    'corporate':
        'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=600&q=80',
    'house':
        'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80',
    'kitty':
        'https://images.unsplash.com/photo-1585937421612-70a008356fbe?auto=format&fit=crop&w=600&q=80',
    // Festival — swapped from a 404'd URL to a verified menu-repo photo.
    'festival':
        'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?auto=format&fit=crop&w=600&q=80',
    'anniversary':
        'https://images.unsplash.com/photo-1530023367847-a683933f4172?auto=format&fit=crop&w=600&q=80',
    'gettogether':
        'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=600&q=80',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = AppColors.fromHex(category.bgHex);
    final fg = AppColors.fromHex(category.iconHex, fallback: AppColors.primary);
    final imageUrl = _imageBySlug[category.slug];

    Widget iconFallback() => Container(
          color: bg,
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              materialIconByName(category.iconName),
              color: fg,
              size: 20,
            ),
          ),
        );

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Square photo on top.
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    SafeNetImage(
                      url: imageUrl,
                      errorBuilder: (_) => iconFallback(),
                      placeholder: (_) => iconFallback(),
                    )
                  else
                    iconFallback(),
                  // Subtle dark scrim helps the photo read as tappable
                  // and gives consistent contrast against the label below.
                  if (imageUrl != null)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.6, 1.0],
                          colors: [
                            Colors.transparent,
                            Color(0x1F000000),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Label below — capped at 2 lines so "Get-together" etc. wrap
          // cleanly without resizing the tile.
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.captionBold.copyWith(
              fontSize: 11,
              height: 1.15,
              color: AppColors.textPrimary,
            ),
          ),
        ],
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
