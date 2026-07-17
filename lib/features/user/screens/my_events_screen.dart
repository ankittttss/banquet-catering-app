import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/order_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/user_bottom_nav.dart';

enum _Filter { all, active, delivered, cancelled }

/// One booking with all the per-restaurant orders that belong to it.
/// Multiple restaurants per event happen when guests want, say, biryani
/// from one vendor + desserts from another — Dawat splits them into
/// separate orders, but the customer thinks of them as one event.
class _EventGroup {
  _EventGroup({
    required this.eventId,
    required this.orders,
    required this.eventName,
    required this.eventDate,
    required this.location,
    required this.guestCount,
    required this.totalAmount,
    required this.rolledUpStatus,
    required this.createdAt,
  });

  final String eventId;
  final List<OrderSummary> orders;
  final String? eventName;
  final DateTime? eventDate;
  final String? location;
  final int? guestCount;
  final double totalAmount;
  final OrderStatus rolledUpStatus;
  final DateTime createdAt;

  bool get isMultiVendor => orders.length > 1;
  bool get isPast =>
      rolledUpStatus == OrderStatus.delivered ||
      rolledUpStatus == OrderStatus.cancelled;
}

class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(myOrdersStreamProvider);

    return AppScaffold(
      padded: false,
      backgroundColor: AppColors.surfaceAlt,
      bottomBar: const UserBottomNav(active: UserNavTab.orders),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load orders',
          message: '$e',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(myOrdersStreamProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return _Empty(
              onStart: () => context.push(AppRoutes.eventDetails),
            );
          }
          final groups = _groupByEvent(list);
          final counts = _eventCounts(groups);
          final filtered = _filteredGroups(groups, _filter);
          final stats = _spendStats(groups);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(total: groups.length),
              _Filters(
                filter: _filter,
                counts: counts,
                onChanged: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(myOrdersStreamProvider),
                  child: _EventGroupsList(
                    groups: filtered,
                    header: _SpendSummaryCard(
                      spend: stats.spend,
                      eventsDone: stats.events,
                      guestsFed: stats.guests,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_EventGroup> _groupByEvent(List<OrderSummary> list) {
    final byEvent = <String, List<OrderSummary>>{};
    for (final o in list) {
      byEvent.putIfAbsent(o.eventId, () => []).add(o);
    }
    final out = <_EventGroup>[];
    byEvent.forEach((eventId, orders) {
      orders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final total = orders.fold<double>(0, (s, o) => s + o.total);
      final earliest = orders
          .map((o) => o.createdAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final first = orders.first;
      out.add(_EventGroup(
        eventId: eventId,
        orders: orders,
        eventName: first.eventName,
        eventDate: first.eventDate,
        location: first.location,
        guestCount: first.guestCount,
        totalAmount: total,
        rolledUpStatus: _rollupStatus(orders),
        createdAt: earliest,
      ));
    });
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// Most-active wins. If every order is terminal, "delivered" beats
  /// "cancelled" so a partially-fulfilled event isn't marked cancelled.
  OrderStatus _rollupStatus(List<OrderSummary> orders) {
    bool any(OrderStatus s) => orders.any((o) => o.orderStatus == s);
    if (any(OrderStatus.dispatched)) return OrderStatus.dispatched;
    if (any(OrderStatus.preparing)) return OrderStatus.preparing;
    if (any(OrderStatus.confirmed)) return OrderStatus.confirmed;
    if (any(OrderStatus.placed)) return OrderStatus.placed;
    if (orders.every((o) => o.orderStatus == OrderStatus.cancelled)) {
      return OrderStatus.cancelled;
    }
    return OrderStatus.delivered;
  }

  Map<_Filter, int> _eventCounts(List<_EventGroup> groups) {
    int active = 0, delivered = 0, cancelled = 0;
    for (final g in groups) {
      switch (g.rolledUpStatus) {
        case OrderStatus.delivered:
          delivered++;
        case OrderStatus.cancelled:
          cancelled++;
        case OrderStatus.placed:
        case OrderStatus.confirmed:
        case OrderStatus.preparing:
        case OrderStatus.dispatched:
          active++;
      }
    }
    return {
      _Filter.all: groups.length,
      _Filter.active: active,
      _Filter.delivered: delivered,
      _Filter.cancelled: cancelled,
    };
  }

  List<_EventGroup> _filteredGroups(List<_EventGroup> groups, _Filter f) {
    return switch (f) {
      _Filter.all => groups,
      _Filter.delivered =>
        groups.where((g) => g.rolledUpStatus == OrderStatus.delivered).toList(),
      _Filter.cancelled =>
        groups.where((g) => g.rolledUpStatus == OrderStatus.cancelled).toList(),
      _Filter.active => groups
          .where((g) =>
              g.rolledUpStatus != OrderStatus.delivered &&
              g.rolledUpStatus != OrderStatus.cancelled)
          .toList(),
    };
  }

  /// Lifetime totals for the spend hero card. Cancelled events don't count
  /// toward spend or guests fed; "events done" counts delivered events.
  ({double spend, int events, int guests}) _spendStats(
    List<_EventGroup> groups,
  ) {
    var spend = 0.0;
    var events = 0;
    var guests = 0;
    for (final g in groups) {
      if (g.rolledUpStatus != OrderStatus.cancelled) {
        spend += g.totalAmount;
        guests += g.guestCount ?? 0;
      }
      if (g.rolledUpStatus == OrderStatus.delivered) events++;
    }
    return (spend: spend, events: events, guests: guests);
  }
}

// ───────────────────────── Status + event-type helpers ─────────────────────

/// (background, foreground, label, leading-glyph) for an order-status badge,
/// styled after the prototype's StatusBadge: soft tint background, strong
/// tint foreground, uppercase label. Glyph is ● for in-progress statuses,
/// ✓ for delivered, ✕ for cancelled.
(Color, Color, String, String) _statusView(OrderStatus s) => switch (s) {
      OrderStatus.placed => (
          AppColors.catGoldLt,
          AppColors.accentDark,
          'Placed',
          '●',
        ),
      OrderStatus.confirmed => (
          AppColors.catGreenLt,
          AppColors.catGreen,
          'Confirmed',
          '●',
        ),
      OrderStatus.preparing => (
          AppColors.catBlueLt,
          AppColors.catBlue,
          'Preparing',
          '●',
        ),
      OrderStatus.dispatched => (
          AppColors.catBlueLt,
          AppColors.catBlue,
          'On the way',
          '●',
        ),
      OrderStatus.delivered => (
          AppColors.divider,
          AppColors.textSecondary,
          'Delivered',
          '✓',
        ),
      OrderStatus.cancelled => (
          AppColors.catRedLt,
          AppColors.error,
          'Cancelled',
          '✕',
        ),
    };

/// (background, foreground, emoji, label) for the event-type chip, inferred
/// from guest count as a lightweight stand-in until events carry a type.
(Color, Color, String, String) _eventMeta(int guests) {
  if (guests >= 60) {
    return (AppColors.catPurpleLt, AppColors.catPurple, '💒', 'Wedding');
  }
  if (guests >= 30) {
    return (AppColors.catBlueLt, AppColors.catBlue, '🏢', 'Corporate event');
  }
  if (guests >= 10) {
    return (AppColors.catGoldLt, AppColors.catGold, '🏠', 'House party');
  }
  if (guests > 0) {
    return (AppColors.primarySoft, AppColors.primary, '🎂', 'Birthday');
  }
  return (AppColors.accentSoft, AppColors.accentDark, '🎉', 'Event');
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My orders', style: AppTextStyles.display),
          const SizedBox(height: 2),
          Text(
            total == 1 ? '1 event' : '$total events',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Filters ─────────────────────────

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });
  final _Filter filter;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
          children: [
            _chip(_Filter.all, 'All'),
            _chip(_Filter.active, 'Active'),
            _chip(_Filter.delivered, 'Delivered'),
            _chip(_Filter.cancelled, 'Cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _chip(_Filter f, String label) {
    final on = filter == f;
    final count = counts[f] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sm),
      child: Material(
        color: on ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          side: BorderSide(color: on ? AppColors.primary : AppColors.border),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(f);
          },
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: on ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: on
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Event groups list ─────────────────────────

class _EventGroupsList extends StatelessWidget {
  const _EventGroupsList({
    required this.groups,
    required this.header,
  });
  final List<_EventGroup> groups;

  /// Widget pinned to the top of the scrollable list (the spend summary card).
  final Widget header;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          header,
          const SizedBox(height: 120),
          Center(
            child: Text(
              'No events match this filter',
              style: AppTextStyles.bodyMuted,
            ),
          ),
        ],
      );
    }

    final children = <Widget>[header];
    for (var i = 0; i < groups.length; i++) {
      children.add(
        _EventGroupCard(group: groups[i])
            .animate()
            .fadeIn(duration: 240.ms, delay: (30 * i).ms),
      );
    }
    children.add(const SizedBox(height: 20));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: AppSizes.xs, bottom: AppSizes.md),
      children: children,
    );
  }
}

