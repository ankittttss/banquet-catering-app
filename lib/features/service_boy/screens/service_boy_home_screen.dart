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
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/providers/staffing_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer.dart';

class ServiceBoyHomeScreen extends ConsumerWidget {
  const ServiceBoyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<EventAssignment>>>(
      myAssignmentsProvider,
      (prev, next) {
        final prevCount = prev?.valueOrNull
                ?.where((a) => a.roleOnEvent == EventAssignmentRole.serviceBoy)
                .length ??
            0;
        final nextCount = next.valueOrNull
                ?.where((a) => a.roleOnEvent == EventAssignmentRole.serviceBoy)
                .length ??
            0;
        if (nextCount > prevCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have been staffed on a new event.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    final assignments = ref.watch(myAssignmentsProvider);
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Service crew'),
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
        onRefresh: () async => ref.invalidate(myAssignmentsProvider),
        child: assignments.when(
          loading: () => const _ServiceBoyLoading(),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(myAssignmentsProvider),
          ),
          data: (rows) {
            final jobs = rows
                .where((r) => r.roleOnEvent == EventAssignmentRole.serviceBoy)
                .toList(growable: false)
              ..sort(_assignmentSort);
            final stats = _ServiceStats.from(jobs);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.xxl,
              ),
              children: [
                _ServiceHero(stats: stats, nextJob: _nextJob(jobs)),
                const SizedBox(height: AppSizes.xl),
                if (jobs.isEmpty)
                  const EmptyState(
                    icon: PhosphorIconsDuotone.calendarBlank,
                    title: 'No duty assigned',
                    message:
                        'Your manager will assign you to events when service staff is needed.',
                  )
                else
                  _DutyList(assignments: jobs),
              ]
                  .animate(interval: 55.ms)
                  .fadeIn(duration: 260.ms)
                  .slideY(begin: 0.05, end: 0),
            );
          },
        ),
      ),
    );
  }
}

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.stats, required this.nextJob});

  final _ServiceStats stats;
  final EventAssignment? nextJob;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.14),
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
                    AppColors.success,
                    AppColors.info,
                    AppColors.primaryDark.withValues(alpha: 0.92),
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
                            'Today\'s service duty',
                            style: AppTextStyles.display.copyWith(
                              color: Colors.white,
                              fontSize: 25,
                            ),
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            'Check your venue, report on time, and mark attendance.',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _HeroBadge(
                      icon: stats.checkedIn > 0
                          ? PhosphorIconsBold.signIn
                          : PhosphorIconsBold.clock,
                      label: stats.checkedIn > 0
                          ? '${stats.checkedIn} live'
                          : '${stats.pending} pending',
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
                        value: '${stats.upcoming}',
                        label: 'Upcoming',
                        icon: PhosphorIconsDuotone.calendarBlank,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _HeroMetric(
                        value: '${stats.completed}',
                        label: 'Done',
                        icon: PhosphorIconsBold.checkCircle,
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
                          PhosphorIconsBold.mapPin,
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
                              nextJob == null
                                  ? 'No upcoming duty pressure'
                                  : 'Next duty ${_urgencyLabel(nextJob!.eventDate)}',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextJob == null
                                  ? 'Assigned events will show up here.'
                                  : [
                                      if (nextJob!.eventLocation != null)
                                        nextJob!.eventLocation!,
                                      if (nextJob!.eventSession != null)
                                        nextJob!.eventSession!,
                                      '${nextJob!.eventGuestCount ?? 0} guests',
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

class _DutyList extends StatelessWidget {
  const _DutyList({required this.assignments});

  final List<EventAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final groups = _groupAssignments(assignments);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var gi = 0; gi < groups.length; gi++) ...[
          _GroupHeader(label: groups[gi].key, count: groups[gi].value.length),
          const SizedBox(height: AppSizes.sm),
          for (var i = 0; i < groups[gi].value.length; i++) ...[
            _DutyCard(assignment: groups[gi].value[i]),
            if (i != groups[gi].value.length - 1)
              const SizedBox(height: AppSizes.md),
          ],
          if (gi != groups.length - 1) const SizedBox(height: AppSizes.lg),
        ],
      ],
    );
  }
}

class _DutyCard extends ConsumerWidget {
  const _DutyCard({required this.assignment});

  final EventAssignment assignment;

