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
import '../../../data/models/manager_event_detail.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_vendor_lot.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/order_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/providers/staffing_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// Full booking review screen for the banquet operator.
///
/// The operator opens this from the inbox before deciding whether to
/// accept/decline a booking or assign a manager — the inbox card alone
/// is too small to make those calls. The screen pulls the same
/// aggregated snapshot as the manager event-detail screen
/// (`managerEventDetailProvider`) and adds an operator-specific action
/// bar pinned to the bottom.
class BanquetBookingDetailScreen extends ConsumerWidget {
  const BanquetBookingDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(managerEventDetailProvider(eventId));
    final staffAsync = ref.watch(eventStaffProvider(eventId));

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Booking review'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      padded: false,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(managerEventDetailProvider(eventId));
          ref.invalidate(eventStaffProvider(eventId));
          ref.invalidate(banquetInboxProvider);
          await ref.read(managerEventDetailProvider(eventId).future);
        },
        child: detailAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              Text('Could not load booking: $e',
                  style: AppTextStyles.caption),
            ],
          ),
          data: (detail) {
            if (detail == null) return const _NotFoundView();
            final manager = staffAsync.valueOrNull?.where(
              (a) => a.roleOnEvent == EventAssignmentRole.manager,
            ).toList();
            final hasManager = manager != null && manager.isNotEmpty;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      AppSizes.md,
                      AppSizes.pagePadding,
                      AppSizes.md,
                    ),
                    children: [
                      _StatusBanner(detail: detail, hasManager: hasManager),
                      const SizedBox(height: AppSizes.md),
                      _SectionTitle('Customer'),
                      _CustomerCard(detail: detail),
                      const SizedBox(height: AppSizes.lg),
                      _SectionTitle('When & where'),
                      _WhenWhereCard(detail: detail),
                      const SizedBox(height: AppSizes.lg),
                      _SectionTitle('Booking'),
                      _BookingCard(detail: detail),
                      if (detail.banquetNotes != null &&
                          detail.banquetNotes!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSizes.lg),
                        _SectionTitle('Operator notes'),
                        AppCard(
                          child: Text(
                            detail.banquetNotes!,
                            style: AppTextStyles.body
                                .copyWith(fontSize: 13.5),
                          ),
                        ),
                      ],
                      if (detail.hasOrder) ...[
                        const SizedBox(height: AppSizes.lg),
                        _SectionTitle('Bill summary'),
                        _BillCard(detail: detail),
                      ],
                      if (detail.vendorLots.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.lg),
                        _SectionTitle(
                            'Restaurants (${detail.vendorLots.length})'),
                        for (final lot in detail.vendorLots) ...[
                          _VendorLotCard(lot: lot),
                          const SizedBox(height: AppSizes.sm),
                        ],
                      ],
                      const SizedBox(height: AppSizes.lg),
                      _SectionTitle('On-site team'),
                      _RosterCard(staffAsync: staffAsync),
                    ],
                  ),
                ),
                _ActionBar(
                  eventId: eventId,
                  status: detail.banquetStatus,
                  hasManager: hasManager,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── Action bar ─────────────────────────

/// Pinned bottom bar that drives the operator pipeline:
/// pending → Accept / Decline; accepted → Assign / Reassign manager;
/// declined or cancelled → read-only status pill.
class _ActionBar extends ConsumerWidget {
  const _ActionBar({
    required this.eventId,
    required this.status,
    required this.hasManager,
  });

  final String eventId;
  final BanquetEventStatus? status;
  final bool hasManager;

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    BanquetEventStatus next,
  ) async {
    try {
      await ref.read(banquetRepositoryProvider).updateEventStatus(
            eventId: eventId,
            status: next,
          );
      ref.invalidate(managerEventDetailProvider(eventId));
      ref.invalidate(banquetInboxProvider);
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
    final s = status ?? BanquetEventStatus.pending;
    final container = Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: switch (s) {
        BanquetEventStatus.pending => Row(
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
                  label: const Text('Accept booking'),
                ),
              ),
            ],
          ),
        BanquetEventStatus.accepted => SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AssignManagerSheet(eventId: eventId),
              ),
              icon: const Icon(PhosphorIconsBold.userGear, size: 16),
              label: Text(hasManager ? 'Reassign manager' : 'Assign manager'),
            ),
          ),
        BanquetEventStatus.declined ||
        BanquetEventStatus.cancelled ||
        BanquetEventStatus.completed =>
          Center(
            child: Text(
              'No further action — booking is ${s.label.toLowerCase()}.',
              style: AppTextStyles.caption,
            ),
          ),
      },
    );
    return container;
  }
}

