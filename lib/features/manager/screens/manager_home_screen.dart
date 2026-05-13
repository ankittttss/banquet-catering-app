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
import '../../../data/models/event_assignment.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/providers/staffing_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/customer_line.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer.dart';

/// Manager dashboard — the manager's mental model is "what am I running
/// and when?", so we lead with stats + a time-grouped list of events.
/// New-assignment toasts are still wired so a freshly assigned event
/// pings the manager while they're on the screen.
class ManagerHomeScreen extends ConsumerWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In-app ping when a new manager assignment lands while the screen is
    // open. Relies on Supabase Realtime streaming `event_assignments` —
    // trigger Phase 25 also writes a persisted notification row.
    ref.listen<AsyncValue<List<EventAssignment>>>(
      myAssignmentsProvider,
      (prev, next) {
        final prevCount = prev?.valueOrNull
                ?.where((a) =>
                    a.roleOnEvent == EventAssignmentRole.manager)
                .length ??
            0;
        final nextCount = next.valueOrNull
                ?.where((a) =>
                    a.roleOnEvent == EventAssignmentRole.manager)
                .length ??
            0;
        if (nextCount > prevCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('New event assigned to you — check your list.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    final assignments = ref.watch(myAssignmentsProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Manager'),
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myAssignmentsProvider);
          ref.invalidate(eventStaffProvider);
          await ref.read(myAssignmentsProvider.future);
        },
        child: assignments.when(
          loading: () => const _ManagerLoading(),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(myAssignmentsProvider),
          ),
          data: (rows) {
            final managed = rows
                .where((r) => r.roleOnEvent == EventAssignmentRole.manager)
                .toList(growable: false);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.xxl,
              ),
              children: [
                _ManagerDashboardHero(profile: profile, events: managed),
                const SizedBox(height: AppSizes.xl),
                if (managed.isEmpty)
                  const _EmptyEventsHint()
                else
                  _GroupedEvents(events: managed),
              ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 280.ms)
                  .slideY(begin: 0.05, end: 0),
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── Greeting ─────────────────────────

class _ManagerDashboardHero extends StatelessWidget {
  const _ManagerDashboardHero({
    required this.profile,
    required this.events,
  });

  final UserProfile? profile;
  final List<EventAssignment> events;

  String get _timeOfDayGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?.name;
    final displayName = name != null && name.trim().isNotEmpty
        ? name.trim().split(' ').first
        : 'manager';
    final stats = _ManagerStats.from(events);
    final nextEvent = _nextUpcoming(events);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.accentDark.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_timeOfDayGreeting, $displayName',
                            style: AppTextStyles.display.copyWith(
                              color: Colors.white,
                              fontSize: 25,
                            ),
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            'Your event command board for service day.',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeroBadge(
                      icon: PhosphorIconsBold.userGear,
                      label: '${stats.total} assigned',
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        value: '${stats.today}',
                        label: 'Today',
                        icon: PhosphorIconsBold.calendarCheck,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _HeroMetric(
                        value: '${stats.tomorrow}',
                        label: 'Tomorrow',
                        icon: PhosphorIconsDuotone.sun,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _HeroMetric(
                        value: '${stats.thisWeek}',
                        label: 'This week',
                        icon: PhosphorIconsBold.sparkle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          PhosphorIconsBold.bellRinging,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nextEvent == null
                                  ? 'No upcoming service pressure'
                                  : 'Next event ${_urgencyLabel(nextEvent.eventDate)}',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextEvent == null
                                  ? 'New manager assignments will appear here.'
                                  : [
                                      if (nextEvent.eventLocation != null)
                                        nextEvent.eventLocation!,
                                      if (nextEvent.eventSession != null)
                                        nextEvent.eventSession!,
                                      '${nextEvent.eventGuestCount ?? 0} guests',
                                    ].join(' - '),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: Colors.white,
              fontSize: 10,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.82), size: 17),
          const SizedBox(height: AppSizes.sm),
          Text(
            value,
            style: AppTextStyles.display.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 10,
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ManagerStats {
  const _ManagerStats({
    required this.today,
    required this.tomorrow,
    required this.thisWeek,
    required this.total,
  });

  final int today;
  final int tomorrow;
  final int thisWeek;
  final int total;

  factory _ManagerStats.from(List<EventAssignment> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));
    var todayCount = 0;
    var tomorrowCount = 0;
    var weekCount = 0;
    for (final event in events) {
      final date = event.eventDate;
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (day == today) todayCount++;
      if (day == tomorrow) tomorrowCount++;
      if (!day.isBefore(today) && day.isBefore(weekEnd)) weekCount++;
    }
    return _ManagerStats(
      today: todayCount,
      tomorrow: tomorrowCount,
      thisWeek: weekCount,
      total: events.length,
    );
  }
}

EventAssignment? _nextUpcoming(List<EventAssignment> events) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final upcoming = events
      .where((event) =>
          event.eventDate != null && !event.eventDate!.isBefore(today))
      .toList(growable: false)
    ..sort((a, b) => a.eventDate!.compareTo(b.eventDate!));
  return upcoming.isEmpty ? null : upcoming.first;
}

String _urgencyLabel(DateTime? eventDate) {
  if (eventDate == null) return 'soon';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(eventDate.year, eventDate.month, eventDate.day);
  final days = target.difference(today).inDays;
  if (days < 0) return '${-days}d ago';
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 7) return 'in ${days}d';
  if (days < 30) return 'in ${(days / 7).round()}w';
  return 'in ${(days / 30).round()}mo';
}

