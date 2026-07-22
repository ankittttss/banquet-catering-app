import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/providers/event_plan_providers.dart';
import '../event_plan_summary.dart';

/// Status colour + short label for the current readiness.
({Color color, String label}) _status(EventPlanSummary s) =>
    switch (s.readiness) {
      EventPlanReadiness.ready => (color: AppColors.success, label: 'Ready'),
      EventPlanReadiness.checking => (
          color: AppColors.textMuted,
          label: 'Checking…'
        ),
      EventPlanReadiness.needsAttention => (
          color: AppColors.warning,
          label: 'Needs attention'
        ),
      EventPlanReadiness.incomplete => (
          color: AppColors.primary,
          label: 'In progress'
        ),
      EventPlanReadiness.notStarted => (
          color: AppColors.primary,
          label: 'Plan an event'
        ),
    };

/// THE single entry rule for the event plan: open the plan when one exists,
/// otherwise start a new one. Never opens a blank management page.
///
/// Public so screens with their own header language (e.g. the restaurant
/// detail photo header's circular actions) can reuse the behaviour without
/// duplicating the routing decision.
void openEventPlan(BuildContext context, WidgetRef ref) {
  final s = ref.read(eventPlanSummaryProvider);
  context.push(
    s.hasMeaningfulDraft ? AppRoutes.eventPlan : AppRoutes.eventDetails,
  );
}

/// Full-width entry point used where there is room for a summary line
/// (home, search results).
class EventPlanChip extends ConsumerWidget {
  const EventPlanChip({super.key, this.margin});

  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(eventPlanSummaryProvider);
    final status = _status(s);

    return Padding(
      padding: margin ??
          const EdgeInsets.symmetric(
            horizontal: AppSizes.pagePadding,
            vertical: AppSizes.sm,
          ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: InkWell(
          onTap: () => openEventPlan(context, ref),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: const Icon(
                    PhosphorIconsFill.calendarCheck,
                    size: 17,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSizes.sm + 2),
                Expanded(
                  child: s.hasMeaningfulDraft
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Event plan',
                              style: AppTextStyles.captionBold
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${s.cardSubtitle} · ${s.guestsText}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyBold
                                  .copyWith(fontSize: 13.5),
                            ),
                          ],
                        )
                      : Text(
                          'Plan an event',
                          style:
                              AppTextStyles.bodyBold.copyWith(fontSize: 13.5),
                        ),
                ),
                const SizedBox(width: AppSizes.sm),
                if (s.hasMeaningfulDraft)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    ),
                    child: Text(
                      status.label,
                      style: AppTextStyles.captionBold.copyWith(
                        color: status.color,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact header action for screens where vertical space belongs to the menu
/// (restaurant detail, build-your-menu). Deliberately icon-first.
class EventPlanAction extends ConsumerWidget {
  const EventPlanAction({super.key, this.tint});

  /// Icon colour override for dark/photo headers.
  final Color? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(eventPlanSummaryProvider);
    final status = _status(s);
    final label = s.hasMeaningfulDraft ? 'Plan' : 'Plan an event';

    return Semantics(
      button: true,
      label: s.hasMeaningfulDraft
          ? 'Event plan, ${status.label}'
          : 'Plan an event',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
          child: InkWell(
            onTap: () => openEventPlan(context, ref),
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        PhosphorIconsFill.calendarCheck,
                        size: 18,
                        color: tint ?? AppColors.textPrimary,
                      ),
                      if (s.hasMeaningfulDraft && !s.isReady)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.captionBold.copyWith(
                      color: tint ?? AppColors.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
