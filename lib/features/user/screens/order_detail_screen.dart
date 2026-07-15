import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/manager_event_detail.dart';
import '../../../data/models/order.dart';
import '../../../data/models/order_vendor_lot.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/order_providers.dart';
import '../../../shared/providers/review_providers.dart';
import '../widgets/rate_order_sheet.dart';

// ───────────────────────── Palette (Dawat tracking) ─────────────────────────

class _TP {
  static const Color red = Color(0xFFE23744);
  static const Color gold = Color(0xFFC4922A);
  static const Color goldLight = Color(0xFFFFF8E7);
  static const Color green = Color(0xFF1BA672);
  static const Color greenLight = Color(0xFFEAFAF1);

  static const Color black = Color(0xFF1A1A1A);
  static const Color g80 = Color(0xFF3D3530);
  static const Color g60 = Color(0xFF6B5D4F);
  static const Color g40 = Color(0xFF8C8078);
  static const Color g25 = Color(0xFFB0A89E);
  static const Color g15 = Color(0xFFD8D0C8);
  static const Color g8 = Color(0xFFEAE4DE);
  static const Color g4 = Color(0xFFF5F0EB);
  static const Color cream = Color(0xFFFDFBF9);
}

// ───────────────────────── Screen ─────────────────────────

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));
    final asyncState = ref.watch(myOrdersStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: '$e'),
        data: (_) {
          if (order == null) return const _NotFoundView();
          return _Tracker(order: order);
        },
      ),
    );
  }
}

// ───────────────────────── Tracker shell ─────────────────────────

class _Tracker extends StatelessWidget {
  const _Tracker({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _TopBar(order: order),
          Expanded(child: _BottomSheet(order: order)),
        ],
      ),
    );
  }
}