// ───────────────────────── Status + cards ─────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.textMuted,
          fontSize: 11,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.detail, required this.hasManager});
  final ManagerEventDetail detail;
  final bool hasManager;

  ({Color color, String headline, IconData icon}) _theme() {
    final s = detail.banquetStatus ?? BanquetEventStatus.pending;
    return switch (s) {
      BanquetEventStatus.pending => (
          color: AppColors.warning,
          headline: 'Awaiting your review',
          icon: PhosphorIconsBold.clock,
        ),
      BanquetEventStatus.accepted => (
          color: AppColors.success,
          headline:
              hasManager ? 'Accepted · manager assigned' : 'Accepted · needs manager',
          icon: PhosphorIconsBold.check,
        ),
      BanquetEventStatus.declined => (
          color: AppColors.textMuted,
          headline: 'Declined',
          icon: PhosphorIconsBold.x,
        ),
      BanquetEventStatus.cancelled => (
          color: AppColors.textMuted,
          headline: 'Cancelled',
          icon: PhosphorIconsBold.prohibit,
        ),
      BanquetEventStatus.completed => (
          color: AppColors.success,
          headline: 'Completed',
          icon: PhosphorIconsBold.flag,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme();
    final date = detail.eventDate;
    final dateText = date != null ? Formatters.date(date) : 'Date TBD';
    final timeRange = _timeRange(detail.startTime, detail.endTime);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: t.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: t.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(t.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.headline, style: AppTextStyles.bodyBold),
                const SizedBox(height: 2),
                Text(
                  '$dateText${timeRange != null ? ' · $timeRange' : ''}',
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

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.detail});
  final ManagerEventDetail detail;

  bool _has(String? s) => s != null && s.trim().isNotEmpty;

  String get _shortId => detail.eventId.length >= 8
      ? '#${detail.eventId.substring(0, 8)}'
      : '#${detail.eventId}';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: PhosphorIconsDuotone.user,
            label: 'Customer',
            value: _has(detail.customerName)
                ? detail.customerName!
                : (_has(detail.customerPhone)
                    ? detail.customerPhone!
                    : (_has(detail.customerEmail)
                        ? detail.customerEmail!
                        : _shortId)),
          ),
          if (_has(detail.customerPhone) && _has(detail.customerName))
            _DetailRow(
              icon: PhosphorIconsDuotone.phone,
              label: 'Phone',
              value: detail.customerPhone!,
            ),
          if (_has(detail.customerEmail) &&
              (_has(detail.customerName) || _has(detail.customerPhone)))
            _DetailRow(
              icon: PhosphorIconsDuotone.envelope,
              label: 'Email',
              value: detail.customerEmail!,
            ),
          _DetailRow(
            icon: PhosphorIconsDuotone.identificationCard,
            label: 'Booking ID',
            value: _shortId,
          ),
        ],
      ),
    );
  }
}

class _WhenWhereCard extends StatelessWidget {
  const _WhenWhereCard({required this.detail});
  final ManagerEventDetail detail;

