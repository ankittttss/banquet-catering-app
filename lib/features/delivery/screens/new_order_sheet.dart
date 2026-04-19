import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/delivery_assignment.dart';

/// Modal bottom sheet shown when a new delivery offer arrives.
/// Returns `true` if the driver accepted, `false` if declined, `null` on
/// timeout or dismiss.
class NewOrderSheet extends StatefulWidget {
  const NewOrderSheet._({required this.offer});
  final DeliveryAssignment offer;

  static Future<bool?> show(BuildContext context, DeliveryAssignment offer) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => NewOrderSheet._(offer: offer),
    );
  }

  @override
  State<NewOrderSheet> createState() => _NewOrderSheetState();
}

class _NewOrderSheetState extends State<NewOrderSheet> {
  static const _totalSeconds = 15;
  int _remaining = _totalSeconds;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _timer.cancel();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXl)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.pagePadding + MediaQuery.of(context).padding.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            _Timer(remaining: _remaining, total: _totalSeconds),
            const SizedBox(height: AppSizes.md),
            Center(
              child: Text('New order request!',
                  style: AppTextStyles.heading2),
            ),
            const SizedBox(height: AppSizes.lg),
            _Route(pickup: o.pickupAddress, drop: o.dropAddress),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: _MetaTile(
                    value: '${o.distanceKm.toStringAsFixed(1)} km',
                    label: 'Distance',
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _MetaTile(
                    value: Formatters.currency(o.earningAmount),
                    label: 'Earn',
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _MetaTile(
                    value: '${o.itemCount} items',
                    label: 'Order',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.catGoldLt,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.cake,
                      color: AppColors.accent, size: 22),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${o.eventLabel} — ${o.guestCount} Guests',
                          style: AppTextStyles.bodyBold,
                        ),
                        Text(
                          'Setup required on arrival',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accentDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppSizes.buttonHeight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm),
                        ),
                      ),
                      child: Text('Decline',
                          style: AppTextStyles.buttonLabel),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: SizedBox(
                    height: AppSizes.buttonHeight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Accept',
                              style: AppTextStyles.buttonLabel.copyWith(
                                color: Colors.white,
                              )),
                          const SizedBox(width: 6),
                          const Icon(PhosphorIconsBold.arrowRight,
                              color: Colors.white, size: 18),
                        ],
                      ),
                    ),
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

class _Timer extends StatelessWidget {
  const _Timer({required this.remaining, required this.total});
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = remaining / total;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
              Text(
                '$remaining',
                style: AppTextStyles.heading2
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Text(
          'seconds to accept',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.pickup, required this.drop});
  final String pickup;
  final String drop;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppColors.border,
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Addr(label: 'PICKUP', addr: pickup),
              const SizedBox(height: AppSizes.md),
              _Addr(label: 'DROP-OFF', addr: drop),
            ],
          ),
        ),
      ],
    );
  }
}

class _Addr extends StatelessWidget {
  const _Addr({required this.label, required this.addr});
  final String label;
  final String addr;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(addr, style: AppTextStyles.bodyBold),
      ],
    );
  }
}

class _MetaTile extends StatelessWidget {
  const _MetaTile({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.heading2),
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
