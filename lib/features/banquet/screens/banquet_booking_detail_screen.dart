import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer.dart';

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
        toolbarHeight: 64,
        // Two-line title — keeps customer + total + date pinned at the
        // top through the whole scroll so the operator never loses
        // context.
        title: _BookingAppBarTitle(detailAsync: detailAsync),
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
          loading: () => const _BookingDetailLoading(),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () {
              ref.invalidate(managerEventDetailProvider(eventId));
              ref.invalidate(eventStaffProvider(eventId));
            },
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
                      _BookingSummaryCard(
                        detail: detail,
                        hasManager: hasManager,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      _SectionTitle('Timeline'),
                      _TimelineCard(
                        detail: detail,
                        staffAsync: staffAsync,
                      ),
                      const SizedBox(height: AppSizes.lg),
                      _SectionTitle('Customer'),
                      _CustomerCard(detail: detail),
                      const SizedBox(height: AppSizes.lg),
                      _SectionTitle('When & where'),
                      _WhenWhereCard(detail: detail),
                      const SizedBox(height: AppSizes.lg),
                      _SectionTitle('Booking'),
                      _BookingCard(detail: detail),
                      const SizedBox(height: AppSizes.lg),
                      _SectionTitle('Operator notes'),
                      _NotesCard(
                        eventId: eventId,
                        initialNotes: detail.banquetNotes,
                      ),
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

// ───────────────────────── AppBar title ─────────────────────────

/// Two-line AppBar title. Top line stays "Booking review"; the second
/// line surfaces the customer name + (when present) the booking total
/// and event date so the operator always sees what they're looking at,
/// no matter where they've scrolled to.
class _BookingDetailLoading extends StatelessWidget {
  const _BookingDetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShimmerBox(
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(width: AppSizes.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: 180, height: 18),
                        SizedBox(height: 8),
                        ShimmerBox(width: 240, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              const Row(
                children: [
                  Expanded(child: ShimmerStatCard()),
                  SizedBox(width: AppSizes.sm),
                  Expanded(child: ShimmerStatCard()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        for (var i = 0; i < 5; i++) ...[
          const ShimmerBox(width: 130, height: 14),
          const SizedBox(height: AppSizes.sm),
          const ShimmerBookingCard(),
          const SizedBox(height: AppSizes.lg),
        ],
      ],
    );
  }
}

class _BookingAppBarTitle extends StatelessWidget {
  const _BookingAppBarTitle({required this.detailAsync});
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
      if (detail.total != null && detail.total! > 0) {
        parts.add(Formatters.currency(detail.total!));
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
          'Booking review',
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

// ───────────────────────── Timeline ─────────────────────────

/// Vertical step timeline showing the booking's lifecycle so far —
/// gives the operator the audit-trail "fine SaaS" feel and answers
/// "when did we accept this?" without leaving the page.
///
/// Steps surfaced (skipped if the underlying timestamp isn't known):
///   • Booked          — `order.created_at`
///   • Status          — current banquet_status (always shown)
///   • Manager assigned — earliest manager assignment.assigned_at
///   • Event date      — future-tense step pinned at the bottom
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.detail, required this.staffAsync});
  final ManagerEventDetail detail;
  final AsyncValue<List<EventAssignment>> staffAsync;

  @override
  Widget build(BuildContext context) {
    final managerAssignment = staffAsync.valueOrNull
        ?.where((a) => a.roleOnEvent == EventAssignmentRole.manager)
        .fold<EventAssignment?>(
      null,
      (acc, a) => acc == null || a.assignedAt.isBefore(acc.assignedAt)
          ? a
          : acc,
    );
    final status = detail.banquetStatus ?? BanquetEventStatus.pending;
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
      _TimelineStep(
        icon: _statusIcon(status),
        color: _statusColor(status),
        headline: switch (status) {
          BanquetEventStatus.pending => 'Awaiting your review',
          BanquetEventStatus.accepted => 'Accepted by you',
          BanquetEventStatus.declined => 'Declined by you',
          BanquetEventStatus.cancelled => 'Cancelled',
          BanquetEventStatus.completed => 'Completed',
        },
        subline: switch (status) {
          BanquetEventStatus.pending => 'Tap "Accept booking" below to confirm',
          _ => 'Status updated',
        },
        done: status != BanquetEventStatus.pending,
      ),
      if (managerAssignment != null)
        _TimelineStep(
          icon: PhosphorIconsBold.userGear,
          color: AppColors.primary,
          headline: 'Manager assigned',
          subline:
              '${Formatters.date(managerAssignment.assignedAt)} · ${managerAssignment.profileName ?? 'Manager'}',
          done: true,
        )
      else if (status == BanquetEventStatus.accepted)
        _TimelineStep(
          icon: PhosphorIconsBold.userGear,
          color: AppColors.textMuted,
          headline: 'Assign a manager',
          subline: 'Use the action below to staff this event',
          done: false,
        ),
      if (detail.eventDate != null)
        _TimelineStep(
          icon: PhosphorIconsBold.calendarBlank,
          color: AppColors.accent,
          headline: 'Event day',
          subline: Formatters.date(detail.eventDate!),
          done: detail.eventDate!.isBefore(DateTime.now()),
          isFuture:
              !detail.eventDate!.isBefore(DateTime.now()),
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

  IconData _statusIcon(BanquetEventStatus s) => switch (s) {
        BanquetEventStatus.pending => PhosphorIconsBold.clock,
        BanquetEventStatus.accepted => PhosphorIconsBold.check,
        BanquetEventStatus.declined => PhosphorIconsBold.x,
        BanquetEventStatus.cancelled => PhosphorIconsBold.prohibit,
        BanquetEventStatus.completed => PhosphorIconsBold.flag,
      };

  Color _statusColor(BanquetEventStatus s) => switch (s) {
        BanquetEventStatus.pending => AppColors.warning,
        BanquetEventStatus.accepted => AppColors.success,
        BanquetEventStatus.declined => AppColors.error,
        BanquetEventStatus.cancelled => AppColors.textMuted,
        BanquetEventStatus.completed => AppColors.success,
      };
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
          // Rail (line + dot) sized to the row's height.
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

// ───────────────────────── Operator notes ─────────────────────────

/// Inline-editable operator note. View mode shows the saved text (or a
/// placeholder when empty) plus an Edit pencil. Tapping Edit flips the
/// card into a TextField with Save / Cancel; Save persists via
/// `BanquetRepository.updateEventNotes` and refreshes the providers
/// powering the detail screen + the inbox so the new note shows up
/// everywhere immediately.
class _NotesCard extends ConsumerStatefulWidget {
  const _NotesCard({required this.eventId, required this.initialNotes});

  final String eventId;
  final String? initialNotes;

  @override
  ConsumerState<_NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends ConsumerState<_NotesCard> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;
  String _persisted = '';

  @override
  void initState() {
    super.initState();
    _persisted = widget.initialNotes ?? '';
    _controller = TextEditingController(text: _persisted);
  }

  @override
  void didUpdateWidget(covariant _NotesCard old) {
    super.didUpdateWidget(old);
    // If the underlying provider re-emitted with a different note (e.g.
    // another operator updated it server-side), pick up the new value
    // — but only when we're not actively editing, so we don't clobber
    // the user's in-progress text.
    if (!_editing && (widget.initialNotes ?? '') != _persisted) {
      _persisted = widget.initialNotes ?? '';
      _controller.text = _persisted;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = _controller.text.trim();
    if (next == _persisted.trim()) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(banquetRepositoryProvider).updateEventNotes(
            eventId: widget.eventId,
            notes: next,
          );
      ref.invalidate(managerEventDetailProvider(widget.eventId));
      ref.invalidate(banquetInboxProvider);
      if (!mounted) return;
      setState(() {
        _persisted = next;
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Text('Operator note saved'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save note: $e')),
      );
    }
  }

  void _cancel() {
    setState(() {
      _controller.text = _persisted;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 3,
              autofocus: true,
              style: AppTextStyles.body.copyWith(fontSize: 13.5),
              decoration: InputDecoration(
                hintText:
                    'Add a private note about this booking — visible to operators only.',
                hintStyle: AppTextStyles.caption,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.4,
                  ),
                ),
                contentPadding: const EdgeInsets.all(AppSizes.md),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : _cancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSizes.xs),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: 8,
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(PhosphorIconsBold.check, size: 14),
                  label: Text(_saving ? 'Saving' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final hasNote = _persisted.trim().isNotEmpty;
    return AppCard(
      onTap: () => setState(() => _editing = true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: hasNote
                ? Text(
                    _persisted,
                    style: AppTextStyles.body.copyWith(fontSize: 13.5),
                  )
                : Row(
                    children: [
                      Icon(
                        PhosphorIconsDuotone.notePencil,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          'Add an operator note',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: AppSizes.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsBold.pencilSimple,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  hasNote ? 'Edit' : 'Add',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.primary,
                    fontSize: 11,
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

  Future<void> _requestStatusChange(
    BuildContext context,
    WidgetRef ref,
    BanquetEventStatus next,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _StatusConfirmDialog(status: next),
    );
    if (confirmed != true || !context.mounted) return;
    await _setStatus(context, ref, next);
  }

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
        // Semantic colors: Accept reads as the safe primary path
        // (filled green), Decline reads as cautious/destructive
        // (outlined red, lower visual weight). Accept also gets 1.5×
        // the horizontal flex so the eye lands on it first.
        BanquetEventStatus.pending => Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _requestStatusChange(
                    context,
                    ref,
                    BanquetEventStatus.declined,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(PhosphorIconsBold.x, size: 16),
                  label: const Text('Decline'),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _requestStatusChange(
                    context,
                    ref,
                    BanquetEventStatus.accepted,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(PhosphorIconsBold.check, size: 16),
                  label: const Text(
                    'Accept booking',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
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

class _StatusConfirmDialog extends StatelessWidget {
  const _StatusConfirmDialog({required this.status});

  final BanquetEventStatus status;

  @override
  Widget build(BuildContext context) {
    final isAccept = status == BanquetEventStatus.accepted;
    final color = isAccept ? AppColors.success : AppColors.error;
    final title = isAccept ? 'Accept this booking?' : 'Decline this booking?';
    final body = isAccept
        ? 'This confirms the venue booking. You can assign a manager after accepting.'
        : 'This removes the booking from active review. Check the customer, date, guests, and notes before declining.';
    final actionLabel = isAccept ? 'Accept booking' : 'Decline booking';

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isAccept ? PhosphorIconsBold.check : PhosphorIconsBold.x,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Row(
        children: [
          // Small accent rule — gives every section a clear visual
          // anchor and consistent rhythm down the page.
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

class _BookingSummaryCard extends StatelessWidget {
  const _BookingSummaryCard({
    required this.detail,
    required this.hasManager,
  });

  final ManagerEventDetail detail;
  final bool hasManager;

  ({Color color, String label, IconData icon}) _statusTheme() {
    final s = detail.banquetStatus ?? BanquetEventStatus.pending;
    return switch (s) {
      BanquetEventStatus.pending => (
          color: AppColors.warning,
          label: 'Awaiting review',
          icon: PhosphorIconsBold.clock,
        ),
      BanquetEventStatus.accepted => (
          color: AppColors.success,
          label: hasManager ? 'Accepted - staffed' : 'Accepted - needs manager',
          icon: PhosphorIconsBold.check,
        ),
      BanquetEventStatus.declined => (
          color: AppColors.textMuted,
          label: 'Declined',
          icon: PhosphorIconsBold.x,
        ),
      BanquetEventStatus.cancelled => (
          color: AppColors.textMuted,
          label: 'Cancelled',
          icon: PhosphorIconsBold.prohibit,
        ),
      BanquetEventStatus.completed => (
          color: AppColors.success,
          label: 'Completed',
          icon: PhosphorIconsBold.flag,
        ),
    };
  }

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
    final t = _statusTheme();
    final dateText = detail.eventDate != null
        ? Formatters.date(detail.eventDate!)
        : 'Date TBD';
    final timeRange = _timeRange(detail.startTime, detail.endTime);
    final countdown = _countdownLabel(detail.eventDate);
    final amountText = detail.total != null && detail.total! > 0
        ? Formatters.currency(detail.total!)
        : 'Total pending';
    final paymentText = _payLabel(detail.paymentStatus);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: [
          BoxShadow(
            color: t.color.withValues(alpha: 0.13),
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
                    t.color.withValues(alpha: 0.22),
                    AppColors.surface,
                    AppColors.accentSoft.withValues(alpha: 0.78),
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
                        color: t.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: t.color.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(t.icon, color: Colors.white, size: 23),
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
                      _SummaryPill(label: countdown, color: t.color),
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
                        label: 'Total',
                        value: amountText,
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
                    _SummaryPill(label: t.label, color: t.color),
                    _SummaryPill(
                      label: 'Payment $paymentText',
                      color: _payColor(detail.paymentStatus),
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

  String? _countdownLabel(DateTime? eventDate) {
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
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: color,
                    fontSize: highlight ? 15 : 14,
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
    final countdown = _countdown(date);
    final bookedAgo = _relativeBookedAt(detail.orderCreatedAt);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        // Subtle gradient instead of flat tint — gives the banner more
        // visual depth and makes the status read as the page's hero.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.color.withValues(alpha: 0.18),
            t.color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: t.color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: t.color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
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
              if (countdown != null) ...[
                const SizedBox(width: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusPill),
                    border: Border.all(
                      color: t.color.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    countdown,
                    style: AppTextStyles.captionBold.copyWith(
                      color: t.color,
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (bookedAgo != null) ...[
            const SizedBox(height: AppSizes.sm),
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsDuotone.clockCounterClockwise,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Booked $bookedAgo',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Human-friendly time-until-event countdown shown as a small pill on
  /// the right of the status row. Returns null when there's no event
  /// date or when the event has already passed (countdowns are only
  /// useful for triage on upcoming bookings).
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

  /// Human-friendly "X ago" for the order's created_at — gives the
  /// operator a quick sense of how stale a pending booking is.
  String? _relativeBookedAt(DateTime? at) {
    if (at == null) return null;
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'just now';
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes} ${delta.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours} ${delta.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (delta.inDays < 30) {
      return '${delta.inDays} ${delta.inDays == 1 ? 'day' : 'days'} ago';
    }
    final months = (delta.inDays / 30).round();
    return '$months ${months == 1 ? 'month' : 'months'} ago';
  }
}

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
            const Icon(
              PhosphorIconsBold.check,
              color: Colors.white,
              size: 16,
            ),
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
    if (bold) {
      // Total row — promote with primary color and a larger amount so
      // the operator's eye lands on it instantly.
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    this.onCopy,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool multiline;
  final Widget? valueChip;

  /// When non-null, a small copy-icon button is shown on the right and
  /// the whole row becomes tappable. Used by the Customer card so the
  /// operator can one-tap copy phone / email / booking ID.
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

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: PhosphorIconsDuotone.warningCircle,
      title: 'Booking not found',
      message: 'This booking may have been cancelled or moved out of your inbox.',
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
                loading: () => ListView.separated(
                  controller: scrollCtrl,
                  itemCount: 5,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSizes.sm),
                  itemBuilder: (_, __) => AppCard(
                    color: AppColors.surfaceAlt,
                    border: Border.all(color: AppColors.border),
                    radius: AppSizes.radiusSm,
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
                  if (rows.isEmpty) {
                    return const EmptyState(
                      icon: PhosphorIconsDuotone.userCircleMinus,
                      title: 'No managers available',
                      message:
                          'An admin must promote a user to the manager role before this event can be staffed.',
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