  @override
  Widget build(BuildContext context) {
    final timeRange = _timeRange(detail.startTime, detail.endTime);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: PhosphorIconsDuotone.calendarBlank,
            label: 'Date',
            value: detail.eventDate != null
                ? Formatters.date(detail.eventDate!)
                : '—',
          ),
          if (detail.session != null)
            _DetailRow(
              icon: PhosphorIconsDuotone.sun,
              label: 'Session',
              value: detail.session!,
            ),
          if (timeRange != null)
            _DetailRow(
              icon: PhosphorIconsDuotone.clock,
              label: 'Time',
              value: timeRange,
            ),
          if (detail.location != null && detail.location!.trim().isNotEmpty)
            _DetailRow(
              icon: PhosphorIconsDuotone.mapPin,
              label: 'Location',
              value: detail.location!,
              multiline: true,
            ),
          if (detail.banquetVenueName != null)
            _DetailRow(
              icon: PhosphorIconsDuotone.buildings,
              label: 'Banquet venue',
              value: detail.banquetVenueName!,
            ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.detail});
  final ManagerEventDetail detail;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: PhosphorIconsDuotone.users,
            label: 'Guest count',
            value: detail.guestCount != null
                ? '${detail.guestCount} guests'
                : '—',
          ),
          if (detail.tierLabel != null)
            _DetailRow(
              icon: PhosphorIconsDuotone.crown,
              label: 'Package',
              value: detail.tierLabel!,
            ),
          if (detail.serviceBoyCount != null)
            _DetailRow(
              icon: PhosphorIconsDuotone.handshake,
              label: 'Service boys (booked)',
              value: '${detail.serviceBoyCount}',
            ),
          if (detail.hasOrder) ...[
            _DetailRow(
              icon: PhosphorIconsDuotone.receipt,
              label: 'Order status',
              value: detail.orderStatus?.label ?? '—',
              valueChip: _StatusChip(
                label: detail.orderStatus?.label ?? '—',
                color: _orderStatusColor(detail.orderStatus),
              ),
            ),
            _DetailRow(
              icon: PhosphorIconsDuotone.creditCard,
              label: 'Payment',
              value: _payLabel(detail.paymentStatus),
              valueChip: _StatusChip(
                label: _payLabel(detail.paymentStatus),
                color: _payColor(detail.paymentStatus),
              ),
            ),
            if (detail.orderCreatedAt != null)
              _DetailRow(
                icon: PhosphorIconsDuotone.clockCounterClockwise,
                label: 'Booked at',
                value: Formatters.date(detail.orderCreatedAt!),
              ),
          ] else
            _DetailRow(
              icon: PhosphorIconsDuotone.warningCircle,
              label: 'Booking',
              value: 'No order placed yet',
            ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.detail});
  final ManagerEventDetail detail;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.foodCost != null)
            _BillRow('Food cost', detail.foodCost!),
          if ((detail.deliveryCharge ?? 0) > 0)
            _BillRow('Delivery', detail.deliveryCharge!),
          if ((detail.banquetCharge ?? 0) > 0)
            _BillRow('Banquet', detail.banquetCharge!),
          if ((detail.buffetSetup ?? 0) > 0)
            _BillRow('Buffet setup', detail.buffetSetup!),
          if ((detail.serviceBoyCost ?? 0) > 0)
            _BillRow('Service boys', detail.serviceBoyCost!),
          if ((detail.waterBottleCost ?? 0) > 0)
            _BillRow('Water bottles', detail.waterBottleCost!),
          if ((detail.platformFee ?? 0) > 0)
            _BillRow('Platform fee', detail.platformFee!),
          if ((detail.gst ?? 0) > 0) _BillRow('GST + tax', detail.gst!),
          if (detail.subtotal != null && detail.total != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.xs),
              child: Divider(color: AppColors.border, height: 1),
            ),
          if (detail.total != null)
            _BillRow('Total', detail.total!, bold: true),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow(this.label, this.amount, {this.bold = false});
  final String label;
  final double amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = (bold ? AppTextStyles.bodyBold : AppTextStyles.body)
        .copyWith(fontSize: bold ? 15 : 13);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            Formatters.currency(amount),
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _VendorLotCard extends StatelessWidget {
  const _VendorLotCard({required this.lot});
  final OrderVendorLot lot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(PhosphorIconsDuotone.storefront,
                color: AppColors.accentDark, size: 20),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lot.restaurantName ?? 'Restaurant',
                  style: AppTextStyles.bodyBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(Formatters.currency(lot.subtotal),
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          _StatusChip(
            label: lot.status.label,
            color: _lotStatusColor(lot.status),
          ),
        ],
      ),
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.staffAsync});
  final AsyncValue<List<EventAssignment>> staffAsync;

  @override
  Widget build(BuildContext context) {
    return staffAsync.when(
      loading: () => const AppCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => AppCard(
        child: Text('Could not load roster: $e',
            style: AppTextStyles.caption),
      ),
      data: (rows) {
        final managers = rows
            .where((r) => r.roleOnEvent == EventAssignmentRole.manager)
            .toList();
        final boys = rows
            .where((r) => r.roleOnEvent == EventAssignmentRole.serviceBoy)
            .toList();
        if (managers.isEmpty && boys.isEmpty) {
          return AppCard(
            child: Text(
              'Nobody assigned yet. Accept the booking and assign a manager '
              'to start staffing.',
              style: AppTextStyles.caption,
            ),
          );
        }
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${boys.length} service '
                '${boys.length == 1 ? 'boy' : 'boys'} '
                'and ${managers.length} '
                '${managers.length == 1 ? 'manager' : 'managers'} assigned',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSizes.sm),
              for (final a in [...managers, ...boys])
                _RosterTile(assignment: a),
            ],
          ),
        );
      },
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({required this.assignment});
  final EventAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final isManager =
        assignment.roleOnEvent == EventAssignmentRole.manager;
    final initial = (assignment.profileName?.isNotEmpty ?? false)
        ? assignment.profileName![0].toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isManager
                ? AppColors.primarySoft
                : AppColors.surfaceAlt,
            foregroundColor: isManager
                ? AppColors.primary
                : AppColors.textSecondary,
            child: Text(
              initial,
              style: AppTextStyles.captionBold.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              assignment.profileName ?? 'Staff member',
              style: AppTextStyles.body.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _StatusChip(
            label: assignment.roleOnEvent.label,
            color: isManager ? AppColors.primary : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
    this.valueChip,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;
  final Widget? valueChip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                if (valueChip != null)
                  valueChip!
                else
                  Text(
                    value,
                    style: AppTextStyles.body.copyWith(fontSize: 13.5),
                    maxLines: multiline ? 4 : 1,
                    overflow: multiline
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(
          color: color,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        const SizedBox(height: AppSizes.xxxl),
        const Icon(PhosphorIconsDuotone.warningCircle,
            size: 48, color: AppColors.textMuted),
        const SizedBox(height: AppSizes.md),
        Text('Booking not found',
            style: AppTextStyles.heading2,
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'This booking may have been cancelled or moved out of your inbox.',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ───────────────────────── Assign-manager sheet ─────────────────────────

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
      ref.invalidate(eventStaffProvider(eventId));
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${manager.name ?? 'Manager'} assigned to event'),
          ),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign manager', style: AppTextStyles.display),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Pick a manager to run this event. They can then staff service '
              'boys from their team.',
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
                        'No managers available. An admin must promote a user '
                        'to the manager role first.',
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

// ───────────────────────── Helpers ─────────────────────────

String? _timeRange(String? start, String? end) {
  String trim(String s) => s.length >= 5 ? s.substring(0, 5) : s;
  if (start != null && end != null) return '${trim(start)} – ${trim(end)}';
  if (start != null) return trim(start);
  return null;
}

Color _orderStatusColor(OrderStatus? s) {
  return switch (s) {
    OrderStatus.delivered => AppColors.success,
    OrderStatus.cancelled => AppColors.error,
    OrderStatus.dispatched ||
    OrderStatus.preparing ||
    OrderStatus.confirmed =>
      AppColors.accent,
    _ => AppColors.textSecondary,
  };
}

String _payLabel(PaymentStatus? p) => switch (p) {
      PaymentStatus.paid => 'Paid',
      PaymentStatus.failed => 'Failed',
      PaymentStatus.refunded => 'Refunded',
      _ => 'Pending',
    };

Color _payColor(PaymentStatus? p) => switch (p) {
      PaymentStatus.paid => AppColors.success,
      PaymentStatus.failed => AppColors.error,
      PaymentStatus.refunded => AppColors.accent,
      _ => AppColors.warning,
    };

Color _lotStatusColor(VendorLotStatus s) {
  return switch (s) {
    VendorLotStatus.delivered => AppColors.success,
    VendorLotStatus.cancelled => AppColors.error,
    VendorLotStatus.preparing ||
    VendorLotStatus.readyForPickup ||
    VendorLotStatus.pickedUp ||
    VendorLotStatus.accepted =>
      AppColors.accent,
    VendorLotStatus.pending => AppColors.warning,
  };
}
