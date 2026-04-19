import 'dart:math' as math;

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
import '../../../data/models/order.dart';
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
  static const Color blue = Color(0xFF2B6CB0);
  static const Color blueLight = Color(0xFFEBF4FF);

  static const Color black = Color(0xFF1A1A1A);
  static const Color g80 = Color(0xFF3D3530);
  static const Color g60 = Color(0xFF6B5D4F);
  static const Color g40 = Color(0xFF8C8078);
  static const Color g25 = Color(0xFFB0A89E);
  static const Color g15 = Color(0xFFD8D0C8);
  static const Color g8 = Color(0xFFEAE4DE);
  static const Color g4 = Color(0xFFF5F0EB);
  static const Color cream = Color(0xFFFDFBF9);

  static const Color mapTop = Color(0xFFE8DDD4);
  static const Color mapMid = Color(0xFFD4C8BC);
  static const Color mapBot = Color(0xFFC8BCA8);
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
    return Stack(
      children: [
        // Fills whole screen; map sits up top, bottom sheet overlaps.
        Positioned.fill(
          child: Column(
            children: [
              _MapArea(order: order),
              Expanded(
                child: _BottomSheet(order: order),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Map area ─────────────────────────

class _MapArea extends StatelessWidget {
  const _MapArea({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 300 + topPad,
      child: Stack(
        children: [
          // Gradient terrain
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.2, -1),
                  end: Alignment(0.4, 1),
                  colors: [_TP.mapTop, _TP.mapMid, _TP.mapBot],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Grid
          const Positioned.fill(child: _MapGrid()),
          // Roads
          const Positioned.fill(child: _MapRoads()),
          // Labels
          const Positioned(
            top: 90,
            left: 30,
            child: _MapLabel(text: 'Jubilee Hills'),
          ),
          const Positioned(
            top: 200,
            right: 30,
            child: _MapLabel(text: 'Banjara Hills'),
          ),
          // Animated route
          Positioned.fill(
            child: CustomPaint(painter: _RoutePainter()),
          ),
          // Restaurant marker
          Positioned(
            top: topPad + 100,
            left: 40,
            child: const _MapMarker(
              emoji: '🍛',
              pinColor: _TP.gold,
              label: 'Restaurant',
            ),
          ),
          // Rider (animated)
          Positioned(
            top: topPad + 140,
            left: MediaQuery.of(context).size.width / 2 - 34,
            child: _RiderMarker(
              name: order.driverName ?? 'On the way',
            ),
          ),
          // User marker
          Positioned(
            bottom: 64,
            right: 40,
            child: const _MapMarker(
              emoji: '📍',
              pinColor: _TP.red,
              label: 'Your location',
            ),
          ),
          // Top controls
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MapBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.userHome),
                ),
                _MapBtn(
                  icon: Icons.open_in_full_rounded,
                  onTap: () => HapticFeedback.selectionClick(),
                ),
              ],
            ),
          ),
          // ETA chip
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: _EtaChip(order: order)),
          ),
        ],
      ),
    );
  }
}

class _MapGrid extends StatelessWidget {
  const _MapGrid();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _TP.black.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (final frac in [0.2, 0.4, 0.6, 0.8]) {
      canvas.drawLine(
        Offset(0, size.height * frac),
        Offset(size.width, size.height * frac),
        p,
      );
      canvas.drawLine(
        Offset(size.width * frac, 0),
        Offset(size.width * frac, size.height),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _MapRoads extends StatelessWidget {
  const _MapRoads();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RoadsPainter());
  }
}

class _RoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round;