  Future<void> _toggleCheck(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(staffingRepositoryProvider);
    try {
      if (assignment.isCheckedIn) {
        await repo.checkOut(assignment.id);
      } else {
        await repo.checkIn(assignment.id);
      }
      ref.invalidate(myAssignmentsProvider);
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
    final date = assignment.eventDate;
    final state = _DutyState.from(assignment);
    return AppCard(
      padding: EdgeInsets.zero,
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
              color: state.color.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date != null ? Formatters.date(date) : 'Date TBD',
                    style: AppTextStyles.heading2.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(label: state.label, color: state.color),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: state.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(state.icon, color: state.color, size: 22),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              if (assignment.eventSession != null)
                                assignment.eventSession!,
                              '${assignment.eventGuestCount ?? 0} guests',
                            ].join(' - '),
                            style: AppTextStyles.bodyBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _urgencyLabel(date),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (assignment.eventLocation != null) ...[
                  const SizedBox(height: AppSizes.md),
                  _MetaRow(
                    icon: PhosphorIconsDuotone.mapPin,
                    text: assignment.eventLocation!,
                  ),
                ],
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: PhosphorIconsDuotone.user,
                        label: 'Customer',
                        value: _customerLabel(assignment),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _InfoTile(
                        icon: PhosphorIconsDuotone.clock,
                        label: 'Attendance',
                        value: state.shortLabel,
                        color: state.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: assignment.checkedOutAt != null
                        ? null
                        : () => _toggleCheck(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          assignment.isCheckedIn ? AppColors.textPrimary : state.color,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(
                      assignment.isCheckedIn
                          ? PhosphorIconsBold.signOut
                          : PhosphorIconsBold.signIn,
                      size: 16,
                    ),
                    label: Text(
                      assignment.checkedOutAt != null
                          ? 'Shift completed'
                          : assignment.isCheckedIn
                              ? 'Check out'
                              : 'Check in',
                    ),
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

class _ServiceBoyLoading extends StatelessWidget {
  const _ServiceBoyLoading();

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
        ShimmerBox(width: double.infinity, height: 220),
        SizedBox(height: AppSizes.xl),
        ShimmerBookingCard(),
        SizedBox(height: AppSizes.md),
        ShimmerBookingCard(),
      ],
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

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isUrgent = label == 'Today' || label == 'Tomorrow';
    final color = isUrgent ? AppColors.success : AppColors.textSecondary;
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

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

class _ServiceStats {
  const _ServiceStats({
    required this.today,
    required this.upcoming,
    required this.checkedIn,
    required this.completed,
    required this.pending,
  });

  final int today;
  final int upcoming;
  final int checkedIn;
  final int completed;
  final int pending;

  factory _ServiceStats.from(List<EventAssignment> assignments) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var todayCount = 0;
    var upcomingCount = 0;
    var checkedInCount = 0;
    var completedCount = 0;
    for (final assignment in assignments) {
      final date = assignment.eventDate;
      if (date != null) {
        final day = DateTime(date.year, date.month, date.day);
        if (day == today) todayCount++;
        if (!day.isBefore(today)) upcomingCount++;
      }
      if (assignment.isCheckedIn) checkedInCount++;
      if (assignment.checkedOutAt != null) completedCount++;
    }
    return _ServiceStats(
      today: todayCount,
      upcoming: upcomingCount,
      checkedIn: checkedInCount,
      completed: completedCount,
      pending: assignments.length - completedCount,
    );
  }
}

class _DutyState {
  const _DutyState({
    required this.label,
    required this.shortLabel,
    required this.color,
    required this.icon,
  });

  final String label;
  final String shortLabel;
  final Color color;
  final IconData icon;

  factory _DutyState.from(EventAssignment assignment) {
    if (assignment.checkedOutAt != null) {
      return const _DutyState(
        label: 'Completed',
        shortLabel: 'Checked out',
        color: AppColors.textMuted,
        icon: PhosphorIconsBold.checkCircle,
      );
    }
    if (assignment.isCheckedIn) {
      return const _DutyState(
        label: 'Checked in',
        shortLabel: 'On duty',
        color: AppColors.success,
        icon: PhosphorIconsBold.signIn,
      );
    }
    return const _DutyState(
      label: 'Report pending',
      shortLabel: 'Not checked in',
      color: AppColors.warning,
      icon: PhosphorIconsBold.clock,
    );
  }
}

List<MapEntry<String, List<EventAssignment>>> _groupAssignments(
  List<EventAssignment> assignments,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final weekEnd = today.add(const Duration(days: 7));
  final buckets = <String, List<EventAssignment>>{
    'Today': [],
    'Tomorrow': [],
    'This week': [],
    'Later': [],
    'Past': [],
  };
  for (final assignment in assignments) {
    final date = assignment.eventDate;
    if (date == null) {
      buckets['Later']!.add(assignment);
      continue;
    }
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(today)) {
      buckets['Past']!.add(assignment);
    } else if (day == today) {
      buckets['Today']!.add(assignment);
    } else if (day == tomorrow) {
      buckets['Tomorrow']!.add(assignment);
    } else if (day.isBefore(weekEnd)) {
      buckets['This week']!.add(assignment);
    } else {
      buckets['Later']!.add(assignment);
    }
  }
  for (final list in buckets.values) {
    list.sort(_assignmentSort);
  }
  return buckets.entries
      .where((entry) => entry.value.isNotEmpty)
      .toList(growable: false);
}

EventAssignment? _nextJob(List<EventAssignment> assignments) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final upcoming = assignments
      .where((assignment) =>
          assignment.checkedOutAt == null &&
          assignment.eventDate != null &&
          !assignment.eventDate!.isBefore(today))
      .toList(growable: false)
    ..sort(_assignmentSort);
  return upcoming.isEmpty ? null : upcoming.first;
}

int _assignmentSort(EventAssignment a, EventAssignment b) {
  if (a.eventDate == null) return 1;
  if (b.eventDate == null) return -1;
  return a.eventDate!.compareTo(b.eventDate!);
}

String _urgencyLabel(DateTime? date) {
  if (date == null) return 'date to be confirmed';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final days = target.difference(today).inDays;
  if (days < 0) return '${-days}d ago';
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 7) return 'in ${days}d';
  if (days < 30) return 'in ${(days / 7).round()}w';
  return 'in ${(days / 30).round()}mo';
}

String _customerLabel(EventAssignment assignment) {
  final name = assignment.customerName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final phone = assignment.customerPhone?.trim();
  if (phone != null && phone.isNotEmpty) return phone;
  final email = assignment.customerEmail?.trim();
  if (email != null && email.isNotEmpty) return email;
  return 'Customer';
}
