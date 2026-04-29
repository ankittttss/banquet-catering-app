import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/material_icon_map.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../data/models/event_category.dart';
import '../../../data/models/event_tier.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/event_tier_providers.dart';
import '../../../shared/providers/home_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// Visual accents per tier code — keeps the old package colour/icon palette
/// without having to push those fields into the DB.
class _TierVisual {
  const _TierVisual({
    required this.iconName,
    required this.bgHex,
    required this.iconHex,
  });
  final String iconName;
  final String bgHex;
  final String iconHex;
}

const _tierVisuals = <String, _TierVisual>{
  'budget': _TierVisual(
    iconName: 'rice_bowl',
    bgHex: '#EAFAF1',
    iconHex: '#1BA672',
  ),
  'standard': _TierVisual(
    iconName: 'set_meal',
    bgHex: '#EBF4FF',
    iconHex: '#2B6CB0',
  ),
  'premium': _TierVisual(
    iconName: 'auto_awesome',
    bgHex: '#FFF8E7',
    iconHex: '#E5A100',
  ),
};

const _defaultTierVisual = _TierVisual(
  iconName: 'auto_awesome',
  bgHex: '#FFF8E7',
  iconHex: '#E5A100',
);

class EventDetailsScreen extends ConsumerStatefulWidget {
  const EventDetailsScreen({super.key});

  @override
  ConsumerState<EventDetailsScreen> createState() =>
      _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  String? _categorySlug;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-fill location from default saved address if empty.
      final draft = ref.read(eventDraftProvider);
      if (draft.location == null || draft.location!.trim().isEmpty) {
        final def = ref.read(defaultAddressProvider);
        if (def != null) {
          ref.read(eventDraftProvider.notifier).setLocation(def.fullAddress);
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(eventDraftProvider).date ??
          now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(eventDraftProvider.notifier).setDate(picked);
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final draft = ref.read(eventDraftProvider);
    final initial = draft.startTime == null
        ? const TimeOfDay(hour: 19, minute: 0)
        : TimeOfDay.fromDateTime(draft.startTime!);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final date = draft.date ?? now;
      final start = DateTime(
        date.year,
        date.month,
        date.day,
        picked.hour,
        picked.minute,
      );
      ref.read(eventDraftProvider.notifier).setStartTime(start);
      // Default 3-hour duration if end not set.
      if (draft.endTime == null) {
        ref
            .read(eventDraftProvider.notifier)
            .setEndTime(start.add(const Duration(hours: 3)));
      }
    }
  }

  void _applyCategory(EventCategory cat) {
    HapticFeedback.selectionClick();
    setState(() => _categorySlug = cat.slug);
    ref.read(eventDraftProvider.notifier).setSession(cat.defaultSession);
    ref
        .read(eventDraftProvider.notifier)
        .setGuestCount(cat.defaultGuestCount);
  }

  void _bumpGuests(int delta) {
    final draft = ref.read(eventDraftProvider);
    final next = (draft.guestCount + delta).clamp(5, 5000);
    ref.read(eventDraftProvider.notifier).setGuestCount(next);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(eventDraftProvider);
    final cats = ref.watch(eventCategoriesProvider).valueOrNull ?? const [];

    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: const Text('Plan your event'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.userHome),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _Section(
            title: 'Event type',
            child: _CategoryGrid(
              categories: cats,
              selectedSlug: _categorySlug,
              onSelect: _applyCategory,
            ),
          ),
          _Section(
            title: 'Number of guests',
            child: _GuestCounter(
              count: draft.guestCount,
              onMinus: () => _bumpGuests(-5),
              onPlus: () => _bumpGuests(5),
            ),
          ),
          _Section(
            title: 'Date & time',
            child: Column(
              children: [
                _PickerRow(
                  icon: Icons.calendar_today_rounded,
                  value: draft.date == null
                      ? 'Pick a date'
                      : Formatters.date(draft.date!),
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSizes.sm),
                _PickerRow(
                  icon: Icons.schedule_rounded,
                  value: draft.startTime == null
                      ? 'Pick a time'
                      : _formatTime(draft.startTime!),
                  onTap: _pickTime,
                ),
              ],
            ),
          ),
          _Section(
            title: 'Choose a package',
            child: _TierPicker(selectedTierId: draft.tierId),
          ),
          _Section(
            title: 'Banquet venue (optional)',
            child: _VenuePicker(
              selectedVenueId: draft.banquetVenueId,
              selectedVenueName: draft.banquetVenueName,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
            child: FilledButton(
              onPressed: (draft.date == null || draft.tierId == null)
                  ? null
                  : () => context.go(AppRoutes.userHome),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Browse restaurants',
                    style: AppTextStyles.buttonLabel
                        .copyWith(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final am = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }
}

// ───────────────────────── Section ─────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        0,
      ),
      padding: const EdgeInsets.all(AppSizes.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.heading3),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    ).animate().fadeIn(duration: 240.ms);
  }
}

