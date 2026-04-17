import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/order.dart';
import '../widgets/status_badge.dart';

/// Single source of truth for how an [OrderStatus] looks in the UI.
/// Any screen rendering status badges/icons should read from this extension
/// — do NOT duplicate the mapping inline.
extension OrderStatusPresentation on OrderStatus {
  StatusTone get tone => switch (this) {
        OrderStatus.placed => StatusTone.pending,
        OrderStatus.confirmed => StatusTone.info,
        OrderStatus.preparing => StatusTone.info,
        OrderStatus.dispatched => StatusTone.warning,
        OrderStatus.delivered => StatusTone.success,
        OrderStatus.cancelled => StatusTone.error,
      };

  IconData get icon => switch (this) {
        OrderStatus.placed => PhosphorIconsFill.clock,
        OrderStatus.confirmed => PhosphorIconsFill.checkCircle,
        OrderStatus.preparing => PhosphorIconsFill.forkKnife,
        OrderStatus.dispatched => PhosphorIconsFill.truck,
        OrderStatus.delivered => PhosphorIconsFill.package,
        OrderStatus.cancelled => PhosphorIconsFill.xCircle,
      };

  /// Foreground color for this status (used in notification icon tints etc).
  Color get foregroundColor => switch (this) {
        OrderStatus.placed => AppColors.accentDark,
        OrderStatus.confirmed => AppColors.info,
        OrderStatus.preparing => AppColors.info,
        OrderStatus.dispatched => AppColors.warning,
        OrderStatus.delivered => AppColors.success,
        OrderStatus.cancelled => AppColors.error,
      };
}