    // Main horizontal road
    p.strokeWidth = 6;
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      p,
    );
    // Vertical cross
    canvas.drawLine(
      Offset(size.width * 0.45, 0),
      Offset(size.width * 0.45, size.height),
      p,
    );
    // Side
    p.strokeWidth = 5;
    canvas.save();
    canvas.translate(size.width * 0.2, size.height * 0.35);
    canvas.rotate(-12 * math.pi / 180);
    canvas.drawLine(Offset.zero, Offset(size.width * 0.55, 0), p);
    canvas.restore();

    canvas.save();
    canvas.translate(size.width * 0.1, size.height * 0.72);
    canvas.rotate(5 * math.pi / 180);
    canvas.drawLine(Offset.zero, Offset(size.width * 0.4, 0), p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoadsPainter old) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.2, size.height * 0.45);
    final end = Offset(size.width * 0.8, size.height * 0.75);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        size.width * 0.35, size.height * 0.2,
        size.width * 0.7, size.height * 0.3,
        end.dx, end.dy,
      );

    final paint = Paint()
      ..color = _TP.red.withValues(alpha: 0.55)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Dashed path
    const dash = 6.0, gap = 4.0;
    final metrics = path.computeMetrics().toList();
    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => false;
}

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.black.withValues(alpha: 0.2),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.emoji,
    required this.pinColor,
    required this.label,
  });
  final String emoji;
  final Color pinColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: pinColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            Positioned(
              bottom: -5,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(width: 10, height: 10, color: pinColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _TP.g80,
            ),
          ),
        ),
      ],
    )
        .animate()
        .scale(
          duration: 500.ms,
          curve: Curves.easeOutBack,
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
        )
        .fadeIn(duration: 300.ms);
  }
}

class _RiderMarker extends StatelessWidget {
  const _RiderMarker({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Pulse
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _TP.red, width: 2),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  duration: 2000.ms,
                  begin: const Offset(1, 1),
                  end: const Offset(1.4, 1.4),
                  curve: Curves.easeOut,
                )
                .fadeOut(duration: 2000.ms),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('🏍️', style: TextStyle(fontSize: 22)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _TP.red,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _TP.red.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .slideX(
          begin: -0.12,
          end: 0.12,
          duration: 3800.ms,
          curve: Curves.easeInOut,
        )
        .slideY(
          begin: -0.06,
          end: 0.06,
          duration: 3800.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _MapBtn extends StatelessWidget {
  const _MapBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: _TP.g80),
        ),
      ),
    );
  }
}

class _EtaChip extends StatelessWidget {
  const _EtaChip({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final time = _etaHeadline(order);
    final label = order.orderStatus == OrderStatus.delivered
        ? 'Delivered'
        : order.orderStatus == OrderStatus.cancelled
            ? 'Status'
            : 'Arriving in';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _TP.green,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeOut(duration: 600.ms),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _TP.g40,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _TP.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Bottom sheet ─────────────────────────

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -20),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 30,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _TP.g15,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _StatusHeader(order: order),
            _ProgressBar(order: order),
            _Timeline(order: order),
            if (order.orderStatus == OrderStatus.delivered &&
                order.restaurantId != null)
              _RateOrderCard(order: order),
            const _SheetDivider(),
            if (order.driverName != null) ...[
              _DriverSection(order: order),
              const _SheetDivider(),
            ],
            if (order.eventDate != null) _EventBadge(order: order),
            _OrderSummaryBlock(order: order),
            _HelpBar(order: order),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
      OrderStatus.dispatched => 'On the way!',
      OrderStatus.delivered => 'Delivered 🎉',
      OrderStatus.cancelled => 'Cancelled',
    };

