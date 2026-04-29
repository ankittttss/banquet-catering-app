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
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/providers/staffing_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';

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
              content: Text(
                  'New event assigned to you — check your list.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    final assignments = ref.watch(myAssignmentsProvider);
    return AppScaffold(
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
        onRefresh: () async => ref.invalidate(myAssignmentsProvider),
        child: assignments.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: AppSizes.xl),
              Text('Could not load your events: $e',
                  style: AppTextStyles.caption, textAlign: TextAlign.center),
            ],
          ),
          data: (rows) {
            final managed = rows
                .where((r) => r.roleOnEvent == EventAssignmentRole.manager)
                .toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: AppSizes.xl),
              children: [
                const SizedBox(height: AppSizes.sm),
                Text('Your events', style: AppTextStyles.display),
                const SizedBox(height: AppSizes.xs),
                Text(
                  managed.isEmpty
                      ? 'You have no events assigned yet.'
                      : 'You are managing ${managed.length} event${managed.length == 1 ? '' : 's'}.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: AppSizes.lg),
                if (managed.isEmpty)
                  const _EmptyEventsHint()
                else
                  for (final a in managed) ...[
                    _EventCard(assignment: a),
                    const SizedBox(height: AppSizes.md),
                  ],
              ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.06, end: 0),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyEventsHint extends StatelessWidget {
  const _EmptyEventsHint();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(PhosphorIconsDuotone.calendarBlank,
              size: 40, color: AppColors.textMuted),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date != null ? Formatters.date(date) : 'Date TBD',
                  style: AppTextStyles.heading2,
                ),
              ),
              const Icon(PhosphorIconsBold.userGear,
                  size: 18, color: AppColors.primary),
            ],
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
                const Icon(PhosphorIconsDuotone.mapPin,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(assignment.eventLocation!,
                      style: AppTextStyles.caption, maxLines: 2),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(PhosphorIconsDuotone.users,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '$serviceBoyCount service '
                '${serviceBoyCount == 1 ? 'boy' : 'boys'} assigned',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AddServiceBoySheet(
                  eventId: assignment.eventId,
                ),
              ),
              icon: const Icon(PhosphorIconsBold.userPlus, size: 16),
              label: const Text('Add service boy'),
            ),
          ),
        ],
      ),
    );
  }
}

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
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
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
                error: (e, _) => Text('Could not load reports: $e',
                    style: AppTextStyles.caption),
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
                  Text(profile.name ?? 'Service boy',
                      style: AppTextStyles.bodyBold),
                  if (profile.email != null)
                    Text(profile.email!,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.plus,
                color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
