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
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/status_badge.dart';
import 'my_events_screen.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final firstName = (profile?.name?.split(' ').first.trim().isNotEmpty ?? false)
        ? profile!.name!.split(' ').first
        : (profile?.email?.split('@').first ?? 'there');

    return AppScaffold(
      padded: false,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.pageBg,
            surfaceTintColor: AppColors.pageBg,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: const Icon(
                    PhosphorIconsDuotone.confetti,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Text('Dawat',
                    style: AppTextStyles.display.copyWith(fontSize: 22)),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSizes.sm),
                child: IconButton(
                  icon: const Icon(
                    PhosphorIconsDuotone.userCircle,
                    color: AppColors.primary,
                  ),
                  iconSize: 28,
                  tooltip: 'My profile',
                  onPressed: () => context.push(AppRoutes.profile),
                ),
              ),
            ],
          ),

          // Greeting
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.sm,
                AppSizes.pagePadding,
                AppSizes.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()},',
                    style: AppTextStyles.bodyMuted
                        .copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(firstName, style: AppTextStyles.display),
                ],
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.08, end: 0),
            ),
          ),

          // Hero — plan new event
          SliverToBoxAdapter(child: _PlanEventCard()),

          // Upcoming event preview (realtime)
          SliverToBoxAdapter(child: _UpcomingEventSection()),

          // What we offer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.xl,
                AppSizes.pagePadding,
                AppSizes.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHAT WE OFFER',
                      style: AppTextStyles.overline),
                  const SizedBox(height: AppSizes.xs),
                  Text('A premium catering experience',
                      style: AppTextStyles.heading1),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _FeatureGrid()),

          const SliverPadding(
            padding: EdgeInsets.only(bottom: AppSizes.xxl),
          ),
        ],
      ),
      bottomBar: const _BottomNav(),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan-new-event hero card
// ---------------------------------------------------------------------------

class _PlanEventCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative sparkle glyphs (soft, far right)
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.10,
                child: Icon(
                  PhosphorIconsFill.sparkle,
                  color: Colors.white,
                  size: 160,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroOverline('READY TO CELEBRATE'),
                const SizedBox(height: AppSizes.sm),
                Text(
                  'Plan a new event',
                  style: AppTextStyles.display.copyWith(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  'Curated menus, setup, service — delivered to your venue.',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: AppSizes.xl),
                _HeroCtaButton(
                  label: 'Start Planning',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push(AppRoutes.eventDetails);
                  },
                ),
              ],
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 500.ms, delay: 100.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }
}

class _HeroOverline extends StatelessWidget {
  const _HeroOverline(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.xs + 1,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(PhosphorIconsFill.sparkle,
              color: AppColors.accent, size: 12),
          const SizedBox(width: AppSizes.xs),
          Text(
            text,
            style: AppTextStyles.overline.copyWith(
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCtaButton extends StatelessWidget {
  const _HeroCtaButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyBold
                    .copyWith(color: AppColors.primary, fontSize: 15),
              ),
              const SizedBox(width: AppSizes.sm),
              const Icon(PhosphorIconsBold.arrowRight,
                  color: AppColors.primary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming event preview (realtime — only shows if user has bookings)
// ---------------------------------------------------------------------------

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
                onTap: () => context.push(AppRoutes.orderDetailFor(next.id)),
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
                          if (next.location != null)
                            Text(
                              next.location!,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: AppSizes.xs),
                          StatusBadge(
                            label: next.orderStatus.label,
                            tone: _tone(next.orderStatus),
                          ),
                        ],
                      ),
                    ),
                    const Icon(PhosphorIconsBold.caretRight,
                        color: AppColors.textMuted),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms)
                  .slideY(begin: 0.08, end: 0),
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

// ---------------------------------------------------------------------------
// Feature grid
// ---------------------------------------------------------------------------

class _FeatureGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = <_Feature>[
      _Feature('Multi-cuisine menus', 'North Indian, Awadhi, Goan & more',
          PhosphorIconsDuotone.forkKnife),
      _Feature('Trained service boys', 'Uniformed, experienced staff',
          PhosphorIconsDuotone.users),
      _Feature('Buffet setup included', 'Tables, linens, décor',
          PhosphorIconsDuotone.table),
      _Feature('GST invoice', 'Compliant billing on request',
          PhosphorIconsDuotone.receipt),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        0,
      ),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSizes.md,
        crossAxisSpacing: AppSizes.md,
        childAspectRatio: 1.05,
        children: [
          for (int i = 0; i < features.length; i++)
            _FeatureTile(features[i])
                .animate(delay: (i * 70).ms)
                .fadeIn(duration: 320.ms)
                .slideY(begin: 0.08, end: 0),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile(this.f);
  final _Feature f;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(f.icon, color: AppColors.primary, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.title,
                  style: AppTextStyles.heading3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(f.subtitle,
                  style: AppTextStyles.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav
// ---------------------------------------------------------------------------

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: PhosphorIconsFill.house,
              label: 'Home',
              selected: true,
              onTap: () {},
            ),
            _NavItem(
              icon: PhosphorIconsBold.calendarCheck,
              label: 'Events',
              selected: false,
              onTap: () => context.push(AppRoutes.myEvents),
            ),
            _NavItem(
              icon: PhosphorIconsBold.userCircle,
              label: 'Profile',
              selected: false,
              onTap: () => context.push(AppRoutes.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.captionBold.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
