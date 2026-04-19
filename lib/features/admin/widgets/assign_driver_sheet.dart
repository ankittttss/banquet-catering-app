import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/delivery_assignment.dart';
import '../../../data/models/driver_profile.dart';
import '../../../data/models/order.dart';
import '../../../shared/providers/repositories_providers.dart';

/// Bottom sheet shown from the admin orders screen: lists online + free
/// drivers and lets the admin either assign directly or broadcast an offer.
class AssignDriverSheet extends ConsumerStatefulWidget {
  const AssignDriverSheet._({required this.order});
  final OrderSummary order;

  static Future<void> show(BuildContext context, OrderSummary order) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
      ),
      builder: (_) => AssignDriverSheet._(order: order),
    );
  }

  @override
  ConsumerState<AssignDriverSheet> createState() => _State();
}

class _State extends ConsumerState<AssignDriverSheet> {
  late Future<List<DriverProfile>> _driversFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _driversFuture =
        ref.read(deliveryRepositoryProvider).fetchAvailableDrivers();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final listHeight = (screenH * 0.55).clamp(200.0, 520.0);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSizes.md),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius:
                  BorderRadius.circular(AppSizes.radiusPill),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding),
            child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assign driver',
                            style: AppTextStyles.heading1),
                        const SizedBox(height: 2),
                        Text(
                          'Order #${widget.order.id.substring(0, 8).toUpperCase()} · '
                          '${Formatters.currency(widget.order.total)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _broadcast,
                    icon: const Icon(PhosphorIconsBold.broadcast, size: 16),
                    label: const Text('Broadcast'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),
            SizedBox(
              height: listHeight,
              child: FutureBuilder<List<DriverProfile>>(
                future: _driversFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding:
                          const EdgeInsets.all(AppSizes.pagePadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsDuotone.warning,
                              size: 48, color: AppColors.error),
                          const SizedBox(height: AppSizes.md),
                          Text('Couldn\'t load drivers',
                              style: AppTextStyles.heading2),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            '${snap.error}',
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSizes.md),
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _driversFuture = ref
                                  .read(deliveryRepositoryProvider)
                                  .fetchAvailableDrivers();
                            }),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  final drivers = snap.data ?? const <DriverProfile>[];
                  if (drivers.isEmpty) {
                    return Padding(
                      padding:
                          const EdgeInsets.all(AppSizes.pagePadding),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsDuotone.userCircleMinus,
                              size: 56,
                              color: AppColors.textMuted),
                          const SizedBox(height: AppSizes.md),
                          Text('No drivers available',
                              style: AppTextStyles.heading2),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            'Try broadcasting so any online driver can accept.',
                            style: AppTextStyles.caption,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pagePaddingSm,
                      vertical: AppSizes.xs,
                    ),
                    itemBuilder: (_, i) => _DriverTile(
                      driver: drivers[i],
                      busy: _busy,
                      onTap: () => _assign(drivers[i]),
                    ),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.sm),
                    itemCount: drivers.length,
                  );
                },
              ),
            ),
          ],
        ),
    );
  }

  DeliveryAssignment _draftFromOrder({String? driverId}) {
    final o = widget.order;
    return DeliveryAssignment(
      id: 'a-${o.id}',
      orderId: o.id,
      status: driverId == null
          ? DeliveryStatus.offered
          : DeliveryStatus.accepted,
      offeredAt: DateTime.now(),
      pickupAddress: 'Restaurant pickup',
      dropAddress: o.location ?? 'Customer address',
      distanceKm: 4.2,
      earningAmount: 85,
      itemCount: 3,
      restaurantName: 'Kitchen',
      customerName: 'Customer',
      customerPhone: '',
      eventLabel: '🎉 Event',
      guestCount: o.guestCount ?? 0,
      deliveryOtp: '4829',
      driverId: driverId,
      acceptedAt: driverId != null ? DateTime.now() : null,
      etaMinutes: 18,
    );
  }

  Future<void> _assign(DriverProfile d) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(deliveryRepositoryProvider);
      await repo.assignDriverToOrder(
        orderId: widget.order.id,
        driverId: d.id,
        draft: _draftFromOrder(driverId: d.id),
      );
      // Reflect on the order side: mark dispatched.
      await ref
          .read(orderRepositoryProvider)
          .updateStatus(widget.order.id, OrderStatus.dispatched);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned to ${d.name}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assign failed: $e')),
      );
    }
  }

  Future<void> _broadcast() async {
    setState(() => _busy = true);
    final repo = ref.read(deliveryRepositoryProvider);
    await repo.broadcastOffer(_draftFromOrder());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Broadcast to all online drivers')),
    );
    Navigator.of(context).pop();
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({
    required this.driver,
    required this.busy,
    required this.onTap,
  });
  final DriverProfile driver;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.catBlueLt,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(PhosphorIconsFill.userCircle,
                    color: AppColors.catBlue, size: 28),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(driver.name, style: AppTextStyles.bodyBold),
                        const SizedBox(width: AppSizes.sm),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${driver.vehicle} · ⭐ ${driver.rating.toStringAsFixed(1)} · '
                      '${driver.totalDeliveries} deliveries',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(PhosphorIconsBold.caretRight,
                  color: AppColors.textMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
