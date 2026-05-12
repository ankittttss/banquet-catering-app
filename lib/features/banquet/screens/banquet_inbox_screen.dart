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
import '../../../shared/widgets/customer_line.dart';
import '../../../shared/widgets/shimmer.dart';
import '../widgets/banquet_bottom_nav.dart';

/// Filter buckets surfaced as chips at the top of the inbox.
enum _InboxFilter { all, pending, accepted, declined }

extension _InboxFilterLabel on _InboxFilter {
  String get label => switch (this) {
        _InboxFilter.all => 'All',
        _InboxFilter.pending => 'Pending',
        _InboxFilter.accepted => 'Accepted',
        _InboxFilter.declined => 'Declined',
      };
}

class BanquetInboxScreen extends ConsumerStatefulWidget {
  const BanquetInboxScreen({super.key, this.initialFilter});

  /// Optional deep-link filter keyword. `accepted` lands the user on the
  /// "Accepted" chip pre-selected so the Assign-managers shortcut feels
  /// like a dedicated staffing surface.
  final String? initialFilter;

  @override
  ConsumerState<BanquetInboxScreen> createState() =>
      _BanquetInboxScreenState();
}

class _BanquetInboxScreenState extends ConsumerState<BanquetInboxScreen> {
  late _InboxFilter _filter;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filter = switch (widget.initialFilter) {
      'accepted' => _InboxFilter.accepted,
      'pending' => _InboxFilter.pending,
      'declined' => _InboxFilter.declined,
      _ => _InboxFilter.all,
    };
    _searchCtrl.addListener(() {
      final next = _searchCtrl.text.trim().toLowerCase();
      if (next != _query) setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesFilter(BanquetInboxEvent e) => switch (_filter) {
        _InboxFilter.all => true,
        _InboxFilter.pending => e.status == BanquetEventStatus.pending,
        _InboxFilter.accepted => e.status == BanquetEventStatus.accepted,
        _InboxFilter.declined => e.status == BanquetEventStatus.declined,
      };

  /// Substring-match the search query against any obvious identifier on
  /// the booking. Empty query passes through everything.
  bool _matchesQuery(BanquetInboxEvent e) {
    if (_query.isEmpty) return true;
    final haystack = [
      e.customerName,
      e.customerPhone,
      e.customerEmail,
      e.id,
      e.location,
      e.session,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(banquetInboxProvider);
    final isStaffingShortcut = widget.initialFilter == 'accepted';
    final title =
        isStaffingShortcut ? 'Staff your events' : 'Incoming bookings';
    return AppScaffold(
      padded: false,
      appBar: AppBar(
        // Only show the back arrow when there's actually somewhere to
        // pop to — when the operator lands on the inbox via the bottom
        // nav (`context.go`) the stack is empty and a back arrow would
        // be confusing.
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(PhosphorIconsBold.arrowLeft),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(title),
      ),
      bottomBar: const BanquetBottomNav(active: BanquetNavTab.bookings),
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
          // Shimmer card list while the first fetch is in flight — the
          // page reveals its real shape immediately instead of jumping
          // in once the data arrives.
          loading: () => ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              AppSizes.md,
              AppSizes.pagePadding,
              AppSizes.xl,
            ),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: AppSizes.md),
            itemBuilder: (_, __) => const ShimmerBookingCard(),
          ),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: AppSizes.xxxl),
              Center(
                child: Text(
                  'Could not load inbox: $e',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
          data: (all) {
            final filtered = all
                .where(_matchesFilter)
                .where(_matchesQuery)
                .toList(growable: false);
            return Column(
              children: [
                _InboxToolbar(
                  events: all,
                  selected: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                  filteredCount: filtered.length,
                  searchCtrl: _searchCtrl,
                  hasQuery: _query.isNotEmpty,
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? _InboxEmptyState(
                          filter: _filter,
                          query: _query,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.pagePadding,
                            AppSizes.md,
                            AppSizes.pagePadding,
                            AppSizes.xl,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSizes.md),
                          itemBuilder: (_, i) =>
                              _InboxCard(event: filtered[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── Toolbar (count + chips) ─────────────────────────

class _InboxToolbar extends StatelessWidget {
  const _InboxToolbar({
    required this.events,
    required this.selected,
    required this.onChanged,
    required this.filteredCount,
    required this.searchCtrl,
    required this.hasQuery,
  });

  final List<BanquetInboxEvent> events;
  final _InboxFilter selected;
  final ValueChanged<_InboxFilter> onChanged;
  final int filteredCount;
  final TextEditingController searchCtrl;
  final bool hasQuery;

  int _countFor(_InboxFilter f) => switch (f) {
        _InboxFilter.all => events.length,
        _InboxFilter.pending =>
          events.where((e) => e.status == BanquetEventStatus.pending).length,
        _InboxFilter.accepted =>
          events.where((e) => e.status == BanquetEventStatus.accepted).length,
        _InboxFilter.declined =>
          events.where((e) => e.status == BanquetEventStatus.declined).length,
      };

  @override
  Widget build(BuildContext context) {
    final headline = filteredCount == 0
        ? (hasQuery ? 'No matches' : 'Nothing to show')
        : '$filteredCount ${selected.label.toLowerCase()} '
            '${filteredCount == 1 ? 'booking' : 'bookings'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.6),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search field ──
          TextField(
            controller: searchCtrl,
            textInputAction: TextInputAction.search,
            style: AppTextStyles.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by name, phone, email or ID',
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                PhosphorIconsBold.magnifyingGlass,
                size: 18,
                color: AppColors.textMuted,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(
                        PhosphorIconsBold.x,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => searchCtrl.clear(),
                      splashRadius: 18,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            headline,
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _InboxFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f = _InboxFilter.values[i];
                return _FilterChip(
                  label: f.label,
                  count: _countFor(f),
                  selected: f == selected,
                  onTap: () => onChanged(f),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          border: Border.all(
            color: selected ? AppColors.textPrimary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppColors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.captionBold.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Empty state ─────────────────────────

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState({required this.filter, required this.query});
  final _InboxFilter filter;
  final String query;

  @override
  Widget build(BuildContext context) {
    // When a search query is active, the "no results" message has to
    // explain what's filtered out instead of describing the filter
    // bucket's natural empty state.
    final (title, sub) = query.isNotEmpty
        ? (
            'No matches for "$query"',
            'Try a different name, phone, email or booking ID — or clear the search to see all bookings.',
          )
        : switch (filter) {
            _InboxFilter.pending => (
                'No bookings awaiting review',
                'New event requests routed to your venues will appear here in real time.',
              ),
            _InboxFilter.accepted => (
                'No accepted events yet',
                'Accept an incoming booking first, then return here to staff a manager.',
              ),
            _InboxFilter.declined => (
                'No declined bookings',
                'Bookings you decline will be archived under this view.',
              ),
            _InboxFilter.all => (
                'No incoming bookings',
                'New event requests routed to your venues will appear here in real time.',
              ),
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsDuotone.calendarBlank,
                size: 40,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(title, style: AppTextStyles.heading3),
            const SizedBox(height: AppSizes.xs),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
          ],
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
          // Customer first — operator's primary "which booking is this?"
          // signal. Falls back to phone / email / short id when name
          // isn't available.
          Row(
            children: [
              Expanded(
                child: CustomerLine(
                  bookingId: event.id,
                  name: event.customerName,
                  phone: event.customerPhone,
                  email: event.customerEmail,
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
          const SizedBox(height: 6),
          Text(
            Formatters.date(event.eventDate),
            style: AppTextStyles.heading2,
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