// ───────────────────────── Stats row ─────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.events});
  final List<EventAssignment> events;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfWeek = today.add(const Duration(days: 7));
    var todayCount = 0;
    var weekCount = 0;
    for (final e in events) {
      final d = e.eventDate;
      if (d == null) continue;
      final dd = DateTime(d.year, d.month, d.day);
      if (dd == today) todayCount++;
      if (!dd.isBefore(today) && dd.isBefore(endOfWeek)) weekCount++;
    }
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Today',
            value: todayCount,
            icon: PhosphorIconsDuotone.sun,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _StatCard(
            label: 'This week',
            value: weekCount,
            icon: PhosphorIconsDuotone.calendar,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: _StatCard(
            label: 'All assigned',
            value: events.length,
            icon: PhosphorIconsDuotone.userCircleGear,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
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

// ───────────────────────── Grouped event list ─────────────────────────

/// Buckets the manager's events into Today / Tomorrow / This week /
/// Next week / Later / Past. Unlike the operator inbox (where the
/// operator just wants to see what just landed), the manager's mental
/// model is "what am I running, and when?" — so the date-based view
/// here fits.
class _GroupedEvents extends StatelessWidget {
  const _GroupedEvents({required this.events});
  final List<EventAssignment> events;

  static List<MapEntry<String, List<EventAssignment>>> _bucket(
    List<EventAssignment> events,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfThisWeek = today.add(const Duration(days: 7));
    final endOfNextWeek = today.add(const Duration(days: 14));

    final buckets = <String, List<EventAssignment>>{
      'Today': [],
      'Tomorrow': [],
      'This week': [],
      'Next week': [],
      'Later': [],
      'Past': [],
    };
    for (final a in events) {
      final d = a.eventDate;
      if (d == null) {
        buckets['Later']!.add(a);
        continue;
      }
      final dd = DateTime(d.year, d.month, d.day);
      if (dd.isBefore(today)) {
        buckets['Past']!.add(a);
      } else if (dd == today) {
        buckets['Today']!.add(a);
      } else if (dd == tomorrow) {
        buckets['Tomorrow']!.add(a);
      } else if (dd.isBefore(endOfThisWeek)) {
        buckets['This week']!.add(a);
      } else if (dd.isBefore(endOfNextWeek)) {
        buckets['Next week']!.add(a);
      } else {
        buckets['Later']!.add(a);
      }
    }
    for (final list in buckets.values) {
      list.sort((a, b) {
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });
    }
    return buckets.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _bucket(events);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var gi = 0; gi < groups.length; gi++) ...[
          _GroupHeader(
            label: groups[gi].key,
            count: groups[gi].value.length,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < groups[gi].value.length; i++) ...[
            _EventCardV2(assignment: groups[gi].value[i]),
            if (i != groups[gi].value.length - 1)
              const SizedBox(height: AppSizes.md),
          ],
          if (gi != groups.length - 1) const SizedBox(height: AppSizes.lg),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isUrgent = label == 'Today' || label == 'Tomorrow';
    final color = isUrgent ? AppColors.primary : AppColors.textSecondary;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.captionBold.copyWith(
            color: color,
            fontSize: 11,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.captionBold.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Loading state ─────────────────────────

class _ManagerLoading extends StatelessWidget {
  const _ManagerLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.xxl,
      ),
      children: const [
        ShimmerBox(width: 220, height: 28),
        SizedBox(height: 4),
        ShimmerBox(width: 180, height: 14),
        SizedBox(height: AppSizes.lg),
        Row(
          children: [
            Expanded(child: ShimmerStatCard()),
            SizedBox(width: AppSizes.sm),
            Expanded(child: ShimmerStatCard()),
            SizedBox(width: AppSizes.sm),
            Expanded(child: ShimmerStatCard()),
          ],
        ),
        SizedBox(height: AppSizes.xl),
        ShimmerBookingCard(),
        SizedBox(height: AppSizes.md),
        ShimmerBookingCard(),
      ],
    );
  }
}

// ───────────────────────── Empty state ─────────────────────────

class _EmptyEventsHint extends StatelessWidget {
  const _EmptyEventsHint();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: PhosphorIconsDuotone.calendarBlank,
      title: 'Nothing on your plate',
      message: 'Your banquet operator will assign you to events here.',
    );
  }
}

