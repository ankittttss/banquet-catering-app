import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../data/models/event_assignment.dart';
import '../../../shared/providers/banquet_providers.dart';
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
        BanquetEventStatus.pending => AppColors.warning,
        BanquetEventStatus.accepted => AppColors.success,
        BanquetEventStatus.declined => AppColors.textMuted,
        BanquetEventStatus.cancelled => AppColors.textMuted,
        BanquetEventStatus.completed => AppColors.success,
      };

  String _ctaHint() => switch (event.status) {
        BanquetEventStatus.pending =>
          'Tap to review full details before accepting',
        BanquetEventStatus.accepted =>
          'Tap to view details or assign a manager',
        _ => 'Tap to view booking details',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor();
    return AppCard(
      onTap: () =>
          context.push(AppRoutes.banquetBookingDetailFor(event.id)),
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
                  horizontal: 10,
                  vertical: 4,
                ),
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
                  child: Text(
                    event.location!,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
          if (event.status == BanquetEventStatus.accepted) ...[
            const SizedBox(height: AppSizes.sm),
            _ManagerRow(eventId: event.id),
          ],
          const SizedBox(height: AppSizes.sm),
          // Replaces the old inline Accept/Decline/Assign row — operators
          // now open the booking-detail screen first so they're never
          // forced to act on a thin summary card.
          Row(
            children: [
              Expanded(
                child: Text(
                  _ctaHint(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(PhosphorIconsBold.caretRight,
                  size: 16, color: AppColors.primary),
            ],
          ),
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
    final color =
        hasManager ? AppColors.success : AppColors.warning;
    final label = hasManager
        ? 'Manager: ${manager.profileName ?? 'Assigned'}'
        : 'Manager not yet assigned';
    // Read-only chip — assign / reassign actions live on the booking
    // detail screen so the operator always sees full info first.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsBold.userGear, color: color, size: 18),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

