import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/app_notification.dart';
import '../../../shared/providers/notification_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsStreamProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.profile),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(notificationRepositoryProvider)
                  .markAllRead();
            },
            child: Text(
              'Mark all read',
              style: AppTextStyles.captionBold
                  .copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn\'t load notifications',
          message: '$e',
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_rounded,
              title: 'You\'re all caught up',
              message: 'New notifications will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
            itemCount: list.length,
            itemBuilder: (_, i) => _NotificationRow(
              n: list[i],
              onTap: () async {
                final n = list[i];
                if (n.isUnread) {
                  await ref
                      .read(notificationRepositoryProvider)
                      .markRead(n.id);
                }
                if (!context.mounted) return;
                if (n.orderId != null) {
                  context.push(AppRoutes.orderDetailFor(n.orderId!));
                }
              },
            ).animate().fadeIn(duration: 220.ms, delay: (30 * i).ms),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Row ─────────────────────────

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.n, required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.fromHex(n.bgHex, fallback: AppColors.primarySoft);
    final fg = AppColors.fromHex(n.accentHex, fallback: AppColors.primary);
    final icon = _iconFor(n.iconName);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePadding,
          vertical: AppSizes.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: AppTextStyles.bodyBold
                          .copyWith(fontSize: 14)),
                  if (n.body != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      n.body!,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                      maxLines: 3,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(n.createdAt),
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (n.isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? name) {
    switch (name) {
      case 'check_circle':
        return Icons.check_circle_rounded;
      case 'local_offer':
        return Icons.local_offer_rounded;
      case 'delivery_dining':
        return Icons.delivery_dining_rounded;
      case 'celebration':
        return Icons.celebration_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'cancel':
        return Icons.cancel_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
