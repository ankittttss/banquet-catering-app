import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/delivery_assignment.dart';
import '../../../shared/providers/delivery_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../widgets/delivery_bottom_nav.dart';

enum _Range { today, week, month }

class DeliveryEarningsScreen extends ConsumerStatefulWidget {
  const DeliveryEarningsScreen({super.key});
  @override
  ConsumerState<DeliveryEarningsScreen> createState() => _State();
}

class _State extends ConsumerState<DeliveryEarningsScreen> {
  _Range _tab = _Range.today;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(deliveryHistoryProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(title: const Text('Earnings')),
      bottomBar: const DeliveryBottomNav(active: DeliveryNavTab.earnings),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(deliveryHistoryProvider),
        ),
        data: (all) {
          final delivered = all
              .where((a) => a.status == DeliveryStatus.delivered)
              .toList();
          final inRange =
              delivered.where((a) => _inRange(a, _tab)).toList();

          final totalEarned = delivered.fold<double>(
              0, (sum, a) => sum + a.earningAmount);
          final rangeEarned =
              inRange.fold<double>(0, (sum, a) => sum + a.earningAmount);
          final rangeDistance =
              inRange.fold<double>(0, (sum, a) => sum + a.distanceKm);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(deliveryHistoryProvider);
              await ref.read(deliveryHistoryProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSizes.xl),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSizes.pagePaddingSm),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Column(
                      children: [
                        Text(
                          Formatters.currency(totalEarned),
                          style: AppTextStyles.display,
                        ),
                        const SizedBox(height: 4),
                        Text('All-time earned',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pagePaddingSm),
                  child: Row(
                    children: [
                      for (final r in _Range.values) ...[
                        Expanded(
                          child: _Tab(
                            label: _label(r),
                            selected: _tab == r,
                            onTap: () => setState(() => _tab = r),
                          ),
                        ),
                        if (r != _Range.values.last)
                          const SizedBox(width: AppSizes.xs),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pagePaddingSm),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Mini(
                          value: Formatters.currency(rangeEarned),
                          label: 'Earned',
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: _Mini(
                          value: '${inRange.length}',
                          label: 'Trips',
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: _Mini(
                          value:
                              '${rangeDistance.toStringAsFixed(1)} km',
                          label: 'Distance',
                        ),
                      ),
                    ],
                  ),
                ),
                const _SectionTitle('BREAKDOWN'),
                if (inRange.isEmpty)
                  const _EmptyCard(message: 'No deliveries in this range.')
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.pagePaddingSm),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.xs,
                      ),
                      child: Column(
                        children: [
                          _EarnRow(
                            icon: PhosphorIconsFill.motorcycle,
                            bg: AppColors.catGreenLt,
                            fg: AppColors.success,
                            title: 'Delivery fees',
                            subtitle: '${inRange.length} deliveries',
                            amount:
                                '+${Formatters.currency(rangeEarned)}',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _label(_Range r) => switch (r) {
        _Range.today => 'Today',
        _Range.week => 'This Week',
        _Range.month => 'This Month',
      };

  bool _inRange(DeliveryAssignment a, _Range r) {
    final ts = a.deliveredAt ?? a.offeredAt;
    final now = DateTime.now();
    return switch (r) {
      _Range.today =>
        ts.year == now.year && ts.month == now.month && ts.day == now.day,
      _Range.week => ts.isAfter(now.subtract(const Duration(days: 7))),
      _Range.month =>
        ts.year == now.year && ts.month == now.month,
    };
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: selected ? AppColors.textPrimary : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.captionBold.copyWith(
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.heading2),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.captionBold
                .copyWith(color: AppColors.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.sm,
      ),
      child: Text(
        text,
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.textMuted,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
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
              child: const Icon(PhosphorIconsDuotone.currencyInr,
                  color: AppColors.textMuted, size: 18),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(child: Text(message, style: AppTextStyles.caption)),
          ],
        ),
      ),
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.title,
    required this.subtitle,
    required this.amount,
  });
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyBold),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.heading3
                .copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}
