import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/event_plan_providers.dart';
import '../../../shared/providers/event_tier_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../event_plan_summary.dart';
import '../plan_edit_context.dart';
import '../plan_edit_flows.dart';

/// Read-only overview of the customer's in-progress event: what is planned,
/// and an honest verdict on whether it is actually orderable.
///
/// Nothing on this page mutates the draft or the cart. The only actions are
/// Retry affordances for the two live validations.
class EventPlanScreen extends ConsumerWidget {
  const EventPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(eventPlanSummaryProvider);

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Event plan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.userHome),
        ),
      ),
      // Deep-linked with nothing planned → never render a blank management
      // page; send the customer to start one instead.
      body: !s.hasMeaningfulDraft
          ? EmptyState(
              icon: Icons.event_available_rounded,
              title: 'Plan an event',
              message: 'Tell us the occasion, date and guest count and we\'ll '
                  'find kitchens that can serve it.',
              actionLabel: 'Plan an event',
              onAction: () => context.go(AppRoutes.eventDetails),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.md,
                AppSizes.pagePadding,
                AppSizes.xxl,
              ),
              children: [
                _StatusCard(summary: s),
                const SizedBox(height: AppSizes.md),
                _Section(
                  icon: PhosphorIconsFill.calendarBlank,
                  title: 'Event',
                  // Edits name/session/date/time/guests. Occasion + location
                  // stay read-only on that screen (they fire immediate,
                  // unconfirmed mutations — deferred to Phase 3).
                  onEdit: () => context.push(PlanEditContext.editEvent()),
                  rows: [
                    if (s.eventName != null) ('Event name', s.eventName!),
                    if (s.occasionText != null) ('Occasion', s.occasionText!),
                    if (s.sessionText != null) ('Session', s.sessionText!),
                    ('Date', s.dateText),
                    ('Time', s.timeText ?? 'Time not set'),
                    ('Guests', s.guestsText),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                // Transactional location change: pick an address, preview which
                // venue/cart selections it invalidates, apply only on confirm.
                _Section(
                  icon: PhosphorIconsFill.mapPin,
                  title: 'Location',
                  onEdit: () => changeEventLocationFlow(context, ref),
                  // Neutral label: the value is a venue NAME for a booked hall
                  // and an address for a private property.
                  rows: [('Event location', s.locationText)],
                ),
                const SizedBox(height: AppSizes.sm),
                _Section(
                  icon: PhosphorIconsFill.forkKnife,
                  title: 'Package',
                  onEdit: () => context.push(PlanEditContext.editPackage()),
                  rows: [
                    ('Selected', s.packageText),
                    if (s.packageRangeText != null)
                      ('Price range', s.packageRangeText!),
                  ],
                  check: s.packageCheck,
                  onRetry: s.packageCheck == EventPlanCheck.error
                      ? () => ref.invalidate(eventTiersProvider)
                      : null,
                ),
                const SizedBox(height: AppSizes.sm),
                if (s.isPrivateProperty) ...[
                  // The ONLY way back to the venue-type screen for a private
                  // plan. Banquet plans reach it through their "Banquet venue"
                  // Edit; without this row a customer who picked private
                  // property could never switch to a hall again.
                  _Section(
                    icon: PhosphorIconsFill.buildings,
                    title: 'Venue type',
                    onEdit: () => context.push(PlanEditContext.editVenue()),
                    rows: const [('Type', 'Private property')],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  // Property type + address details.
                  _Section(
                    icon: PhosphorIconsFill.house,
                    title: 'Private property',
                    onEdit: () => context.push(PlanEditContext.editProperty()),
                    rows: [('Property', s.propertyText)],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  _Section(
                    icon: PhosphorIconsFill.wrench,
                    title: 'Setup & equipment',
                    onEdit: () => context.push(PlanEditContext.editSetup()),
                    rows: [
                      (
                        'Add-ons',
                        s.addonCount == 0
                            ? 'None selected'
                            : '${s.addonCount} selected'
                      ),
                    ],
                  ),
                ] else
                  // Change the hall, or switch to private property, via the
                  // reused venue screen (safe, confirmed, returns to plan).
                  _Section(
                    icon: PhosphorIconsFill.buildings,
                    title: 'Banquet venue',
                    onEdit: () => context.push(PlanEditContext.editVenue()),
                    rows: [
                      (
                        'Selected',
                        s.venueText.isEmpty ? 'No venue selected' : s.venueText
                      ),
                      if (s.venueCapacityText != null)
                        ('Capacity', s.venueCapacityText!),
                    ],
                    check: s.venueCheck,
                    onRetry: s.venueCheck == EventPlanCheck.error
                        ? () =>
                            ref.invalidate(selectedBanquetVenueCheckProvider)
                        : null,
                  ),
                const SizedBox(height: AppSizes.lg),
                _StartFreshButton(onTap: () => startFreshFlow(context, ref)),
              ],
            ),
    );
  }
}

/// Destructive footer action — clears the whole plan and the cart after a
/// confirmation that spells out exactly what is (and isn't) removed.
class _StartFreshButton extends StatelessWidget {
  const _StartFreshButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Start fresh'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
      ),
    );
  }
}

/// Headline readiness + progress, driven entirely by the shared summary so it
/// can never contradict the cascade or the live checks.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.summary});
  final EventPlanSummary summary;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (summary.readiness) {
      EventPlanReadiness.ready => (AppColors.success, 'Ready to order'),
      EventPlanReadiness.checking => (AppColors.textMuted, 'Checking…'),
      EventPlanReadiness.needsAttention => (
          AppColors.warning,
          'Needs attention'
        ),
      _ => (AppColors.primary, 'In progress'),
    };

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading2,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.captionBold
                      .copyWith(color: color, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            child: LinearProgressIndicator(
              value: summary.fraction,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          // The plan's CONDITION (not the tap action): the customer is already
          // looking at the plan here, so "add dishes to finalise the menu" is
          // the useful thing to say once everything checks out.
          Text(summary.statusMessage, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.rows,
    this.check,
    this.onRetry,
    this.onEdit,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> rows;

  /// When set, an attention/error state tints the section header.
  final EventPlanCheck? check;

  /// Supplied only for a failed live check — re-runs the lookup.
  final VoidCallback? onRetry;

  /// When set, an "Edit" action opens the owning screen in edit mode. Deferred
  /// sections (location, banquet venue, private-property details) leave this
  /// null and stay read-only.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final needsAttention =
        check == EventPlanCheck.attention || check == EventPlanCheck.error;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: needsAttention ? AppColors.warning : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: needsAttention ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.captionBold.copyWith(
                    color: needsAttention
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    'Retry',
                    style: AppTextStyles.captionBold
                        .copyWith(color: AppColors.primary),
                  ),
                ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  // Style the label directly (not via styleFrom.textStyle),
                  // matching Retry — passing an inherit:true TextStyle to the
                  // button crashes TextStyle.lerp during state animations.
                  label: Text(
                    'Edit',
                    style: AppTextStyles.captionBold
                        .copyWith(color: AppColors.primary),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 32),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    rows[i].$1,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].$2,
                    style: AppTextStyles.body.copyWith(fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
