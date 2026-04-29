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
import '../../../shared/widgets/app_scaffold.dart';

class ServiceBoyHomeScreen extends ConsumerWidget {
  const ServiceBoyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<List<EventAssignment>>>(
      myAssignmentsProvider,
      (prev, next) {
        final prevCount = prev?.valueOrNull
                ?.where((a) =>
                    a.roleOnEvent == EventAssignmentRole.serviceBoy)
                .length ??
            0;
        final nextCount = next.valueOrNull
                ?.where((a) =>
                    a.roleOnEvent == EventAssignmentRole.serviceBoy)
                .length ??
            0;
        if (nextCount > prevCount) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('You\'ve been staffed on a new event.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    final assignments = ref.watch(myAssignmentsProvider);
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Service Boy'),
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
          error: (e, _) => ListView(children: [
            const SizedBox(height: AppSizes.xl),
            Text('Could not load your assignments: $e',
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ]),
          data: (rows) {
            final upcoming = rows
                .where((r) =>
                    r.roleOnEvent == EventAssignmentRole.serviceBoy)
                .toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: AppSizes.xl),
              children: [
                const SizedBox(height: AppSizes.sm),
                Text('My assignments', style: AppTextStyles.display),
                const SizedBox(height: AppSizes.xs),
                Text(
                  upcoming.isEmpty
                      ? 'No events yet — your manager will assign you.'
                      : '${upcoming.length} event${upcoming.length == 1 ? '' : 's'} on your calendar.',
                  style: AppTextStyles.bodyMuted,
                ),
                const SizedBox(height: AppSizes.lg),
                if (upcoming.isEmpty)
                  const _EmptyState()
                else
                  for (final a in upcoming) ...[
                    _AssignmentCard(assignment: a),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(PhosphorIconsDuotone.calendarBlank,
              size: 40, color: AppColors.textMuted),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              'Nothing scheduled yet — your manager will staff you on upcoming events.',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends ConsumerWidget {
  const _AssignmentCard({required this.assignment});
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
    final d = assignment.eventDate;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(d != null ? Formatters.date(d) : 'Date TBD',
                    style: AppTextStyles.heading2),
              ),
              if (assignment.isCheckedIn)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'CHECKED IN',
                    style: AppTextStyles.captionBold
                        .copyWith(color: AppColors.success),
                  ),
                ),
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
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: assignment.checkedOutAt != null
                      ? null
                      : () => _toggleCheck(context, ref),
                  icon: Icon(
                    assignment.isCheckedIn
                        ? PhosphorIconsBold.signOut
                        : PhosphorIconsBold.signIn,
                    size: 16,
                  ),
                  label: Text(
                    assignment.checkedOutAt != null
                        ? 'Checked out'
                        : assignment.isCheckedIn
                            ? 'Check out'
                            : 'Check in',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
