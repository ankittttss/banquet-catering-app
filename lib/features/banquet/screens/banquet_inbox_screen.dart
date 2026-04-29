import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../data/models/event_assignment.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/providers/staffing_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';

class BanquetInboxScreen extends ConsumerWidget {
  const BanquetInboxScreen({super.key, this.initialFilter});

  /// Optional filter keyword — "accepted" shows only accepted events
  /// (used by the "Assign managers" tile as a staffing shortcut).
  final String? initialFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(banquetInboxProvider);
    final title = initialFilter == 'accepted'
        ? 'Staff your events'
        : 'Incoming bookings';
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          // Re-pull the inbox AND invalidate every per-event staff provider
          // so manager chips refresh. `invalidate(family)` without a key
          // invalidates all instances of the family.
          ref.invalidate(banquetInboxProvider);
          ref.invalidate(eventStaffProvider);
          await ref.read(banquetInboxProvider.future);
        },
        child: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load inbox: $e',
              style: AppTextStyles.caption),
        ),
        data: (all) {
          final events = initialFilter == 'accepted'
              ? all
                  .where((e) => e.status == BanquetEventStatus.accepted)
                  .toList()
              : all;
          if (events.isEmpty) {
            final emptyTitle = initialFilter == 'accepted'
                ? 'No accepted events yet'
                : 'No incoming bookings';
            final emptySub = initialFilter == 'accepted'
                ? 'Accept an incoming booking first, then return here to staff a manager.'
                : 'New event requests routed to your venues will appear here in real time.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIconsDuotone.calendarBlank,
                        size: 56, color: AppColors.textMuted),
                    const SizedBox(height: AppSizes.md),
                    Text(emptyTitle, style: AppTextStyles.heading3),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      emptySub,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            itemCount: events.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSizes.md),
            itemBuilder: (_, i) => _InboxCard(event: events[i]),
          );
        },
      ),
      ),
    );
  }
}

class _InboxCard extends ConsumerWidget {
  const _InboxCard({required this.event});
  final BanquetInboxEvent event;

  Color _statusColor() => switch (event.status) {
        BanquetEventStatus.pending => AppColors.primary,
        BanquetEventStatus.accepted => AppColors.success,
        BanquetEventStatus.declined => AppColors.textMuted,
        BanquetEventStatus.cancelled => AppColors.textMuted,
        BanquetEventStatus.completed => AppColors.success,
      };

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    BanquetEventStatus next,
  ) async {
    try {
      await ref.read(banquetRepositoryProvider).updateEventStatus(
            eventId: event.id,
            status: next,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked ${next.label.toLowerCase()}')),
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
    final statusColor = _statusColor();
    final canAct = event.status == BanquetEventStatus.pending;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Formatters.date(event.eventDate),
                  style: AppTextStyles.heading2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  event.status.label,
                  style: AppTextStyles.captionBold
                      .copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${event.session} · ${event.guestCount} guests'
            '${event.startTime != null ? ' · ${event.startTime}' : ''}',
            style: AppTextStyles.caption,
          ),
          if (event.location != null && event.location!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                const Icon(PhosphorIconsDuotone.mapPin,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(event.location!,
                      style: AppTextStyles.caption, maxLines: 2),
                ),
              ],
            ),
          ],
          if (canAct) ...[
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setStatus(
                      context,
                      ref,
                      BanquetEventStatus.declined,
                    ),
                    icon: const Icon(PhosphorIconsBold.x, size: 16),
                    label: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _setStatus(
                      context,
                      ref,
                      BanquetEventStatus.accepted,
                    ),
                    icon: const Icon(PhosphorIconsBold.check, size: 16),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
          if (event.status == BanquetEventStatus.accepted) ...[
            const SizedBox(height: AppSizes.md),
            _ManagerRow(eventId: event.id),
          ],
        ],
      ),
    );
  }
}

/// Shows the currently assigned manager (or an Assign button when none)
/// by watching the live staff list for the event.
class _ManagerRow extends ConsumerWidget {
  const _ManagerRow({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(eventStaffProvider(eventId));

    // Surface any silent backend failure instead of showing Assign when the
    // load errored — lets us catch RLS / embed problems during demo.
    if (staff.hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsBold.warning,
                size: 16, color: AppColors.primary),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                'Could not load staff: ${staff.error}',
                style: AppTextStyles.caption,
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }

    final manager = staff.valueOrNull?.firstWhere(
      (a) => a.roleOnEvent == EventAssignmentRole.manager,
      orElse: () => EventAssignment(
        id: '',
        eventId: eventId,
        profileId: '',
        roleOnEvent: EventAssignmentRole.manager,
        assignedAt: DateTime.now(),
      ),
    );

    final hasManager = manager != null && manager.id.isNotEmpty;
    if (hasManager) {
      final name = manager.profileName ?? 'Manager';
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(PhosphorIconsBold.userGear,
                color: AppColors.success, size: 18),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text('Manager: $name',
                  style: AppTextStyles.bodyBold
                      .copyWith(color: AppColors.success)),
            ),
            TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AssignManagerSheet(eventId: eventId),
              ),
              child: const Text('Reassign'),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _AssignManagerSheet(eventId: eventId),
        ),
        icon: const Icon(PhosphorIconsBold.userGear, size: 16),
        label: const Text('Assign manager'),
      ),
    );
  }
}

class _AssignManagerSheet extends ConsumerWidget {
  const _AssignManagerSheet({required this.eventId});
  final String eventId;

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    UserProfile manager,
  ) async {
    try {
      await ref.read(staffingRepositoryProvider).setEventManager(
            eventId: eventId,
            managerProfileId: manager.id,
          );
      // Make the inbox card re-render with the new manager immediately.
      ref.invalidate(eventStaffProvider(eventId));
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${manager.name ?? 'Manager'} assigned to event')),
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
    final managers = ref.watch(availableManagersProvider);
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
            Text('Assign manager', style: AppTextStyles.display),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Pick a manager to run this event. They can then staff service boys from their team.',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.lg),
            Expanded(
              child: managers.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load managers: $e',
                    style: AppTextStyles.caption),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        'No managers available. An admin must promote a user to the manager role first.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMuted,
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (_, i) => _PersonTile(
                      profile: rows[i],
                      onTap: () => _assign(context, ref, rows[i]),
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

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.profile, required this.onTap});
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
                  Text(profile.name ?? 'Manager',
                      style: AppTextStyles.bodyBold),
                  if (profile.email != null)
                    Text(profile.email!,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(PhosphorIconsBold.caretRight,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
