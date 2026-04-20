import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/order_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/user_bottom_nav.dart';

// ───────────────────────── Palette (matches HTML mock) ─────────────────────────

class _P {
  static const Color red   = Color(0xFFE23744);
  static const Color redLt = Color(0xFFFFF1F2);
  static const Color grn   = Color(0xFF1BA672);
  static const Color grnLt = Color(0xFFEAFAF1);
  static const Color blu   = Color(0xFF2B6CB0);
  static const Color bluLt = Color(0xFFEBF4FF);
  static const Color gld   = Color(0xFFC4922A);
  static const Color gldLt = Color(0xFFFFF8E7);
  static const Color pur   = Color(0xFF7C3AED);
  static const Color purLt = Color(0xFFF3E8FF);
  static const Color org   = Color(0xFFE97A2B);
  static const Color orgLt = Color(0xFFFFF4EB);
  static const Color blk   = Color(0xFF1A1A1A);
  static const Color g70   = Color(0xFF4F4F4F);
  static const Color g50   = Color(0xFF828282);
  static const Color g30   = Color(0xFFBDBDBD);
  static const Color g15   = Color(0xFFE0E0E0);
  static const Color g8    = Color(0xFFF2F2F2);
  static const Color w     = Color(0xFFFFFFFF);
  static const Color bg    = Color(0xFFF7F4F0);
}

