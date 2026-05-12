import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/shimmer.dart';

/// Operational view of a single event the manager has been assigned to.
///
/// Pulls one aggregated booking snapshot (event + venue + tier + order +
/// vendor lots) plus the existing roster stream so the manager can see
/// the full picture without bouncing between screens. Polished to the
/// same bar as the operator booking-review screen: subtitle AppBar,
/// gradient status banner with countdown, status timeline, tap-to-copy
/// customer info, emphasized bill total, and shimmer loading.
class ManagerEventDetailScreen extends ConsumerWidget {
  const ManagerEventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(managerEventDetailProvider(eventId));
    final staffAsync = ref.watch(eventStaffProvider(eventId));

    return AppScaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: _EventAppBarTitle(detailAsync: detailAsync),
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
          loading: () => const _DetailLoading(),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () =>
                ref.invalidate(managerEventDetailProvider(eventId)),
          ),
          data: (detail) {
            if (detail == null) return const _NotFoundView();
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.xl,
              ),
              children: [
                _ManagerEventSummaryCard(
                  detail: detail,
                  staffAsync: staffAsync,
                ),
                const SizedBox(height: AppSizes.lg),
                _SectionTitle('Timeline'),
                _TimelineCard(detail: detail, staffAsync: staffAsync),
                const SizedBox(height: AppSizes.lg),
                _SectionTitle('Customer'),
                _CustomerCard(detail: detail),
                const SizedBox(height: AppSizes.lg),
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

// ───────────────────────── AppBar title ─────────────────────────

/// Two-line AppBar. Top line stays "Event details"; the subtitle
/// surfaces the customer + date so the manager never loses context
/// during a long scroll.
class _EventAppBarTitle extends StatelessWidget {
  const _EventAppBarTitle({required this.detailAsync});
  final AsyncValue<ManagerEventDetail?> detailAsync;

  @override
  Widget build(BuildContext context) {
    final detail = detailAsync.valueOrNull;
    final parts = <String>[];
    if (detail != null) {
      final name = detail.customerName?.trim();
      if (name != null && name.isNotEmpty) {
        parts.add(name);
      } else {
        parts.add('#${detail.eventId.substring(0, 8)}');
      }
      if (detail.eventDate != null) {
        parts.add(Formatters.date(detail.eventDate!));
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Event details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (parts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              parts.join(' · '),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Section title (accent bar) ─────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Status banner ─────────────────────────

class _ManagerEventSummaryCard extends StatelessWidget {
  const _ManagerEventSummaryCard({
    required this.detail,
    required this.staffAsync,
  });

  final ManagerEventDetail detail;
  final AsyncValue<List<EventAssignment>> staffAsync;

  String get _customerLabel {
    final name = detail.customerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final phone = detail.customerPhone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    final email = detail.customerEmail?.trim();
    if (email != null && email.isNotEmpty) return email;
    return detail.eventId.length >= 8
        ? '#${detail.eventId.substring(0, 8)}'
        : '#${detail.eventId}';
  }

  @override
  Widget build(BuildContext context) {
    final dateText = detail.eventDate != null
        ? Formatters.date(detail.eventDate!)
        : 'Date TBD';
    final timeRange = _timeRange(detail.startTime, detail.endTime);
    final countdown = _countdown(detail.eventDate);
    final rows = staffAsync.valueOrNull ?? const <EventAssignment>[];
    final serviceBoyCount = rows
        .where((r) => r.roleOnEvent == EventAssignmentRole.serviceBoy)
        .length;
    final managerCount = rows
        .where((r) => r.roleOnEvent == EventAssignmentRole.manager)
        .length;
    final paymentLabel = _payLabel(detail.paymentStatus);
    final totalLabel = detail.total != null && detail.total! > 0
        ? Formatters.currency(detail.total!)
        : 'Pending';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.13),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.surface,
                    AppColors.accentSoft.withValues(alpha: 0.86),
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
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        PhosphorIconsBold.userGear,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _customerLabel,
                            style: AppTextStyles.heading2.copyWith(
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              dateText,
                              if (timeRange != null) timeRange,
                              if (detail.session != null) detail.session!,
                            ].join(' - '),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (countdown != null) ...[
                      const SizedBox(width: AppSizes.sm),
                      _SummaryPill(
                        label: countdown,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryMetric(
                        label: 'Guests',
                        value: detail.guestCount != null
                            ? '${detail.guestCount}'
                            : '--',
                        icon: PhosphorIconsDuotone.users,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _SummaryMetric(
                        label: 'Team',
                        value: '$serviceBoyCount boys',
                        icon: PhosphorIconsDuotone.handshake,
                        highlight: serviceBoyCount > 0,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: _SummaryMetric(
                        label: 'Total',
                        value: totalLabel,
                        icon: PhosphorIconsDuotone.receipt,
                        highlight: detail.total != null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    _SummaryPill(
                      label: '$managerCount manager assigned',
                      color: AppColors.primary,
                      icon: PhosphorIconsBold.userGear,
                    ),
                    _SummaryPill(
                      label: 'Payment $paymentLabel',
                      color: _payColor(detail.paymentStatus),
                      icon: PhosphorIconsDuotone.creditCard,
                    ),
                    if (detail.banquetVenueName != null)
                      _SummaryPill(
                        label: detail.banquetVenueName!,
                        color: AppColors.info,
                        icon: PhosphorIconsDuotone.buildings,
                      ),
                    if (detail.tierLabel != null)
                      _SummaryPill(
                        label: detail.tierLabel!,
                        color: AppColors.accentDark,
                        icon: PhosphorIconsDuotone.crown,
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

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(height: AppSizes.sm),
          Text(
            value,
            style: AppTextStyles.bodyBold.copyWith(
              color: color,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textMuted,
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

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                color: color,
                fontSize: 10,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.detail});
  final ManagerEventDetail detail;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;
    final date = detail.eventDate;
    final dateText = date != null ? Formatters.date(date) : 'Date TBD';
    final timeRange = _timeRange(detail.startTime, detail.endTime);
    final countdown = _countdown(date);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        // Subtle gradient lift — gives the banner more visual weight
        // than a flat tint and matches the operator booking-review
        // screen's treatment.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              PhosphorIconsBold.userGear,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are managing this event',
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateText${timeRange != null ? ' · $timeRange' : ''}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (countdown != null) ...[
            const SizedBox(width: AppSizes.sm),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Text(
                countdown,
                style: AppTextStyles.captionBold.copyWith(
                  color: color,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Timeline ─────────────────────────

/// Vertical step timeline showing the event's lifecycle from the
/// manager's perspective: customer booking → assigned to me → event
/// day. Same shape as the operator booking-review timeline.
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.detail, required this.staffAsync});
  final ManagerEventDetail detail;
  final AsyncValue<List<EventAssignment>> staffAsync;

  @override
  Widget build(BuildContext context) {
    final myManagerAssignment = staffAsync.valueOrNull
        ?.where((a) => a.roleOnEvent == EventAssignmentRole.manager)
        .fold<EventAssignment?>(
      null,
      (acc, a) => acc == null || a.assignedAt.isBefore(acc.assignedAt)
          ? a
          : acc,
    );
    final boys = staffAsync.valueOrNull
            ?.where((a) => a.roleOnEvent == EventAssignmentRole.serviceBoy)
            .length ??
        0;
    final steps = <_TimelineStep>[
      if (detail.orderCreatedAt != null)
        _TimelineStep(
          icon: PhosphorIconsBold.shoppingBag,
          color: AppColors.textSecondary,
          headline: 'Booking placed',
          subline:
              '${Formatters.date(detail.orderCreatedAt!)} · by customer',
          done: true,
        ),
      if (myManagerAssignment != null)
        _TimelineStep(
          icon: PhosphorIconsBold.userGear,
          color: AppColors.primary,
          headline: 'Assigned to you',
          subline: Formatters.date(myManagerAssignment.assignedAt),
          done: true,
        ),
      _TimelineStep(
        icon: PhosphorIconsBold.handshake,
        color: boys > 0 ? AppColors.success : AppColors.warning,
        headline: boys > 0
            ? 'Service boys staffed'
            : 'Staff service boys',
        subline: boys > 0
            ? '$boys ${boys == 1 ? 'service boy' : 'service boys'} on the roster'
            : 'Use "Add boy" on the home screen to staff this event',
        done: boys > 0,
      ),
      if (detail.eventDate != null)
        _TimelineStep(
          icon: PhosphorIconsBold.calendarBlank,
          color: AppColors.accent,
          headline: 'Event day',
          subline: Formatters.date(detail.eventDate!),
          done: detail.eventDate!.isBefore(DateTime.now()),
          isFuture: !detail.eventDate!.isBefore(DateTime.now()),
        ),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              isFirst: i == 0,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.icon,
    required this.color,
    required this.headline,
    required this.subline,
    required this.done,
    this.isFuture = false,
  });
  final IconData icon;
  final Color color;
  final String headline;
  final String subline;
  final bool done;
  final bool isFuture;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });
  final _TimelineStep step;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = step.done ? step.color : AppColors.border;
    final headlineColor = step.done || step.isFuture
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst ? Colors.transparent : AppColors.border,
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.done
                        ? dotColor
                        : (step.isFuture
                            ? AppColors.surfaceAlt
                            : AppColors.surface),
                    border: Border.all(
                      color: step.done ? dotColor : AppColors.border,
                      width: step.done ? 0 : 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    step.icon,
                    size: 12,
                    color: step.done
                        ? Colors.white
                        : (step.isFuture
                            ? AppColors.textSecondary
                            : AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.headline,
                    style: AppTextStyles.bodyBold.copyWith(
                      fontSize: 13.5,
                      color: headlineColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subline,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isLast ? 0 : AppSizes.xs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Customer card (tap-to-copy) ─────────────────────────

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.detail});
  final ManagerEventDetail detail;

  bool _has(String? s) => s != null && s.trim().isNotEmpty;

  String get _shortId => detail.eventId.length >= 8
      ? '#${detail.eventId.substring(0, 8)}'
      : '#${detail.eventId}';

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(PhosphorIconsBold.check, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('$label copied to clipboard')),
          ],
        ),
      ),
    );
  }

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
              onCopy: () => _copy(context, detail.customerPhone!, 'Phone'),
            ),
          if (_has(detail.customerEmail) &&
              (_has(detail.customerName) || _has(detail.customerPhone)))
            _DetailRow(
              icon: PhosphorIconsDuotone.envelope,
              label: 'Email',
              value: detail.customerEmail!,
              onCopy: () => _copy(context, detail.customerEmail!, 'Email'),
            ),
          _DetailRow(
            icon: PhosphorIconsDuotone.identificationCard,
            label: 'Booking ID',
            value: _shortId,
            onCopy: () => _copy(context, detail.eventId, 'Booking ID'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── When & where ─────────────────────────

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

// ───────────────────────── Booking ─────────────────────────

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

// ───────────────────────── Bill summary ─────────────────────────

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
    if (bold) {
      // Total row gets primary-color emphasis so the eye lands on it.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyBold.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              Formatters.currency(amount),
              style: AppTextStyles.display.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
          ),
          Text(
            Formatters.currency(amount),
            style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Vendor lot ─────────────────────────

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
            child: const Icon(
              PhosphorIconsDuotone.storefront,
              color: AppColors.accentDark,
              size: 20,
            ),
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

// ───────────────────────── Roster ─────────────────────────

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.staffAsync});
  final AsyncValue<List<EventAssignment>> staffAsync;

  @override
  Widget build(BuildContext context) {
    return staffAsync.when(
      loading: () => const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 190, height: 14),
            SizedBox(height: AppSizes.md),
            ShimmerBox(width: double.infinity, height: 34),
            SizedBox(height: AppSizes.sm),
            ShimmerBox(width: double.infinity, height: 34),
          ],
        ),
      ),
      error: (e, _) => AppCard(
        child: AppErrorView(error: e, compact: true),
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
            backgroundColor:
                isManager ? AppColors.primarySoft : AppColors.surfaceAlt,
            foregroundColor:
                isManager ? AppColors.primary : AppColors.textSecondary,
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

// ───────────────────────── DetailRow (tap-to-copy aware) ─────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
    this.valueChip,
    this.onCopy,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;
  final Widget? valueChip;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
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
                Text(
                  label,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
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
          if (onCopy != null) ...[
            const SizedBox(width: AppSizes.sm),
            Icon(
              PhosphorIconsBold.copy,
              size: 16,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
    if (onCopy == null) return row;
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: row,
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

// ───────────────────────── Loading / not-found ─────────────────────────

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      children: const [
        ShimmerBox(height: 78),
        SizedBox(height: AppSizes.lg),
        ShimmerBox(width: 90, height: 14),
        SizedBox(height: 8),
        ShimmerBookingCard(),
        SizedBox(height: AppSizes.lg),
        ShimmerBox(width: 90, height: 14),
        SizedBox(height: 8),
        ShimmerBookingCard(),
      ],
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
        const Icon(
          PhosphorIconsDuotone.warningCircle,
          size: 48,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: AppSizes.md),
        Text(
          'Event not found',
          style: AppTextStyles.heading2,
          textAlign: TextAlign.center,
        ),
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

String? _countdown(DateTime? eventDate) {
  if (eventDate == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(eventDate.year, eventDate.month, eventDate.day);
  final days = target.difference(today).inDays;
  if (days < -1) return '${-days} days ago';
  if (days == -1) return 'yesterday';
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 7) return 'in $days days';
  if (days < 14) return 'in 1 week';
  if (days < 30) return 'in ${(days / 7).round()} weeks';
  return 'in ${(days / 30).round()} months';
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