// ───────────────────────── Top bar ─────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final shortId = order.id.length > 6
        ? order.id.substring(0, 6).toUpperCase()
        : order.id.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _TP.g80),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.myEvents),
          ),
          const Expanded(
            child: Text(
              'Order details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _TP.black,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _TP.g4,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#DWT-$shortId',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _TP.g40,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Order body ─────────────────────────

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _StatusHeader(order: order),
        _ProgressBar(order: order),
        _Timeline(order: order),
        if (order.orderStatus == OrderStatus.delivered &&
            order.restaurantId != null)
          _RateOrderCard(order: order),
        const _SheetDivider(),
        if (order.eventDate != null) _EventBadge(order: order),
        _OrderSummaryBlock(order: order),
        _HelpBar(order: order),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      color: _TP.g4,
      margin: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}

// ───────────────────────── Status header ─────────────────────────

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final title = switch (order.orderStatus) {
      OrderStatus.placed => 'Order placed!',
      OrderStatus.confirmed => 'Confirmed!',
      OrderStatus.preparing => 'Being prepared',
      OrderStatus.dispatched => 'On its way!',
      OrderStatus.delivered => 'Delivered 🎉',
      OrderStatus.cancelled => 'Cancelled',
    };

    final subtitle = switch (order.orderStatus) {
      OrderStatus.placed => 'We\'ve received your order',
      OrderStatus.confirmed => 'Your booking is confirmed',
      OrderStatus.preparing => 'Your order is being prepared',
      OrderStatus.dispatched => 'On its way to your event',
      OrderStatus.delivered => 'Thanks for ordering with Dawat',
      OrderStatus.cancelled => 'This order was cancelled',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.instrumentSerif(
              fontSize: 26,
              fontWeight: FontWeight.w400,
              color: _TP.black,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: _TP.g40,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Progress bar ─────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final s = order.orderStatus;
    final pct = switch (s) {
      OrderStatus.placed => 0.12,
      OrderStatus.confirmed => 0.30,
      OrderStatus.preparing => 0.50,
      OrderStatus.dispatched => 0.75,
      OrderStatus.delivered => 1.0,
      OrderStatus.cancelled => 0.0,
    };
    final barColor = s == OrderStatus.cancelled ? _TP.red : _TP.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, c) {
          final fillW = c.maxWidth * pct;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: _TP.g8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                width: fillW,
                height: 4,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (pct > 0 && pct < 1)
                Positioned(
                  left: fillW - 4,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: barColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── Timeline ─────────────────────────

enum _TlState { done, active, pending }

class _TimelineStep {
  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.state,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final _TlState state;
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    if (order.orderStatus == OrderStatus.cancelled) {
      return const _CancelledBlock();
    }
    final active = order.orderStatus.stepIndex;
    final steps = <_TimelineStep>[
      _TimelineStep(
        icon: Icons.check_rounded,
        title: 'Order placed',
        subtitle: 'Your order has been confirmed',
        time: _time(order.placedAt ?? order.createdAt),
        state: _stateFor(0, active),
      ),
      _TimelineStep(
        icon: Icons.check_rounded,
        title: 'Booking confirmed',
        subtitle: 'Your kitchen has accepted the order',
        time: _time(order.confirmedAt),
        state: _stateFor(1, active),
      ),
      _TimelineStep(
        icon: Icons.restaurant_rounded,
        title: 'Being prepared',
        subtitle: 'Your order is being prepared for the event',
        time: _time(order.preparingAt),
        state: _stateFor(2, active),
      ),
      _TimelineStep(
        icon: Icons.local_shipping_rounded,
        title: 'On its way',
        subtitle: 'Your order is on its way to the event',
        time: _time(order.dispatchedAt),
        state: _stateFor(3, active),
      ),
      _TimelineStep(
        icon: Icons.celebration_rounded,
        title: 'Delivered',
        subtitle: order.deliveredAt != null
            ? 'Enjoy your event!'
            : 'Scheduled for your event day',
        time: _time(order.deliveredAt),
        state: _stateFor(4, active),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: List.generate(steps.length, (i) {
          return _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
          );
        }),
      ),
    );
  }

  _TlState _stateFor(int i, int active) {
    if (i < active) return _TlState.done;
    if (i == active) return _TlState.active;
    return _TlState.pending;
  }

  String _time(DateTime? t) {
    if (t == null) return '—';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});
  final _TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDone = step.state == _TlState.done;
    final isActive = step.state == _TlState.active;
    final isPending = step.state == _TlState.pending;

    final titleColor = isPending ? _TP.g25 : _TP.black;
    final subColor = isPending ? _TP.g15 : _TP.g40;
    final timeColor = isActive
        ? _TP.red
        : isDone
            ? _TP.green
            : _TP.g25;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _TimelineDot(state: step.state, icon: step.icon),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? _TP.green : _TP.g8,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 6 : 22, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: subColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              step.time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: timeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.state, required this.icon});
  final _TlState state;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDone = state == _TlState.done;
    final isActive = state == _TlState.active;

    final bg = isDone
        ? _TP.greenLight
        : isActive
            ? _TP.red
            : _TP.g4;
    final fg = isDone
        ? _TP.green
        : isActive
            ? Colors.white
            : _TP.g25;

    final dot = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: state == _TlState.pending
            ? Border.all(color: _TP.g15, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: fg),
    );

    if (!isActive) return dot;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _TP.red, width: 2),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scale(
              duration: 2000.ms,
              begin: const Offset(0.85, 0.85),
              end: const Offset(1.25, 1.25),
              curve: Curves.easeOut,
            )
            .fadeOut(duration: 2000.ms),
        dot,
      ],
    );
  }
}

class _CancelledBlock extends StatelessWidget {
  const _CancelledBlock();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.primary),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                'This order was cancelled. If this was unexpected, contact support.',
                style: AppTextStyles.body.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Event badge ─────────────────────────

