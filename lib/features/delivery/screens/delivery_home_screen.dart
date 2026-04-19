import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/supabase/supabase_client.dart' as sb;
import '../../../core/utils/formatters.dart';
import '../../../data/models/delivery_assignment.dart';
import '../../../data/models/driver_profile.dart';
import '../../../shared/providers/delivery_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../widgets/delivery_bottom_nav.dart';
import 'new_order_sheet.dart';

class DeliveryHomeScreen extends ConsumerStatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  ConsumerState<DeliveryHomeScreen> createState() =>
      _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends ConsumerState<DeliveryHomeScreen> {
  bool _sheetOpen = false;

  @override
  Widget build(BuildContext context) {
    // Auto-surface new offers when the driver is online and has nothing active.
    ref.listen<AsyncValue<List<DeliveryAssignment>>>(
      deliveryOffersProvider,
      (_, next) {
        final offers = next.valueOrNull ?? const [];
        if (offers.isEmpty || _sheetOpen) return;
        final active = ref.read(activeDeliveryProvider).valueOrNull;
        if (active != null) return;
        final driver = ref.read(currentDriverProvider).valueOrNull;
        if (driver == null || !driver.isOnline) return;
        _showOfferSheet(offers.first);
      },
    );

    final driverAsync = ref.watch(currentDriverProvider);
    final active = ref.watch(activeDeliveryProvider).valueOrNull;
    final historyAsync = ref.watch(deliveryHistoryProvider);

    return AppScaffold(
      padded: false,
      bottomBar: const DeliveryBottomNav(active: DeliveryNavTab.home),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(deliveryHistoryProvider);
          await ref.read(deliveryHistoryProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(driver: driverAsync.valueOrNull),
            const SizedBox(height: AppSizes.sm),
            if (driverAsync.valueOrNull != null)
              _OnlineToggle(driver: driverAsync.value!),
            const SizedBox(height: AppSizes.md),
            _StatsRow(driver: driverAsync.valueOrNull, history: historyAsync),
            const SizedBox(height: AppSizes.md),
            if (active != null) _ActiveOrderCard(assignment: active),
            _TodayDeliveries(history: historyAsync),
            const SizedBox(height: AppSizes.xl),
          ].animate(interval: 50.ms).fadeIn(duration: 250.ms),
        ),
      ),
    );
  }

  Future<void> _showOfferSheet(DeliveryAssignment offer) async {
    setState(() => _sheetOpen = true);
    final accepted = await NewOrderSheet.show(context, offer);
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    final driverId = ref.read(currentDriverIdProvider);
    final repo = ref.read(deliveryRepositoryProvider);
    if (accepted == true) {
      await repo.acceptOffer(offer.id, driverId);
      if (!mounted) return;
      context.push(AppRoutes.deliveryActiveFor(offer.id));
    } else if (accepted == false) {
      await repo.declineOffer(offer.id, driverId);
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.driver});
  final DriverProfile? driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.catBlueLt,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(PhosphorIconsFill.userCircle,
                color: AppColors.catBlue, size: 30),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, ${driver?.name.split(' ').first ?? 'Partner'}!',
                    style: AppTextStyles.heading1),
                const SizedBox(height: 2),
                Text(
                  driver == null
                      ? 'Loading profile…'
                      : '${driver!.vehicle} · ${driver!.vehicleNumber}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              if (AppConfig.hasSupabase) {
                await sb.auth.signOut();
              }
              if (!context.mounted) return;
              context.go(AppRoutes.login);
            },
            tooltip: 'Sign out',
            icon: const Icon(PhosphorIconsBold.signOut),
          ),
        ],
      ),
    );
  }
}