// ───────────────────────── Event group card ─────────────────────────

class _EventGroupCard extends ConsumerWidget {
  const _EventGroupCard({required this.group});
  final _EventGroup group;

  /// The order a card tap / "Track" opens — the most-active one for a
  /// multi-vendor event, else the only order.
  OrderSummary get _primaryOrder {
    for (final wanted in const [
      OrderStatus.dispatched,
      OrderStatus.preparing,
      OrderStatus.confirmed,
      OrderStatus.placed,
    ]) {
      for (final o in group.orders) {
        if (o.orderStatus == wanted) return o;
      }
    }
    return group.orders.first;
  }

  /// Rebuild the cart from this event's order and land on the cart screen.
  /// Only dishes that are still orderable come back (at CURRENT prices);
  /// anything gone is reported. Previously "Reorder" just opened home.
  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    try {
      final lines = await ref
          .read(orderRepositoryProvider)
          .fetchReorderLines(_primaryOrder.id);
      if (!context.mounted) return;
      if (lines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'None of the dishes from this order are available anymore.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final cart = ref.read(cartProvider.notifier);
      cart.clear();
      for (final line in lines) {
        cart.add(
          line.item,
          customization: CartCustomization(
            portion: line.portion,
            spice: line.spice,
            notes: line.notes,
          ),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${lines.length} dish${lines.length == 1 ? '' : 'es'} added back '
            'to your cart at current prices.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.push(AppRoutes.cart);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not reorder: ${e.toString().split('\n').first}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = group.rolledUpStatus;
    final cancelled = s == OrderStatus.cancelled;
    final reorderable = s == OrderStatus.delivered || cancelled;
    final (evBg, _, emoji, typeLabel) = _eventMeta(group.guestCount ?? 0);
    // Prefer the customer's chosen event name; fall back to the inferred type
    // label (e.g. "Wedding") for legacy orders placed before names existed.
    final name = group.eventName?.trim();
    final title = (name != null && name.isNotEmpty) ? name : typeLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.xs,
        AppSizes.md,
        AppSizes.sm,
      ),
      child: Opacity(
        opacity: cancelled ? 0.85 : 1,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Tappable body: thumbnail + title/status + date + meta ----
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push(AppRoutes.orderDetailFor(_primaryOrder.id));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail — event-type emoji on a tinted tile
                        // (the data model carries no cover photos).
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: evBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.heading2.copyWith(
                                        color: cancelled
                                            ? AppColors.textMuted
                                            : AppColors.textPrimary,
                                        decoration: cancelled
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.sm),
                                  _StatusBadge(status: s),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.date(
                                  group.eventDate ?? group.createdAt,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 8),
                              _metaRow(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ---- Footer: id · total · actions (perforated receipt) ----
              const _DashedLine(),
              Container(
                color: AppColors.surfaceAlt,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _idLabel(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '·',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              Formatters.currency(group.totalAmount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyBold.copyWith(
                                color: cancelled
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    if (reorderable)
                      _FooterButton(
                        label: 'Reorder',
                        icon: Icons.add_rounded,
                        filled: true,
                        onTap: () => _reorder(context, ref),
                      )
                    else
                      _FooterButton(
                        label: 'Track',
                        filled: false,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context
                              .push(AppRoutes.orderDetailFor(_primaryOrder.id));
                        },
                      ),
                    const SizedBox(width: 6),
                    // "Invoice" removed — there is no invoice backend yet and
                    // the button only showed a "coming soon" snackbar.
                    _FooterButton(
                      label: 'Details',
                      icon: Icons.receipt_long_rounded,
                      filled: false,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context
                            .push(AppRoutes.orderDetailFor(_primaryOrder.id));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow() {
    final bits = <Widget>[];
    final guests = group.guestCount ?? 0;
    if (guests > 0) {
      bits.add(_metaBit(Icons.groups_outlined, '$guests'));
    }
    final loc = group.location?.trim();
    if (loc != null && loc.isNotEmpty) {
      bits.add(Flexible(child: _metaBit(Icons.place_outlined, loc)));
    }
    if (bits.isEmpty) {
      final n = group.orders.length;
      bits.add(
        _metaBit(
          Icons.receipt_long_outlined,
          n == 1 ? '1 order' : '$n orders',
        ),
      );
    }
    final spaced = <Widget>[];
    for (var i = 0; i < bits.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: AppSizes.md));
      spaced.add(bits[i]);
    }
    return Row(children: spaced);
  }

  Widget _metaBit(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  String _idLabel() {
    final id = group.eventId.length >= 6
        ? group.eventId.substring(0, 6).toUpperCase()
        : group.eventId.toUpperCase();
    return '#EVT-$id';
  }
}

// ───────────────────────── Status badge ─────────────────────────

/// Pill badge for an order's rolled-up status, matching the prototype's
/// StatusBadge (soft tint bg, strong tint fg, uppercase, leading glyph).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, glyph) = _statusView(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(glyph, style: TextStyle(fontSize: 8, color: fg, height: 1)),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.captionBold.copyWith(
              fontSize: 10,
              color: fg,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Footer button ─────────────────────────

/// Compact receipt-footer action. [filled] renders the solid primary CTA
/// (Reorder); otherwise a white outline button (Track / Invoice).
class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.textSecondary;
    return Material(
      color: filled ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            border: filled ? null : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTextStyles.captionBold.copyWith(
                  fontSize: 11,
                  color: fg,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Spend summary card ─────────────────────────

/// Dark gradient "lifetime spend" hero, ported from the prototype's orders
/// screen. Sits at the top of the scrollable list so it slides away as the
/// host scrolls their bookings. Cancelled events are excluded from the totals.
class _SpendSummaryCard extends StatelessWidget {
  const _SpendSummaryCard({
    required this.spend,
    required this.eventsDone,
    required this.guestsFed,
  });
  final double spend;
  final int eventsDone;
  final int guestsFed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
        AppSizes.xs,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C1C1C), Color(0xFF333333)],
            ),
          ),
          child: Stack(
            children: [
              // Soft gold blob bleeding off the top-right corner.
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LIFETIME SPEND',
                      style: AppTextStyles.captionBold.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.currency(spend),
                      style:
                          AppTextStyles.display.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SpendStat(value: '$eventsDone', label: 'Events done'),
                        const SizedBox(width: 22),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(width: 22),
                        _SpendStat(value: '$guestsFed', label: 'Guests fed'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendStat extends StatelessWidget {
  const _SpendStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.heading2.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Dashed divider ─────────────────────────

/// A horizontal dashed rule for the receipt-style card footer.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 1,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashGap = 4.0;
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + dashWidth, 0.5), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}

// ───────────────────────── Empty state ─────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: AppSizes.md),
            Text('No orders yet', style: AppTextStyles.heading1),
            const SizedBox(height: 6),
            Text(
              'Your bookings will show up here.\nStart planning your first event.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: Text(
                'Start a new event',
                style: AppTextStyles.buttonLabel.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
