import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/event_assignment.dart';
import '../../../data/models/manager_event_detail.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_vendor_lot.dart';
import '../../../shared/providers/order_providers.dart';
import '../../../shared/providers/staffing_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// Operational view of a single event the manager has been assigned to.
///
/// Pulls one aggregated booking snapshot (event + venue + tier + order +
/// vendor lots) plus the existing roster stream so the manager can see
/// the full picture without bouncing between screens.
class ManagerEventDetailScreen extends ConsumerWidget {
  const ManagerEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(managerEventDetailProvider(eventId));
    final staffAsync = ref.watch(eventStaffProvider(eventId));

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Event details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      padded: false,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(managerEventDetailProvider(eventId));
          ref.invalidate(eventStaffProvider(eventId));
          await ref.read(managerEventDetailProvider(eventId).future);
        },
        child: detailAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              Text('Could not load event: $e',
                  style: AppTextStyles.caption),
            ],
          ),
          data: (detail) {
            if (detail == null) {
              return const _NotFoundView();
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.xl,
              ),
              children: [
                _StatusBanner(detail: detail),
                const SizedBox(height: AppSizes.md),
                _SectionTitle('When & where'),
                _WhenWhereCard(detail: detail),
                const SizedBox(height: AppSizes.lg),
                _SectionTitle('Booking'),
                _BookingCard(detail: detail),
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
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── Section bits ─────────────────────────

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
  const _StatusBanner({required this.detail});
  final ManagerEventDetail detail;

  @override
  Widget build(BuildContext context) {
    final date = detail.eventDate;
    final dateText = date != null ? Formatters.date(date) : 'Date TBD';
    final timeRange = _timeRange(detail.startTime, detail.endTime);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(PhosphorIconsBold.userGear,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are managing this event',
                    style: AppTextStyles.bodyBold),
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
          Text(Formatters.currency(amount),
              style: style.copyWith(fontWeight: FontWeight.w700)),
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
                Text(
                  Formatters.currency(lot.subtotal),
                  style: AppTextStyles.caption,
                ),
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
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${boys.length} service '
                  '${boys.length == 1 ? 'boy' : 'boys'} '
                  'and ${managers.length} '
                  '${managers.length == 1 ? 'manager' : 'managers'} '
                  'assigned',
                  style: AppTextStyles.caption),
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
            child: Text(initial,
                style: AppTextStyles.captionBold.copyWith(fontSize: 12)),
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
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        Text('Event not found',
            style: AppTextStyles.heading2,
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          'This event may have been cancelled or you no longer have access.',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
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