class _OnlineToggle extends ConsumerWidget {
  const _OnlineToggle({required this.driver});
  final DriverProfile driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = driver.isOnline;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ref
              .read(deliveryRepositoryProvider)
              .setOnline(driver.id, !online),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.md + 2,
            ),
            decoration: BoxDecoration(
              color: online ? AppColors.catGreenLt : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: online
                    ? AppColors.success.withValues(alpha: 0.25)
                    : AppColors.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  online
                      ? PhosphorIconsFill.circle
                      : PhosphorIconsBold.pause,
                  color: online ? AppColors.success : AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    online ? "You're online" : "You're offline",
                    style: AppTextStyles.heading2.copyWith(
                      color:
                          online ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
                _Switch(on: online),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 48,
      height: 26,
      decoration: BoxDecoration(
        color: on ? AppColors.success : AppColors.textMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: on ? 24 : 2,
            top: 2,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.driver, required this.history});
  final DriverProfile? driver;
  final AsyncValue<List<DeliveryAssignment>> history;

  @override
  Widget build(BuildContext context) {
    final today = history.valueOrNull?.where(_isToday).toList() ?? const [];
    final delivered =
        today.where((a) => a.status == DeliveryStatus.delivered).length;
    final earned = today
        .where((a) => a.status == DeliveryStatus.delivered)
        .fold<double>(0, (sum, a) => sum + a.earningAmount);
    final rating = driver?.rating ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePaddingSm),
      child: Row(
        children: [
          Expanded(child: _StatMini(value: '$delivered', label: 'Deliveries')),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _StatMini(
              value: Formatters.currency(earned),
              label: 'Earned',
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _StatMini(
              value: rating > 0 ? '⭐ ${rating.toStringAsFixed(1)}' : '—',
              label: 'Rating',
            ),
          ),
        ],
      ),
    );
  }

  static bool _isToday(DeliveryAssignment a) {
    final ts = a.deliveredAt ?? a.offeredAt;
    final now = DateTime.now();
    return ts.year == now.year &&
        ts.month == now.month &&
        ts.day == now.day;
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.displaySm),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.assignment});
  final DeliveryAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final inTransit = assignment.status == DeliveryStatus.pickedUp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePaddingSm,
        0,
        AppSizes.pagePaddingSm,
        AppSizes.md,
      ),
      child: AppCard(
        onTap: () =>
            context.push(AppRoutes.deliveryActiveFor(assignment.id)),
        border: Border(
          left: BorderSide(
            color: inTransit ? AppColors.info : AppColors.accent,
            width: 3,
          ),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pill(
                  label: inTransit ? 'In transit' : 'Heading to pickup',
                  color: inTransit ? AppColors.info : AppColors.accent,
                  bg: inTransit
                      ? AppColors.catBlueLt
                      : AppColors.catGoldLt,
                ),
                const Spacer(),
                Text(
                  '#${assignment.orderId}',
                  style: AppTextStyles.captionBold,
                ),
                const SizedBox(width: AppSizes.sm),
                if (assignment.etaMinutes != null)
                  Text(
                    'ETA ${assignment.etaMinutes} min',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                const Icon(PhosphorIconsFill.storefront,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${assignment.restaurantName} → ${assignment.dropAddress}',
                    style: AppTextStyles.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            Row(
              children: [
                Text(
                  '🎉 ${assignment.eventLabel} · ${assignment.guestCount} guests',
                  style: AppTextStyles.caption,
                ),
                const Spacer(),
                Text(
                  '${Formatters.currency(assignment.earningAmount)} earn',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusXs),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TodayDeliveries extends StatelessWidget {
  const _TodayDeliveries({required this.history});
  final AsyncValue<List<DeliveryAssignment>> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.md,
            AppSizes.pagePadding,
            AppSizes.sm,
          ),
          child: Text(
            "TODAY'S DELIVERIES",
            style: AppTextStyles.captionBold.copyWith(
              letterSpacing: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ),
        history.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSizes.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const _EmptyToday(
              message: 'Could not load your deliveries.'),
          data: (all) {
            final today = all
                .where(_StatsRow._isToday)
                .where((a) => a.status == DeliveryStatus.delivered)
                .toList();
            if (today.isEmpty) {
              return const _EmptyToday(
                  message: "No completed deliveries yet today.");
            }
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePaddingSm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.xs,
                ),
                child: Column(
                  children: [
                    for (final a in today) ...[
                      if (a != today.first)
                        const Divider(height: 1, color: AppColors.divider),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSizes.sm),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.catGreenLt,
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusSm),
                              ),
                              child: const Icon(PhosphorIconsFill.checkCircle,
                                  color: AppColors.success, size: 18),
                            ),
                            const SizedBox(width: AppSizes.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.restaurantName.isEmpty
                                        ? 'Order'
                                        : a.restaurantName,
                                    style: AppTextStyles.bodyBold,
                                  ),
                                  Text(
                                    '${a.eventLabel.isEmpty ? 'Delivery' : a.eventLabel} · '
                                    '${a.guestCount > 0 ? '${a.guestCount} guests · ' : ''}'
                                    '${Formatters.time(a.deliveredAt ?? a.offeredAt)}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+${Formatters.currency(a.earningAmount)}',
                              style: AppTextStyles.heading3
                                  .copyWith(color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSizes.pagePaddingSm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius:
                    BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: const Icon(PhosphorIconsDuotone.package,
                  color: AppColors.textMuted, size: 18),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(message, style: AppTextStyles.caption),
            ),
          ],
        ),
      ),
    );
  }
}