class _EventBadge extends StatelessWidget {
  const _EventBadge({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final guests = order.guestCount ?? 0;
    final eventLabel = guests > 0 ? 'Event — $guests Guests' : 'Event order';
    final when =
        order.eventDate == null ? '' : _eventDateLine(order.eventDate!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _TP.goldLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _TP.gold.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eventLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _TP.g80,
                    ),
                  ),
                  if (when.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      when,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _TP.gold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _eventDateLine(DateTime d) {
    final wd = _weekdays[d.weekday - 1];
    final m = _months[d.month - 1];
    return '$wd, ${d.day} $m ${d.year}';
  }
}

// ───────────────────────── Order summary block ─────────────────────────

class _OrderSummaryBlock extends ConsumerWidget {
  const _OrderSummaryBlock({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(managerEventDetailProvider(order.eventId));
    final restaurants =
        ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Order summary'),
          const SizedBox(height: 14),
          detailAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) =>
                _FallbackSummary(order: order, restaurants: restaurants),
            data: (detail) => detail == null
                ? _FallbackSummary(order: order, restaurants: restaurants)
                : _DetailedSummary(
                    order: order,
                    detail: detail,
                    restaurants: restaurants,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Renders when we can't load the full event detail (RLS, offline, etc.).
/// Shows a minimal header + total so the screen never goes blank.
class _FallbackSummary extends StatelessWidget {
  const _FallbackSummary({required this.order, required this.restaurants});
  final OrderSummary order;
  final List<Restaurant> restaurants;

  Restaurant? _restaurant() {
    if (order.restaurantId == null) return null;
    for (final r in restaurants) {
      if (r.id == order.restaurantId) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final r = _restaurant();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RestaurantHeader(
          name: r?.name ?? 'Dawat Kitchen',
          emoji: r?.heroEmoji ?? '🍛',
          subtitle: 'Event order',
        ),
        const SizedBox(height: 14),
        const Divider(color: _TP.g8, height: 1),
        const SizedBox(height: 10),
        _BillRow(
            label: 'Total amount', value: Formatters.currency(order.total)),
        _TotalPaidRow(order: order),
      ],
    );
  }
}

class _DetailedSummary extends StatelessWidget {
  const _DetailedSummary({
    required this.order,
    required this.detail,
    required this.restaurants,
  });
  final OrderSummary order;
  final ManagerEventDetail detail;
  final List<Restaurant> restaurants;

  Restaurant? _restaurantById(String id) {
    for (final r in restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Total item count across every kitchen in this booking.
  int _itemCount() {
    var n = 0;
    for (final lot in detail.vendorLots) {
      n += lot.items.length;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final lots = detail.vendorLots;
    final isMulti = lots.length > 1;
    final guests = detail.guestCount ?? 1;

    // Primary header — single kitchen shows its name; multi-vendor shows
    // the event-level summary so neither restaurant gets implicit priority.
    final headerName = isMulti
        ? 'Event order'
        : (lots.isNotEmpty
            ? (lots.first.restaurantName ??
                _restaurantById(lots.first.restaurantId)?.name ??
                'Dawat Kitchen')
            : 'Dawat Kitchen');
    final headerEmoji = isMulti
        ? '🍽️'
        : (lots.isNotEmpty
            ? (_restaurantById(lots.first.restaurantId)?.heroEmoji ?? '🍛')
            : '🍛');
    final itemCount = _itemCount();
    final headerSubtitle = itemCount > 0
        ? (isMulti
            ? '${lots.length} kitchens · $itemCount items'
            : '$itemCount items')
        : 'Event order';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RestaurantHeader(
          name: headerName,
          emoji: headerEmoji,
          subtitle: headerSubtitle,
        ),
        if (lots.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (var i = 0; i < lots.length; i++) ...[
            _VendorLotBlock(
              lot: lots[i],
              restaurant: _restaurantById(lots[i].restaurantId),
              guestCount: guests,
              showHeader: isMulti,
            ),
            if (i < lots.length - 1) const SizedBox(height: 12),
          ],
        ],
        const SizedBox(height: 16),
        _BillDetailsBlock(detail: detail, order: order),
        _TotalPaidRow(order: order),
      ],
    );
  }
}

class _RestaurantHeader extends StatelessWidget {
  const _RestaurantHeader({
    required this.name,
    required this.emoji,
    required this.subtitle,
  });
  final String name;
  final String emoji;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _TP.goldLight,
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
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _TP.black,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: _TP.g40,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VendorLotBlock extends StatelessWidget {
  const _VendorLotBlock({
    required this.lot,
    required this.restaurant,
    required this.guestCount,
    required this.showHeader,
  });
  final OrderVendorLot lot;
  final Restaurant? restaurant;
  final int guestCount;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final name = lot.restaurantName ?? restaurant?.name ?? 'Kitchen';
    final emoji = restaurant?.heroEmoji ?? '🍛';

    return Container(
      decoration: BoxDecoration(
        color: _TP.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _TP.g8, width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _TP.goldLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _TP.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Formatters.currency(lot.subtotal),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _TP.g60,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: _TP.g8, height: 1),
            const SizedBox(height: 4),
          ],
          if (lot.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Item details not available',
                style: TextStyle(
                  fontSize: 12,
                  color: _TP.g40,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            for (final item in lot.items)
              _ItemRow(item: item, guestCount: guestCount),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.guestCount});
  final VendorLotItem item;
  final int guestCount;

  @override
  Widget build(BuildContext context) {
    final per = item.qtyPerGuest;
    final qtyLabel =
        per != null ? '${_fmt(per)} × $guestCount guests' : '${item.qty}';
    final lineTotal = item.lineTotal(guestCount);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VegDot(isVeg: item.isVeg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name ?? 'Item',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _TP.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$qtyLabel · ${Formatters.currency(item.priceAtOrder)} ea',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _TP.g40,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Formatters.currency(lineTotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _TP.black,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _VegDot extends StatelessWidget {
  const _VegDot({required this.isVeg});
  final bool? isVeg;

  @override
  Widget build(BuildContext context) {
    if (isVeg == null) return const SizedBox(width: 12);
    final color = isVeg! ? _TP.green : _TP.red;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BillDetailsBlock extends StatelessWidget {
  const _BillDetailsBlock({required this.detail, required this.order});
  final ManagerEventDetail detail;
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    // food_cost is the canonical "items total" when present; fall back to
    // the sum of vendor-lot subtotals so the customer never sees a blank
    // line on legacy orders.
    final food = detail.foodCost ??
        detail.vendorLots.fold<double>(0, (s, l) => s + l.subtotal);
    final boyCount = detail.serviceBoyCount ?? 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: _TP.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _TP.g8, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Bill details'),
          const SizedBox(height: 8),
          _BillRow(label: 'Item total', value: Formatters.currency(food)),
          if ((detail.banquetCharge ?? 0) > 0)
            _BillRow(
                label: 'Banquet charge',
                value: Formatters.currency(detail.banquetCharge!)),
          if ((detail.deliveryCharge ?? 0) > 0)
            _BillRow(
                label: 'Delivery',
                value: Formatters.currency(detail.deliveryCharge!)),
          if ((detail.buffetSetup ?? 0) > 0)
            _BillRow(
                label: 'Buffet setup',
                value: Formatters.currency(detail.buffetSetup!)),
          if ((detail.serviceBoyCost ?? 0) > 0)
            _BillRow(
                label:
                    boyCount > 1 ? 'Service boys (×$boyCount)' : 'Service boy',
                value: Formatters.currency(detail.serviceBoyCost!)),
          if ((detail.waterBottleCost ?? 0) > 0)
            _BillRow(
                label: 'Water bottles',
                value: Formatters.currency(detail.waterBottleCost!)),
          if ((detail.platformFee ?? 0) > 0)
            _BillRow(
                label: 'Platform fee',
                value: Formatters.currency(detail.platformFee!)),
          if ((detail.gst ?? 0) > 0)
            _BillRow(
                label: 'GST & taxes', value: Formatters.currency(detail.gst!)),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _TP.g60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _TP.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalPaidRow extends StatelessWidget {
  const _TotalPaidRow({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _TP.g15, width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total paid',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _TP.black,
            ),
          ),
          Row(
            children: [
              Text(
                Formatters.currency(order.total),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _TP.black,
                ),
              ),
              const SizedBox(width: 8),
              _PaymentPill(status: order.paymentStatus),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentPill extends StatelessWidget {
  const _PaymentPill({required this.status});
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final paid = status == PaymentStatus.paid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: paid ? _TP.greenLight : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: paid ? _TP.green : AppColors.warning,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ───────────────────────── Help bar ─────────────────────────

class _HelpBar extends StatelessWidget {
  const _HelpBar({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final terminal = order.orderStatus == OrderStatus.delivered ||
        order.orderStatus == OrderStatus.cancelled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: _HelpBtn(
              icon: Icons.help_outline_rounded,
              label: 'Help',
              onTap: () => HapticFeedback.selectionClick(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HelpBtn(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              onTap: () => _shareOrder(context),
            ),
          ),
          if (!terminal) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _HelpBtn(
                icon: Icons.cancel_outlined,
                label: 'Cancel',
                danger: true,
                onTap: () => HapticFeedback.selectionClick(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _shareOrder(BuildContext context) {
    HapticFeedback.selectionClick();
    final shortId = order.id.length > 6
        ? order.id.substring(0, 6).toUpperCase()
        : order.id.toUpperCase();
    Clipboard.setData(
      ClipboardData(
        text:
            'My Dawat order #DWT-$shortId — ${Formatters.currency(order.total)}',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order details copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _HelpBtn extends StatelessWidget {
  const _HelpBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? _TP.red : _TP.g60;
    final border = danger ? _TP.red.withValues(alpha: 0.15) : _TP.g8;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: danger ? _TP.red : _TP.g40),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Helpers ─────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: _TP.g40,
      ),
    );
  }
}

// ───────────────────────── Empty / error ─────────────────────────

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            Text('Order not found', style: AppTextStyles.heading2),
            const SizedBox(height: AppSizes.xs),
            Text(
              'This order may have been removed or doesn\'t belong to you.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton(
              onPressed: () => context.go(AppRoutes.myEvents),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xl,
                  vertical: AppSizes.md,
                ),
              ),
              child: const Text('Back to orders'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            Text('Couldn\'t load order', style: AppTextStyles.heading2),
            const SizedBox(height: AppSizes.xs),
            Text(message,
                style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Rate-your-order card ─────────────────────────

class _RateOrderCard extends ConsumerWidget {
  const _RateOrderCard({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantId = order.restaurantId!;
    final reviewAsync = ref.watch(myReviewForOrderProvider(order.id));
    final restaurants = ref.watch(restaurantsProvider).valueOrNull;
    final matches = restaurants?.where((r) => r.id == restaurantId);
    final name = (matches != null && matches.isNotEmpty)
        ? matches.first.name
        : 'this restaurant';

    final existing = reviewAsync.valueOrNull;
    final alreadyRated = existing != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md + 2),
        decoration: BoxDecoration(
          color: AppColors.catGoldLt,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.star_rounded,
                  color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alreadyRated
                        ? 'You rated this order'
                        : 'How was your order?',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alreadyRated
                        ? '${existing.rating}★ — tap to edit'
                        : 'Share a rating for $name',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      showRateOrderSheet(
                        context,
                        restaurantId: restaurantId,
                        restaurantName: name,
                        orderId: order.id,
                        existing: existing,
                      );
                    },
                    child: Text(
                      alreadyRated ? 'Edit rating' : 'Rate order',
                      style: AppTextStyles.buttonLabel
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
