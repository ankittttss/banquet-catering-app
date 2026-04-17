import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/order.dart';
import '../../features/user/screens/my_events_screen.dart';
import '../presentation/order_status_presentation.dart';

void showNotificationsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXl),
      ),
    ),
    builder: (_) => const _NotificationsSheet(),
  );
}

class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersStreamProvider).valueOrNull ?? const [];
    // Synthesize notifications from orders + hardcoded tips.
    final items = <_Notif>[
      for (final o in orders.take(5))
        _Notif(
          icon: o.orderStatus.icon,
          color: o.orderStatus.foregroundColor,
          title: 'Booking ${_shortId(o.id)} — ${o.orderStatus.label}',
          body: 'Total ${_fmt(o.total)} · tap to view details',
          when: o.createdAt,
          tag: 'Order',
        ),
      const _Notif(
        icon: PhosphorIconsFill.sparkle,
        color: AppColors.accentDark,
        title: 'Try our wedding menus',
        body: 'Curated thalis from 600/plate — book before Dec 31.',
        tag: 'Promo',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        0,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsDuotone.bell,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: AppSizes.sm),
              Text('Notifications', style: AppTextStyles.heading1),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            items.isEmpty
                ? 'You\'re all caught up.'
                : '${items.length} updates for you',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSizes.md),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.xxxl),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      PhosphorIconsDuotone.bellSlash,
                      size: 64,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text('Nothing new', style: AppTextStyles.bodyBold),
                  ],
                ),
              ),
            )
          else
            for (int i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: _NotifCard(notif: items[i])
                    .animate(delay: (i * 50).ms)
                    .fadeIn(duration: 280.ms)
                    .slideX(begin: 0.08, end: 0),
              ),
        ],
      ),
    );
  }

  static String _shortId(String id) =>
      id.length > 6 ? '#${id.substring(0, 6).toUpperCase()}' : '#$id';

  static String _fmt(double v) => '\u20B9${v.toStringAsFixed(0)}';
}

class _Notif {
  const _Notif({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.tag,
    this.when,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final DateTime? when;
  final String tag;
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif});
  final _Notif notif;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: notif.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(notif.icon, color: notif.color, size: 20),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(notif.title,
                          style: AppTextStyles.bodyBold,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (notif.when != null)
                      Text(
                        timeago.format(notif.when!, locale: 'en_short'),
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(notif.body, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