// ───────────────────────── Event card ─────────────────────────

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.assignment});
  final EventAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = assignment.eventDate;
    final staff = ref.watch(eventStaffProvider(assignment.eventId));
    final serviceBoyCount = staff.valueOrNull
            ?.where(
                (a) => a.roleOnEvent == EventAssignmentRole.serviceBoy)
            .length ??
        0;
    return AppCard(
      onTap: () =>
          context.push(AppRoutes.managerEventDetailFor(assignment.eventId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomerLine(
                  bookingId: assignment.eventId,
                  name: assignment.customerName,
                  phone: assignment.customerPhone,
                  email: assignment.customerEmail,
                ),
              ),
              const Icon(
                PhosphorIconsBold.userGear,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            date != null ? Formatters.date(date) : 'Date TBD',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 4),
          Text(
            '${assignment.eventSession ?? ''} · ${assignment.eventGuestCount ?? 0} guests',
            style: AppTextStyles.caption,
          ),
          if (assignment.eventLocation != null) ...[
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                const Icon(
                  PhosphorIconsDuotone.mapPin,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    assignment.eventLocation!,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(
                PhosphorIconsDuotone.users,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '$serviceBoyCount service '
                '${serviceBoyCount == 1 ? 'boy' : 'boys'} assigned',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.managerEventDetailFor(assignment.eventId),
                  ),
                  icon: const Icon(
                    PhosphorIconsBold.arrowRight,
                    size: 16,
                  ),
                  label: const Text('View details'),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _AddServiceBoySheet(
                      eventId: assignment.eventId,
                    ),
                  ),
                  icon: const Icon(PhosphorIconsBold.userPlus, size: 16),
                  label: const Text('Add boy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventCardV2 extends ConsumerWidget {
  const _EventCardV2({required this.assignment});

  final EventAssignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = assignment.eventDate;
    final urgency = _urgencyLabel(date);
    final staff = ref.watch(eventStaffProvider(assignment.eventId));
    final serviceBoyCount = staff.valueOrNull
            ?.where((a) => a.roleOnEvent == EventAssignmentRole.serviceBoy)
            .length ??
        0;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          context.push(AppRoutes.managerEventDetailFor(assignment.eventId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.accentSoft.withValues(alpha: 0.72),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomerLine(
                    bookingId: assignment.eventId,
                    name: assignment.customerName,
                    phone: assignment.customerPhone,
                    email: assignment.customerEmail,
                  ),
                ),
                _EventPill(label: urgency, color: AppColors.primary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        PhosphorIconsDuotone.calendarBlank,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date != null ? Formatters.date(date) : 'Date TBD',
                            style: AppTextStyles.heading2.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (assignment.eventSession != null)
                                assignment.eventSession!,
                              '${assignment.eventGuestCount ?? 0} guests',
                            ].join(' - '),
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (assignment.eventLocation != null) ...[
                  const SizedBox(height: AppSizes.md),
                  _EventMetaRow(
                    icon: PhosphorIconsDuotone.mapPin,
                    text: assignment.eventLocation!,
                  ),
                ],
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: _EventInfoTile(
                        icon: PhosphorIconsDuotone.users,
                        label: 'Service team',
                        value: '$serviceBoyCount assigned',
                        color: serviceBoyCount > 0
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _EventInfoTile(
                        icon: PhosphorIconsBold.userGear,
                        label: 'Your role',
                        value: 'Manager',
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.managerEventDetailFor(assignment.eventId),
                        ),
                        icon: const Icon(
                          PhosphorIconsBold.arrowRight,
                          size: 16,
                        ),
                        label: const Text('View details'),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    IconButton.outlined(
                      tooltip: 'Add service boy',
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _AddServiceBoySheet(
                          eventId: assignment.eventId,
                        ),
                      ),
                      icon: const Icon(PhosphorIconsBold.userPlus, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventMetaRow extends StatelessWidget {
  const _EventMetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EventInfoTile extends StatelessWidget {
  const _EventInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: AppTextStyles.captionBold.copyWith(
                    color: color,
                    fontSize: 11,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventPill extends StatelessWidget {
  const _EventPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(
          color: color,
          fontSize: 10,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ───────────────────────── Add-service-boy sheet ─────────────────────────

class _AddServiceBoySheet extends ConsumerWidget {
  const _AddServiceBoySheet({required this.eventId});
  final String eventId;

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    UserProfile boy,
  ) async {
    try {
      await ref.read(staffingRepositoryProvider).addServiceBoyAssignment(
            eventId: eventId,
            profileId: boy.id,
          );
      ref.invalidate(eventStaffProvider(eventId));
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${boy.name ?? 'Added'} staffed on event')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);
    final existingStaff = ref.watch(eventStaffProvider(eventId));
    final alreadyAssigned = existingStaff.valueOrNull
            ?.where(
                (a) => a.roleOnEvent == EventAssignmentRole.serviceBoy)
            .map((a) => a.profileId)
            .toSet() ??
        const <String>{};

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add service boy', style: AppTextStyles.display),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Only your direct reports are listed. Admins link service boys to you via profiles.reports_to_manager_id.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.lg),
            Expanded(
              child: reports.when(
                loading: () => ListView.separated(
                  controller: scrollCtrl,
                  itemCount: 5,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.sm),
                  itemBuilder: (_, __) => Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Row(
                      children: [
                        ShimmerBox(
                          width: 40,
                          height: 40,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(width: AppSizes.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(width: 130, height: 14),
                              SizedBox(height: 8),
                              ShimmerBox(width: 190, height: 11),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => AppErrorView(error: e, compact: true),
                data: (rows) {
                  final available = rows
                      .where((p) => !alreadyAssigned.contains(p.id))
                      .toList();
                  if (available.isEmpty) {
                    return EmptyState(
                      icon: PhosphorIconsDuotone.users,
                      title: rows.isEmpty
                          ? 'No service boys yet'
                          : 'Team already assigned',
                      message: rows.isEmpty
                          ? 'Service boys linked to you will appear here.'
                          : 'Every available report is already staffed on this event.',
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    itemCount: available.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (_, i) => _ReportTile(
                      profile: available[i],
                      onTap: () => _add(context, ref, available[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.profile, required this.onTap});
  final UserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = (profile.name?.isNotEmpty ?? false)
        ? profile.name![0].toUpperCase()
        : (profile.email?.isNotEmpty ?? false)
            ? profile.email![0].toUpperCase()
            : '?';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              foregroundColor: AppColors.primary,
              child: Text(initial),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name ?? 'Service boy',
                    style: AppTextStyles.bodyBold,
                  ),
                  if (profile.email != null)
                    Text(
                      profile.email!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(
              PhosphorIconsBold.plus,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