enum _Filter { all, active, delivered, cancelled }

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
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];

    return AppScaffold(
      padded: false,
      backgroundColor: _P.bg,
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
          final counts = _countBy(list);
          final filtered = _filteredOrders(list, _filter);
          return Column(
            children: [
              _Header(total: list.length),
              _Filters(
                filter: _filter,
                counts: counts,
                onChanged: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _P.red,
                  onRefresh: () async =>
                      ref.invalidate(myOrdersStreamProvider),
                  child: _OrdersList(
                    orders: filtered,
                    restaurants: restaurants,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<_Filter, int> _countBy(List<OrderSummary> list) {
    int active = 0, delivered = 0, cancelled = 0;
    for (final o in list) {
      switch (o.orderStatus) {
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
      _Filter.all: list.length,
      _Filter.active: active,
      _Filter.delivered: delivered,
      _Filter.cancelled: cancelled,
    };
  }

  List<OrderSummary> _filteredOrders(List<OrderSummary> list, _Filter f) {
    return switch (f) {
      _Filter.all => list,
      _Filter.delivered =>
        list.where((o) => o.orderStatus == OrderStatus.delivered).toList(),
      _Filter.cancelled =>
        list.where((o) => o.orderStatus == OrderStatus.cancelled).toList(),
      _Filter.active => list
          .where((o) =>
              o.orderStatus != OrderStatus.delivered &&
              o.orderStatus != OrderStatus.cancelled)
          .toList(),
    };
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _P.w,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My orders',
            style: GoogleFonts.instrumentSerif(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: _P.blk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            total == 1 ? '1 order this month' : '$total orders this month',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: _P.g50,
            ),
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
      color: _P.w,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: on ? _P.blk : _P.w,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: on ? _P.blk : _P.g15, width: 1.5),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(f);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: on ? _P.w : _P.g50,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: on ? _P.w.withValues(alpha: 0.2) : _P.g8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: on ? _P.w : _P.g70,
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

// ───────────────────────── Orders list ─────────────────────────

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders, required this.restaurants});
  final List<OrderSummary> orders;
  final List<Restaurant> restaurants;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              'No orders match this filter',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: _P.g50,
              ),
            ),
          ),
        ],
      );
    }

    // Group by date bucket (Today / Yesterday / formatted date).
    final grouped = <String, List<OrderSummary>>{};
    for (final o in orders) {
      final bucket = _bucket(o.createdAt);
      grouped.putIfAbsent(bucket, () => []).add(o);
    }

    final children = <Widget>[];
    var cardIndex = 0;
    grouped.forEach((bucket, list) {
      children.add(_DateDivider(label: bucket));
      for (final o in list) {
        final r = _restaurantFor(o);
        children.add(
          _OrderCard(order: o, restaurant: r)
              .animate()
              .fadeIn(duration: 240.ms, delay: (30 * cardIndex).ms),
        );
        cardIndex++;
      }
    });
    children.add(const SizedBox(height: 20));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      children: children,
    );
  }

  Restaurant? _restaurantFor(OrderSummary o) {
    if (o.restaurantId == null) return null;
    for (final r in restaurants) {
      if (r.id == o.restaurantId) return r;
    }
    return null;
  }

  String _bucket(DateTime d) {
    final now = DateTime.now();
    final dOnly = DateTime(d.year, d.month, d.day);
    final nOnly = DateTime(now.year, now.month, now.day);
    final diff = nOnly.difference(dOnly).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return Formatters.date(d);
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _P.g50,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(color: _P.g15, height: 1, thickness: 1),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Order card ─────────────────────────

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.restaurant});
  final OrderSummary order;
  final Restaurant? restaurant;

  @override
  Widget build(BuildContext context) {
    final s = order.orderStatus;
    final isPast = s == OrderStatus.delivered || s == OrderStatus.cancelled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Material(
        color: _P.w,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(AppRoutes.orderDetailFor(order.id));
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _accentStrip(s, dim: isPast),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Opacity(
                    opacity: isPast ? 0.82 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _top(s),
                        const SizedBox(height: 10),
                        _eventBadge(),
                        if (_itemsPreview().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _itemsPreview(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _P.g50,
                              height: 1.6,
                            ),
                          ),
                        ],
                        if (!isPast) ...[
                          const SizedBox(height: 12),
                          _miniProgress(s),
                        ],
                      ],
                    ),
                  ),
                ),
                _footer(context, s, isPast),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------- accent strip -------
  Widget _accentStrip(OrderStatus s, {required bool dim}) {
    final gradient = switch (s) {
      OrderStatus.placed =>
        const LinearGradient(colors: [_P.gld, _P.org]),
      OrderStatus.confirmed =>
        const LinearGradient(colors: [_P.blu, Color(0xFF5B9BD5)]),
      OrderStatus.preparing =>
        const LinearGradient(colors: [_P.org, Color(0xFFF5A623)]),
      OrderStatus.dispatched =>
        const LinearGradient(colors: [_P.blu, _P.grn]),
      OrderStatus.delivered =>
        const LinearGradient(colors: [_P.grn, Color(0xFF2DC98A)]),
      OrderStatus.cancelled =>
        const LinearGradient(colors: [_P.red, Color(0xFFF07070)]),
    };
    return Opacity(
      opacity: dim ? 0.5 : 1.0,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }

  // ------- top row -------
  Widget _top(OrderStatus s) {
    final (iconBg, emoji) = _restaurantIcon();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restaurant?.name ?? 'Dawat Order',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _P.blk,
                ),
              ),
              const SizedBox(height: 1),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '#DWT-${order.id.substring(0, 6).toUpperCase()} · ',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _P.g50,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: _clock(order.createdAt),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: _P.g30,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _statusBadge(s),
      ],
    );
  }

  (Color, String) _restaurantIcon() {
    final emoji = restaurant?.heroEmoji ?? '🍽️';
    // Pick a muted pastel background by order status for variety.
    final bg = switch (order.orderStatus) {
      OrderStatus.placed => _P.gldLt,
      OrderStatus.confirmed => _P.purLt,
      OrderStatus.preparing => _P.grnLt,
      OrderStatus.dispatched => _P.bluLt,
      OrderStatus.delivered => _P.bluLt,
      OrderStatus.cancelled => _P.redLt,
    };
    return (bg, emoji);
  }

  // ------- status badge -------
  Widget _statusBadge(OrderStatus s) {
    final (bg, fg, pulsing) = switch (s) {
      OrderStatus.placed => (_P.gldLt, _P.gld, false),
      OrderStatus.confirmed => (_P.bluLt, _P.blu, false),
      OrderStatus.preparing => (_P.orgLt, _P.org, true),
      OrderStatus.dispatched => (_P.bluLt, _P.blu, true),
      OrderStatus.delivered => (_P.grnLt, _P.grn, false),
      OrderStatus.cancelled => (_P.redLt, _P.red, false),
    };
    final label = switch (s) {
      OrderStatus.placed => 'Placed',
      OrderStatus.confirmed => 'Confirmed',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.dispatched => 'In Transit',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };

    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
    );
    if (pulsing) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 800.ms)
          .scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1.1, 1.1),
              duration: 800.ms);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ------- event badge -------
  Widget _eventBadge() {
    final (bg, fg, icon, label) = _eventMeta();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(
          '$icon $label',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  (Color, Color, String, String) _eventMeta() {
    final guests = order.guestCount ?? 0;
    final location = order.location ?? 'Event';
    if (guests >= 60) return (_P.purLt, _P.pur, '💒', 'Wedding · $guests guests');
    if (guests >= 30) return (_P.bluLt, _P.blu, '🏢', 'Corporate · $guests guests');
    if (guests >= 10) return (_P.gldLt, _P.gld, '🏠', 'House Party · $guests guests');
    if (guests > 0)   return (_P.redLt, _P.red, '🎂', 'Birthday · $guests guests');
    return (_P.orgLt, _P.org, '🎉', location);
  }

  // ------- items preview -------
  String _itemsPreview() {
    final loc = order.location?.trim();
    if (loc == null || loc.isEmpty) return '';
    if (order.eventDate != null) {
      return 'Serving at $loc · ${Formatters.date(order.eventDate!)}';
    }
    return 'Serving at $loc';
  }

  // ------- mini progress tracker -------
  Widget _miniProgress(OrderStatus s) {
    final active = s.stepIndex;
    return Row(
      children: List.generate(5, (i) {
        final isDone = i < active;
        final isActive = i == active;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == 4 ? 0 : 3),
            height: 3,
            decoration: BoxDecoration(
              color: isDone
                  ? _P.grn
                  : isActive
                      ? _P.org
                      : _P.g8,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // ------- footer -------
  Widget _footer(BuildContext context, OrderStatus s, bool isPast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 10),
            color: _P.g8,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.currency(order.total),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: s == OrderStatus.cancelled ? _P.g30 : _P.blk,
                        decoration: s == OrderStatus.cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _footerSub(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: s == OrderStatus.cancelled ? _P.red : _P.g50,
                      ),
                    ),
                  ],
                ),
              ),
              _actionButtons(context, s),
            ],
          ),
        ],
      ),
    );
  }

  String _footerSub(OrderStatus s) {
    return switch (s) {
      OrderStatus.placed => 'Waiting for restaurant',
      OrderStatus.confirmed => 'Restaurant confirmed · Preparing soon',
      OrderStatus.preparing => 'Food being prepared',
      OrderStatus.dispatched => 'On the way to your location',
      OrderStatus.delivered => order.deliveredAt != null
          ? 'Delivered at ${_clock(order.deliveredAt!)}'
          : 'Delivered',
      OrderStatus.cancelled => 'Refund credited to wallet',
    };
  }

  Widget _actionButtons(BuildContext context, OrderStatus s) {
    switch (s) {
      case OrderStatus.delivered:
        return _btn(
          label: 'Reorder',
          bg: _P.grnLt,
          fg: _P.grn,
          icon: Icons.refresh_rounded,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(AppRoutes.userHome);
          },
        );
      case OrderStatus.cancelled:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(
              label: 'Details',
              bg: _P.g8,
              fg: _P.g70,
              icon: Icons.info_outline_rounded,
              onTap: () =>
                  context.push(AppRoutes.orderDetailFor(order.id)),
            ),
            const SizedBox(width: 6),
            _btn(
              label: 'Reorder',
              bg: _P.grnLt,
              fg: _P.grn,
              icon: Icons.refresh_rounded,
              onTap: () => context.push(AppRoutes.userHome),
            ),
          ],
        );
      case OrderStatus.placed:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
      case OrderStatus.dispatched:
        return _btn(
          label: 'Track',
          bg: _P.red,
          fg: _P.w,
          icon: Icons.location_on_rounded,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(AppRoutes.orderDetailFor(order.id));
          },
        );
    }
  }

  Widget _btn({
    required String label,
    required Color bg,
    required Color fg,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------- helpers -------
  String _clock(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
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
            const SizedBox(height: 16),
            Text(
              'No orders yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _P.blk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your bookings will show up here.\nStart planning your first event.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: _P.g50,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: _P.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start a new event',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _P.w,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