// ───────────────────────── Category chips ─────────────────────────

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedSlug,
    required this.onSelect,
  });

  final List<EventCategory> categories;
  final String? selectedSlug;
  final ValueChanged<EventCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        for (final c in categories)
          _CategoryChip(
            category: c,
            selected: c.slug == selectedSlug,
            onTap: () => onSelect(c),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final EventCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.fromHex(category.iconHex,
        fallback: AppColors.primary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? fg.withValues(alpha: 0.12)
              : AppColors.surfaceAlt,
          border: Border.all(
            color: selected ? fg : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(materialIconByName(category.iconName),
                color: fg, size: 16),
            const SizedBox(width: 6),
            Text(
              category.name,
              style: AppTextStyles.captionBold.copyWith(
                color: selected ? fg : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Guest counter ─────────────────────────

class _GuestCounter extends StatelessWidget {
  const _GuestCounter({
    required this.count,
    required this.onMinus,
    required this.onPlus,
  });
  final int count;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GuestBtn(icon: Icons.remove_rounded, onTap: onMinus),
        Expanded(
          child: Center(
            child: Text(
              '$count',
              style: AppTextStyles.display.copyWith(
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        _GuestBtn(icon: Icons.add_rounded, onTap: onPlus),
      ],
    );
  }
}

class _GuestBtn extends StatelessWidget {
  const _GuestBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.textSecondary),
      ),
    );
  }
}

// ───────────────────────── Picker row ─────────────────────────

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 20),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(value, style: AppTextStyles.body)),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Tier picker ─────────────────────────

class _TierPicker extends ConsumerWidget {
  const _TierPicker({required this.selectedTierId});
  final String? selectedTierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiersAsync = ref.watch(eventTiersProvider);
    final tiers = tiersAsync.valueOrNull ?? const <EventTier>[];

    if (tiers.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Default-select the first tier if the draft doesn't carry one yet, so
    // the "Browse restaurants" button unlocks as soon as date is set.
    if (selectedTierId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final first = tiers.first;
        ref
            .read(eventDraftProvider.notifier)
            .setTier(tierId: first.id, tierCode: first.code);
      });
    }

    return Column(
      children: [
        for (final t in tiers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: _TierCard(
              tier: t,
              selected: t.id == selectedTierId,
              onTap: () {
                HapticFeedback.selectionClick();
                ref
                    .read(eventDraftProvider.notifier)
                    .setTier(tierId: t.id, tierCode: t.code);
              },
            ),
          ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.selected,
    required this.onTap,
  });
  final EventTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _tierVisuals[tier.code] ?? _defaultTierVisual;
    final bg = AppColors.fromHex(visual.bgHex);
    final fg = AppColors.fromHex(visual.iconHex, fallback: AppColors.accent);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(materialIconByName(visual.iconName),
                  color: fg, size: 24),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tier.label, style: AppTextStyles.bodyBold),
                  if (tier.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      tier.description!,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '₹${tier.perGuestMin.toStringAsFixed(0)}–${tier.perGuestMax.toStringAsFixed(0)}/guest',
                    style: AppTextStyles.bodyBold
                        .copyWith(color: AppColors.primary, fontSize: 14),
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

// ───────────────────────── Venue picker ─────────────────────────

class _VenuePicker extends ConsumerWidget {
  const _VenuePicker({
    required this.selectedVenueId,
    required this.selectedVenueName,
  });
  final String? selectedVenueId;
  final String? selectedVenueName;

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _VenueSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelection =
        selectedVenueId != null && selectedVenueId!.isNotEmpty;
    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.apartment_rounded,
                color: AppColors.textMuted, size: 20),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                hasSelection
                    ? selectedVenueName ?? 'Venue selected'
                    : 'Pick a venue (route to a banquet operator)',
                style: AppTextStyles.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _VenueSheet extends ConsumerWidget {
  const _VenueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(allBanquetVenuesProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a banquet venue', style: AppTextStyles.display),
            const SizedBox(height: AppSizes.xs),
            Text(
              "Your booking is routed to this venue's operator for confirmation.",
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.lg),
            Expanded(
              child: venues.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Could not load venues: $e',
                    style: AppTextStyles.caption),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        'No venues available yet.',
                        style: AppTextStyles.bodyMuted,
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (_, i) {
                      final v = rows[i];
                      return _VenueRow(
                        venue: v,
                        onTap: () {
                          ref
                              .read(eventDraftProvider.notifier)
                              .setBanquetVenue(
                                venueId: v.id,
                                venueName: v.name,
                              );
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.venue, required this.onTap});
  final BanquetVenue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.apartment_rounded,
                  color: AppColors.primary),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: AppTextStyles.bodyBold),
                  if (venue.address != null) ...[
                    const SizedBox(height: 2),
                    Text(venue.address!,
                        style: AppTextStyles.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                  if (venue.capacity != null) ...[
                    const SizedBox(height: 2),
                    Text('Up to ${venue.capacity} guests',
                        style: AppTextStyles.captionBold
                            .copyWith(color: AppColors.primary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
