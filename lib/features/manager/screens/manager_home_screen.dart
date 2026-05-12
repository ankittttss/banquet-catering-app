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
                _Greeting(profile: profile),
                const SizedBox(height: AppSizes.lg),
                _StatsRow(events: managed),
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});
  final UserProfile? profile;

  String get _timeOfDayGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?.name;
    final headline = name != null && name.trim().isNotEmpty
        ? '$_timeOfDayGreeting, $name'
        : _timeOfDayGreeting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headline, style: AppTextStyles.display),
        const SizedBox(height: 2),
        Text(
          'Here is what you are running.',
          style: AppTextStyles.bodyMuted,
        ),
      ],
    );
  }
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
            _EventCard(assignment: groups[gi].value[i]),
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
    return AppCard(
      child: Row(
        children: [
          const Icon(
            PhosphorIconsDuotone.calendarBlank,
            size: 40,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nothing on your plate', style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(
                  'Your banquet operator will assign you to events here.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
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
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Could not load reports: $e',
                  style: AppTextStyles.caption,
                ),
                data: (rows) {
                  final available = rows
                      .where((p) => !alreadyAssigned.contains(p.id))
                      .toList();
                  if (available.isEmpty) {
                    return Center(
                      child: Text(
                        rows.isEmpty
                            ? 'No service boys report to you yet.'
                            : 'Every report is already assigned.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMuted,
                      ),
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
