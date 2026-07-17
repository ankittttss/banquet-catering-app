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
import '../../../data/models/event_category.dart';
import '../../../data/models/event_tier.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/event_tier_providers.dart';
import '../../../shared/providers/home_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../widgets/address_search_sheet.dart';

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
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  String? _categorySlug;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: ref.read(eventDraftProvider).eventName ?? '',
    );
    // Pre-select the occasion the customer chose on the home grid.
    _categorySlug = ref.read(eventDraftProvider).categorySlug;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-fill the event location from the ACTIVE address (the one the
      // customer selected in the home header chip — falls back to their
      // default), carrying its coordinates so the restaurant list can sort
      // nearest to it until the user picks a specific event location.
      // Previously this read the default address, silently disagreeing with
      // the address the rest of the app was using.
      final draft = ref.read(eventDraftProvider);
      if (draft.location == null || draft.location!.trim().isEmpty) {
        final active = ref.read(activeAddressProvider);
        if (active != null) {
          ref.read(eventDraftProvider.notifier).setEventLocation(
                address: active.fullAddress,
                latitude: active.hasCoords ? active.latitude : null,
                longitude: active.hasCoords ? active.longitude : null,
              );
        }
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          ref.read(eventDraftProvider).date ?? now.add(const Duration(days: 3)),
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

  Future<TimeOfDay?> _showBrandTimePicker(TimeOfDay initial) {
    return showTimePicker(
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
  }

  void _timeError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickStartTime() async {
    final draft = ref.read(eventDraftProvider);
    final initial = draft.startTime == null
        ? const TimeOfDay(hour: 19, minute: 0)
        : TimeOfDay.fromDateTime(draft.startTime!);
    final picked = await _showBrandTimePicker(initial);
    if (picked == null || !mounted) return;

    final date = draft.date ?? DateTime.now();
    final start =
        DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
    // A same-day event can't start at a time that's already passed.
    if (!start.isAfter(DateTime.now())) {
      _timeError('That time has already passed — pick a later start time.');
      return;
    }
    // End time auto-follows: the controller preserves the previous duration
    // (or defaults to 3 hours) so end can never land before start.
    ref.read(eventDraftProvider.notifier).setStartTime(start);
  }

  Future<void> _pickEndTime() async {
    final draft = ref.read(eventDraftProvider);
    if (draft.startTime == null) {
      _timeError('Pick the start time first.');
      return;
    }
    final initial = draft.endTime == null
        ? TimeOfDay.fromDateTime(draft.startTime!.add(const Duration(hours: 3)))
        : TimeOfDay.fromDateTime(draft.endTime!);
    final picked = await _showBrandTimePicker(initial);
    if (picked == null || !mounted) return;

    final s = draft.startTime!;
    final end = DateTime(s.year, s.month, s.day, picked.hour, picked.minute);
    if (!end.isAfter(s)) {
      _timeError('End time must be after the start time.');
      return;
    }
    ref.read(eventDraftProvider.notifier).setEndTime(end);
  }

  Future<void> _pickEventLocation() async {
    final res = await AddressSearchSheet.show(context);
    if (res == null || !mounted) return;
    final label = res.displayAddress.trim().isNotEmpty
        ? res.displayAddress
        : (res.shortLabel.trim().isNotEmpty ? res.shortLabel : res.name);
    // Photon results always carry coords; the saved-address fallback may use
    // 0/0 when a saved row has none — treat that as "no coords".
    final hasCoords = res.latitude != 0 || res.longitude != 0;
    ref.read(eventDraftProvider.notifier).setEventLocation(
          address: label,
          latitude: hasCoords ? res.latitude : null,
          longitude: hasCoords ? res.longitude : null,
        );
  }

  void _applyCategory(EventCategory cat) {
    HapticFeedback.selectionClick();
    setState(() => _categorySlug = cat.slug);
    ref.read(eventDraftProvider.notifier).setCategory(cat);
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.userHome),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.lg),
        children: [
          _Section(
            title: 'Event name',
            required: true,
            child: _EventNameField(
              controller: _nameCtrl,
              onChanged: (v) =>
                  ref.read(eventDraftProvider.notifier).setEventName(v),
            ),
          ),
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
            child: _GuestSelector(
              count: draft.guestCount,
              onChanged: (v) =>
                  ref.read(eventDraftProvider.notifier).setGuestCount(v),
            ),
          ),
          _Section(
            title: 'Event location',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PickerRow(
                  icon: Icons.location_on_outlined,
                  value:
                      (draft.location == null || draft.location!.trim().isEmpty)
                          ? 'Add event location'
                          : draft.location!,
                  onTap: _pickEventLocation,
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  'We show restaurants nearest to your event location.',
                  style: AppTextStyles.caption,
                ),
              ],
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
                      ? 'Pick a start time'
                      : 'Starts ${_formatTime(draft.startTime!)}',
                  onTap: _pickStartTime,
                ),
                const SizedBox(height: AppSizes.sm),
                _PickerRow(
                  icon: Icons.schedule_rounded,
                  value: draft.endTime == null
                      ? 'Pick an end time'
                      : 'Ends ${_formatTime(draft.endTime!)}',
                  onTap: _pickEndTime,
                ),
              ],
            ),
          ),
          _Section(
            title: 'Choose a package',
            child: _TierPicker(selectedTierId: draft.tierId),
          ),
          const SizedBox(height: AppSizes.md),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
            child: FilledButton(
              // Every planning essential is now required up front (name,
              // date, start time, location, package) — previously location
              // and time could be skipped and were silently backfilled with
              // defaults at checkout.
              onPressed: (draft.date == null ||
                      draft.startTime == null ||
                      draft.tierId == null ||
                      draft.eventName == null ||
                      draft.eventName!.trim().isEmpty ||
                      draft.location == null ||
                      draft.location!.trim().isEmpty)
                  ? null
                  : () => context.push(AppRoutes.eventVenueType),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
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
  const _Section({
    required this.title,
    required this.child,
    this.required = false,
  });
  final String title;
  final Widget child;

  /// Adds a red asterisk after the title to flag a mandatory field.
  final bool required;

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
          Text.rich(
            TextSpan(
              text: title,
              style: AppTextStyles.heading3,
              children: required
                  ? [
                      TextSpan(
                        text: '  *',
                        style: AppTextStyles.heading3
                            .copyWith(color: AppColors.primary),
                      ),
                    ]
                  : null,
            ),
          ),
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
    final fg = AppColors.fromHex(category.iconHex, fallback: AppColors.primary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? fg.withValues(alpha: 0.12) : AppColors.surfaceAlt,
          border: Border.all(
            color: selected ? fg : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(materialIconByName(category.iconName), color: fg, size: 16),
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

/// Guest-count selector: a tap-to-type number field + a slider, with small
/// ±5 fine-adjust buttons. Replaces the old plus/minus-only stepper the
/// client found hard to use for large guest counts.
class _GuestSelector extends StatefulWidget {
  const _GuestSelector({required this.count, required this.onChanged});
  final int count;
  final ValueChanged<int> onChanged;

  @override
  State<_GuestSelector> createState() => _GuestSelectorState();
}

class _GuestSelectorState extends State<_GuestSelector> {
  static const int _min = 5;
  static const int _max = 5000;
  static const double _sliderMax = 1000;

  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.count}');
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _GuestSelector old) {
    super.didUpdateWidget(old);
    // Reflect external changes (e.g. an event-type preset) unless the user
    // is mid-edit in the field.
    if (!_focus.hasFocus && widget.count != old.count) {
      _ctrl.text = '${widget.count}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_ctrl.text.trim());
    final clamped = (parsed ?? widget.count).clamp(_min, _max);
    _ctrl.text = '$clamped';
    if (clamped != widget.count) widget.onChanged(clamped);
  }

  void _set(int v) {
    final clamped = v.clamp(_min, _max);
    HapticFeedback.selectionClick();
    _ctrl.text = '$clamped';
    if (clamped != widget.count) widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final sliderVal = widget.count.clamp(_min, _sliderMax.toInt()).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 96,
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: AppTextStyles.display.copyWith(
                  fontSize: 24,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
                onEditingComplete: () {
                  _commit();
                  FocusScope.of(context).unfocus();
                },
                onSubmitted: (_) => _commit(),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'guests',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const Spacer(),
            _GuestBtn(
              icon: Icons.remove_rounded,
              onTap: () => _set(widget.count - 5),
            ),
            const SizedBox(width: 8),
            _GuestBtn(
              icon: Icons.add_rounded,
              onTap: () => _set(widget.count + 5),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: sliderVal,
            min: _min.toDouble(),
            max: _sliderMax,
            divisions: ((_sliderMax - _min) / 5).round(),
            label: '${widget.count}',
            onChanged: (v) => _set(v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_min', style: AppTextStyles.caption),
              Text('${_sliderMax.toInt()}+', style: AppTextStyles.caption),
            ],
          ),
        ),
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
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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

// ───────────────────────── Event name field ─────────────────────────

class _EventNameField extends StatefulWidget {
  const _EventNameField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_EventNameField> createState() => _EventNameFieldState();
}

class _EventNameFieldState extends State<_EventNameField> {
  @override
  void initState() {
    super.initState();
    // Rebuild as the user types so the trailing × clear button can
    // appear / disappear based on whether the field has content.
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      textCapitalization: TextCapitalization.words,
      style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
      decoration: InputDecoration(
        hintText: "e.g. Aanya's Sangeet",
        hintStyle: AppTextStyles.body
            .copyWith(color: AppColors.textMuted, fontSize: 15),
        helperText: 'Required · shows on your orders and in operator inboxes',
        helperStyle: AppTextStyles.caption,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        prefixIcon: const Icon(
          Icons.edit_note_rounded,
          color: AppColors.textMuted,
          size: 22,
        ),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
