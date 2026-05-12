import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../core/utils/formatters.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/customer_line.dart';
import '../../../shared/widgets/shimmer.dart';
import '../widgets/banquet_bottom_nav.dart';

/// Operator (banquet) home — a real dashboard instead of the generic
/// role landing scaffold. Surfaces what the operator actually needs at
/// a glance: how many bookings are awaiting review, how many they've
/// already accepted that still need staffing, and a peek at the most
/// recent pending requests.
class BanquetHomeScreen extends ConsumerWidget {
  const BanquetHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final inboxAsync = ref.watch(banquetInboxProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Banquet'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsBold.signOut),
            tooltip: 'Sign out',
            onPressed: () async {
              if (AppConfig.hasSupabase) await sb.auth.signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      bottomBar: const BanquetBottomNav(active: BanquetNavTab.home),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(banquetInboxProvider);
          await ref.read(banquetInboxProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.xxl,
          ),
          children: [
            _Greeting(profile: profile),
            const SizedBox(height: AppSizes.lg),
            _StatsRow(inboxAsync: inboxAsync),
            const SizedBox(height: AppSizes.xl),
            _SectionHeader('Quick actions'),
            const SizedBox(height: AppSizes.sm),
            _ActionGrid(),
            const SizedBox(height: AppSizes.xl),
            _SectionHeader(
              'Recent bookings',
              trailing: 'See all',
              onTrailingTap: () => context.push(AppRoutes.banquetInbox),
            ),
            const SizedBox(height: AppSizes.sm),
            _RecentBookings(inboxAsync: inboxAsync),
          ]
              .animate(interval: 60.ms)
              .fadeIn(duration: 280.ms)
              .slideY(begin: 0.05, end: 0),
        ),
      ),
    );
  }
}

// ───────────────────────── Greeting ─────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});
  final dynamic profile;

  String get _timeOfDayGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?.name as String?;
    final headline = name != null && name.trim().isNotEmpty
        ? '$_timeOfDayGreeting, $name'
        : _timeOfDayGreeting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headline, style: AppTextStyles.display),
        const SizedBox(height: 2),
        Text(
          'Here is what is happening at your venues today.',
          style: AppTextStyles.bodyMuted,
        ),
      ],
    );
  }
}

// ───────────────────────── Stats ─────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.inboxAsync});
  final AsyncValue<List<BanquetInboxEvent>> inboxAsync;

  @override
  Widget build(BuildContext context) {
    // While the inbox is still loading on a fresh open, render shimmer
    // placeholders so the page reveals its real shape immediately
    // instead of jumping in once the data arrives.
    if (inboxAsync.isLoading && !inboxAsync.hasValue) {
      return const Row(
        children: [
          Expanded(child: ShimmerStatCard()),
          SizedBox(width: AppSizes.sm),
          Expanded(child: ShimmerStatCard()),
          SizedBox(width: AppSizes.sm),
          Expanded(child: ShimmerStatCard()),
        ],
      );
    }
    final stats = _computeStats(inboxAsync.valueOrNull ?? const []);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Pending review',
            value: stats.pending,
            icon: PhosphorIconsDuotone.clock,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _StatCard(
            label: 'Accepted',
            value: stats.accepted,
            icon: PhosphorIconsDuotone.checkCircle,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _StatCard(
            label: 'This week',
            value: stats.thisWeek,
            icon: PhosphorIconsDuotone.calendar,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  _Stats _computeStats(List<BanquetInboxEvent> events) {
    final now = DateTime.now();
    final weekEnd = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 7));
    var pending = 0, accepted = 0, thisWeek = 0;
    for (final e in events) {
      if (e.status == BanquetEventStatus.pending) pending++;
      if (e.status == BanquetEventStatus.accepted) accepted++;
      if (!e.eventDate.isBefore(now) && e.eventDate.isBefore(weekEnd)) {
        thisWeek++;
      }
    }
    return _Stats(pending: pending, accepted: accepted, thisWeek: thisWeek);
  }
}

