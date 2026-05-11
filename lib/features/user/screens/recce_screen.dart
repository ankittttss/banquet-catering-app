import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/chef.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/recce_providers.dart';
import '../widgets/plan_flow_chrome.dart';

class RecceScreen extends ConsumerWidget {
  const RecceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(eventDraftProvider);
    final chefs = ref.watch(chefsProvider);
    final days = ref.watch(recceDaysProvider);
    final pick = draft.recce;

    final selectedDay = pick?.day != null
        ? days.firstWhere(
            (d) =>
                d.date.year == pick!.day!.year &&
                d.date.month == pick.day!.month &&
                d.date.day == pick.day!.day,
            orElse: () => days.first,
          )
        : days.firstWhere((d) => !d.isFull, orElse: () => days.first);

    final chefName = pick?.chefId == null
        ? null
        : chefs.firstWhere(
            (c) => c.id == pick!.chefId,
            orElse: () => chefs.first,
          ).name.replaceFirst('Chef ', '');

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PlanFlowHeader(
              title: 'Book a site recce',
              step: 3,
              stepLabel: 'Recce',
              subtitleOverride: 'Chef visits · ~45 min · free',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.sm,
                  AppSizes.pagePadding,
                  AppSizes.md,
                ),
                children: [
                  const _WhyCard(),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel(label: 'PICK YOUR CHEF'),
                  const SizedBox(height: AppSizes.sm),
                  for (final c in chefs) ...[
                    _ChefRow(
                      chef: c,
                      selected: pick?.chefId == c.id,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(eventDraftProvider.notifier)
                            .setRecceChef(c.id);
                      },
                    ),
                    const SizedBox(height: AppSizes.sm),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  const _SectionLabel(label: 'CHOOSE A DAY'),
                  const SizedBox(height: AppSizes.sm),
                  _DayRow(
                    days: days,
                    selected: selectedDay,
                    onPick: (d) {
                      if (d.isFull) return;
                      HapticFeedback.selectionClick();
                      ref
                          .read(eventDraftProvider.notifier)
                          .setRecceDay(d.date);
                    },
                  ),
                  const SizedBox(height: AppSizes.lg),
                  _SectionLabel(
                    label:
                        'AVAILABLE SLOTS — ${_dayHeaderLabel(selectedDay.date)}',
                  ),
                  const SizedBox(height: AppSizes.sm),
                  _SlotGrid(
                    day: selectedDay,
                    selectedSlotLabel:
                        pick?.day != null && _sameDay(pick!.day!, selectedDay.date)
                            ? pick.slotLabel
                            : null,
                    onPick: (slot) {
                      if (slot.isBooked) return;
                      HapticFeedback.selectionClick();
                      ref
                          .read(eventDraftProvider.notifier)
                          .setRecceSlot(slot.label);
                    },
                  ),
                  const SizedBox(height: AppSizes.lg),
                ],
              ),
            ),
            PlanFlowFooter(
              labelLine1: chefName == null
                  ? 'Pick a chef & slot'
                  : 'Confirming with $chefName',
              labelLine2: pick?.isComplete == true
                  ? '${_dayHeaderLabel(pick!.day!)} · ${pick.slotLabel}'
                  : 'Choose your visit time',
              buttonLabel: 'Confirm recce',
              trailingIcon: Icons.check_rounded,
              minButtonWidth: 170,
              onPressed: pick?.isComplete == true
                  ? () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text(
                            'Recce confirmed with $chefName on '
                            '${_dayHeaderLabel(pick!.day!)} · ${pick.slotLabel}',
                          ),
                        ),
                      );
                      final t = DateTime.now().millisecondsSinceEpoch;
                      context.go(
                        '${AppRoutes.userHome}?scrollTo=restaurants&t=$t',
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayHeaderLabel(DateTime d) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

String _weekdayShort(DateTime d) {
  const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return w[d.weekday - 1];
}

// ───────────────────────── Why card ─────────────────────────

class _WhyCard extends StatelessWidget {
  const _WhyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.goldGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHY A RECCE?',
            style: AppTextStyles.captionBold.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "The day goes smoother when we've seen the place",
            style: AppTextStyles.display.copyWith(
              color: Colors.white,
              fontSize: 22,
              height: 1.2,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          const _RecceBullet(
              text: 'Measurements for tent, tables, lighting'),
          const SizedBox(height: AppSizes.sm),
          const _RecceBullet(text: 'Pinpoint power & water before the day'),
          const SizedBox(height: AppSizes.sm),
          const _RecceBullet(text: "Spot anything we'd miss in photos"),
        ],
      ),
    );
  }
}