    final shortId = order.id.length > 6
        ? order.id.substring(0, 6).toUpperCase()
        : order.id.toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
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
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _TP.green,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeOut(duration: 600.ms),
                    const SizedBox(width: 6),
                    const Text(
                      'Live tracking • Updated just now',
                      style: TextStyle(
                        fontSize: 13,
                        color: _TP.g40,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
        title: 'Restaurant accepted',
        subtitle: 'Preparing your food',
        time: _time(order.confirmedAt),
        state: _stateFor(1, active),
      ),
      _TimelineStep(
        icon: Icons.restaurant_rounded,
        title: 'Food is ready',
        subtitle: 'Packed and handed to delivery partner',
        time: _time(order.preparingAt),
        state: _stateFor(2, active),
      ),
      _TimelineStep(
        icon: Icons.flash_on_rounded,
        title: 'Out for delivery',
        subtitle: order.driverName == null
            ? 'On the way to your location'
            : '${order.driverName} is heading to your location',
        time: _time(order.dispatchedAt),
        state: _stateFor(3, active),
      ),
      _TimelineStep(
        icon: Icons.access_time_rounded,
        title: 'Delivered',
        subtitle: order.deliveredAt != null
            ? 'Enjoy your meal!'
            : _deliveredEta(order),
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

  String _deliveredEta(OrderSummary o) {
    if (o.etaMinutesMax != null) {
      final eta = DateTime.now().add(Duration(minutes: o.etaMinutesMax!));
      return 'Estimated by ${_time(eta)}';
    }
    return 'Estimated soon';
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

// ───────────────────────── Driver section ─────────────────────────

class _DriverSection extends StatelessWidget {
  const _DriverSection({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final avatarBg = AppColors.fromHex(order.driverAvatarHex,
        fallback: _TP.blueLight);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Delivery partner'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _TP.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _TP.g8, width: 1.5),
            ),
            child: Row(
              children: [
                // Avatar + rating badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text('👨‍💼',
                          style: TextStyle(fontSize: 26)),
                    ),
                    if (order.driverRating != null)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _TP.green,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                order.driverRating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 1),
                              const Icon(Icons.star_rounded,
                                  size: 9, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.driverName ?? 'Delivery partner',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _TP.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            'Honda Activa',
                            style: TextStyle(fontSize: 12, color: _TP.g40),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: _TP.g4,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'TS 09 AB 1234',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _TP.g60,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _DriverAction(
                  icon: Icons.call_rounded,
                  bg: _TP.greenLight,
                  fg: _TP.green,
                  onTap: () => HapticFeedback.selectionClick(),
                ),
                const SizedBox(width: 8),
                _DriverAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  bg: _TP.blueLight,
                  fg: _TP.blue,
                  onTap: () => HapticFeedback.selectionClick(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAction extends StatelessWidget {
  const _DriverAction({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: fg),
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
    final when = order.eventDate == null
        ? ''
        : _eventDateLine(order.eventDate!);
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _eventDateLine(DateTime d) {
    final wd = _weekdays[d.weekday - 1];
    final m = _months[d.month - 1];
    return '$wd, ${d.day} $m ${d.year}';
  }
}

// ───────────────────────── Order summary block ─────────────────────────

class _OrderSummaryBlock extends StatelessWidget {
  const _OrderSummaryBlock({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Order summary'),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _TP.goldLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('🍛', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.location ?? 'Restaurant',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _TP.black,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _subLine(order),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _TP.g40,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _TP.g8)),
            ),
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                _SummaryLine(
                  label: 'Items & restaurant charges',
                  value: Formatters.currency(order.total),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: _TP.g15,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
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
          ),
        ],
      ),
    );
  }

  String _subLine(OrderSummary o) {
    if (o.etaMinutesMin != null && o.etaMinutesMax != null) {
      return '${o.etaMinutesMin}–${o.etaMinutesMax} min · Event order';
    }
    return 'Event order';
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
              fontWeight: FontWeight.w600,
              color: _TP.black,
            ),
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
              label: 'Share ETA',
              onTap: () => HapticFeedback.selectionClick(),
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

String _etaHeadline(OrderSummary o) {
  if (o.orderStatus == OrderStatus.delivered) return 'Completed';
  if (o.orderStatus == OrderStatus.cancelled) return 'Cancelled';
  if (o.etaMinutesMin != null && o.etaMinutesMax != null) {
    return '${o.etaMinutesMin}–${o.etaMinutesMax} min';
  }
  if (o.etaMinutesMax != null) return '${o.etaMinutesMax} min';
  return 'Tracking…';
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
          border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.25)),
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
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSm),
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