class _Stats {
  const _Stats({
    required this.pending,
    required this.accepted,
    required this.thisWeek,
  });
  final int pending;
  final int accepted;
  final int thisWeek;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            '$value',
            style: AppTextStyles.display.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Section header ─────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.trailing, this.onTrailingTap});
  final String text;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.heading2.copyWith(fontSize: 16),
          ),
        ),
        if (trailing != null)
          InkWell(
            onTap: onTrailingTap,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: 4,
              ),
              child: Text(
                trailing!,
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Quick actions ─────────────────────────

class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final actions = <_Action>[
      _Action(
        label: 'Incoming\nbookings',
        icon: PhosphorIconsDuotone.calendarCheck,
        color: AppColors.warning,
        onTap: () => context.push(AppRoutes.banquetInbox),
      ),
      _Action(
        label: 'Assign\nmanagers',
        icon: PhosphorIconsDuotone.userCircleGear,
        color: AppColors.primary,
        onTap: () =>
            context.push('${AppRoutes.banquetInbox}?filter=accepted'),
      ),
      _Action(
        label: 'My\nvenues',
        icon: PhosphorIconsDuotone.buildings,
        color: AppColors.info,
        onTap: () => context.push(AppRoutes.banquetVenues),
      ),
      _Action(
        label: 'Equipment\n& inventory',
        icon: PhosphorIconsDuotone.package,
        color: AppColors.success,
        onTap: () => context.push(AppRoutes.banquetInventory),
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSizes.sm,
      crossAxisSpacing: AppSizes.sm,
      childAspectRatio: 1.6,
      children: [
        for (final a in actions) _ActionTile(action: a),
      ],
    );
  }
}

class _Action {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});
  final _Action action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              Text(
                action.label,
                style: AppTextStyles.bodyBold.copyWith(
                  fontSize: 13,
                  height: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Recent bookings ─────────────────────────

class _RecentBookings extends StatelessWidget {
  const _RecentBookings({required this.inboxAsync});
  final AsyncValue<List<BanquetInboxEvent>> inboxAsync;

  @override
  Widget build(BuildContext context) {
    return inboxAsync.when(
      loading: () => const Column(
        children: [
          ShimmerBookingCard(),
          SizedBox(height: AppSizes.sm),
          ShimmerBookingCard(),
          SizedBox(height: AppSizes.sm),
          ShimmerBookingCard(),
        ],
      ),
      error: (e, _) => AppCard(
        child: Text('Could not load recent bookings: $e',
            style: AppTextStyles.caption),
      ),
      data: (rows) {
        // Show the three most recently received pending bookings —
        // falls back to any recent ones when nothing is pending.
        var pool = rows
            .where((r) => r.status == BanquetEventStatus.pending)
            .toList();
        if (pool.isEmpty) pool = List.of(rows);
        // Newest received first (matches the inbox sort). Falls back
        // to event date if a row is missing created_at for any reason.
        pool.sort((a, b) {
          final ac = a.createdAt ?? a.eventDate;
          final bc = b.createdAt ?? b.eventDate;
          return bc.compareTo(ac);
        });
        final preview = pool.take(3).toList(growable: false);
        if (preview.isEmpty) {
          return AppCard(
            child: Row(
              children: [
                const Icon(PhosphorIconsDuotone.calendarBlank,
                    size: 28, color: AppColors.textMuted),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No bookings yet',
                          style: AppTextStyles.bodyBold),
                      const SizedBox(height: 2),
                      Text(
                        'New event requests routed to your venues will show up here.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final e in preview) ...[
              _RecentTile(event: e),
              const SizedBox(height: AppSizes.sm),
            ],
          ],
        );
      },
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.event});
  final BanquetInboxEvent event;

  Color get _statusColor => switch (event.status) {
        BanquetEventStatus.pending => AppColors.warning,
        BanquetEventStatus.accepted => AppColors.success,
        BanquetEventStatus.declined => AppColors.textMuted,
        BanquetEventStatus.cancelled => AppColors.textMuted,
        BanquetEventStatus.completed => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.md),
      onTap: () =>
          context.push(AppRoutes.banquetBookingDetailFor(event.id)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(PhosphorIconsDuotone.calendarBlank,
                color: _statusColor, size: 22),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomerLine(
                  bookingId: event.id,
                  name: event.customerName,
                  phone: event.customerPhone,
                  email: event.customerEmail,
                  compact: true,
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.date(event.eventDate)} · ${event.session} · ${event.guestCount} guests',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            ),
            child: Text(
              event.status.label,
              style: AppTextStyles.captionBold.copyWith(
                color: _statusColor,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