class _RecceBullet extends StatelessWidget {
  const _RecceBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Section label ─────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.overline.copyWith(
        color: AppColors.accentDark,
        fontSize: 11,
      ),
    );
  }
}

// ───────────────────────── Chef row ─────────────────────────

class _ChefRow extends StatelessWidget {
  const _ChefRow({
    required this.chef,
    required this.selected,
    required this.onTap,
  });

  final Chef chef;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.surfaceAlt,
              child: Text(
                chef.name
                    .replaceFirst('Chef ', '')
                    .split(' ')
                    .where((p) => p.isNotEmpty)
                    .map((p) => p[0])
                    .take(2)
                    .join(),
                style: AppTextStyles.heading2,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chef.name,
                          style: AppTextStyles.heading2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusXs),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              chef.rating.toStringAsFixed(1),
                              style: AppTextStyles.captionBold.copyWith(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chef.headline,
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final tag in chef.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusPill),
                          ),
                          child: Text(
                            tag,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            _Radio(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

// ───────────────────────── Day row ─────────────────────────

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.days,
    required this.selected,
    required this.onPick,
  });

  final List<RecceDay> days;
  final RecceDay selected;
  final ValueChanged<RecceDay> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (_, i) => _DayCard(
          day: days[i],
          isSelected: _sameDay(days[i].date, selected.date),
          onTap: () => onPick(days[i]),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final RecceDay day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isFull = day.isFull;
    final bg = isSelected
        ? AppColors.textPrimary
        : (isFull ? AppColors.surfaceAlt : AppColors.surface);
    final border = isSelected ? AppColors.textPrimary : AppColors.border;
    final fg =
        isSelected ? Colors.white : AppColors.textPrimary;
    return InkWell(
      onTap: isFull ? null : onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _weekdayShort(day.date),
              style: AppTextStyles.bodyBold.copyWith(
                color: fg,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.date.day}',
              style: AppTextStyles.display.copyWith(
                color: fg,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isFull ? 'Full' : '${day.slotsAvailable} slots',
              style: AppTextStyles.caption.copyWith(
                color: isFull
                    ? AppColors.primary
                    : (isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColors.success),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Slot grid ─────────────────────────

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.day,
    required this.selectedSlotLabel,
    required this.onPick,
  });

  final RecceDay day;
  final String? selectedSlotLabel;
  final ValueChanged<RecceSlot> onPick;

  @override
  Widget build(BuildContext context) {
    if (day.slots.isEmpty || day.isFull) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Text(
          day.isFull
              ? 'No more slots on this day. Try another day.'
              : 'No slots yet.',
          style: AppTextStyles.bodyMuted,
        ),
      );
    }
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        for (final s in day.slots)
          _SlotChip(
            slot: s,
            isSelected: !s.isBooked && s.label == selectedSlotLabel,
            onTap: () => onPick(s),
          ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final RecceSlot slot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBooked = slot.isBooked;
    final bg = isBooked
        ? AppColors.primary
        : (isSelected ? AppColors.primary : AppColors.surface);
    final fg = isBooked || isSelected ? Colors.white : AppColors.textPrimary;
    final border = isBooked
        ? AppColors.primary
        : (isSelected ? AppColors.primary : AppColors.border);
    return InkWell(
      onTap: isBooked ? null : onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        constraints: const BoxConstraints(minWidth: 100),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(
          slot.label,
          style: AppTextStyles.bodyBold.copyWith(
            color: fg,
            fontSize: 15,
            decoration:
                isBooked ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
