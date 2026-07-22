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
import '../../../shared/providers/cart_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/providers/event_tier_providers.dart';
import '../../../shared/providers/home_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../location_change.dart';
import '../plan_edit_context.dart';
import '../plan_edit_flows.dart';
import '../planning_next_step.dart';
import '../planning_session.dart';

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

  /// Anchor for scroll-to-package when opened via `section=package`.
  final _packageKey = GlobalKey();

  /// One-shot guard so the edit-mode scroll fires exactly once.
  bool _didEditScroll = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: ref.read(eventDraftProvider).eventName ?? '',
    );
    // Pre-select the occasion the customer chose on the home grid.
    _categorySlug = ref.read(eventDraftProvider).categorySlug;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // In edit mode the plan already has a location — never auto-prefill it
      // (that would be a silent mutation the moment the customer opens an
      // edit). Prefill only happens during first-time forward planning.
      final edit = PlanEditContext.of(
        GoRouterState.of(context),
        PlanEditScreen.eventDetails,
      );
      if (edit.isEditing) return;
      // Pre-fill the event location from the ACTIVE address (the one the
      // customer selected in the home header chip), but ONLY when doing so is
      // genuinely consequence-free. An automatic write must never be a silent
      // location change:
      //  • it needs a real pin — a coordinate-less address can't be verified
      //    against any kitchen, and writing it would strand the plan with an
      //    unserviceable location;
      //  • it must not touch location-dependent state — setEventLocation
      //    clears a selected venue and the property address;
      //  • it must not invalidate a cart the customer already built.
      // When any of those apply we leave the location UNSET, so the customer
      // sets it deliberately through the transactional flow.
      final draft = ref.read(eventDraftProvider);
      final locationEmpty =
          draft.location == null || draft.location!.trim().isEmpty;
      if (!locationEmpty) return;

      final active = ref.read(activeAddressProvider);
      if (active == null) return;
      if (!hasUsableCoords(active.latitude, active.longitude)) return;
      if (draft.banquetVenueId != null) return;
      if (eventLocationChangeClearsProperty(draft)) return;
      if (ref.read(cartProvider).isNotEmpty) return;

      ref.read(eventDraftProvider.notifier).setEventLocation(
            address: active.fullAddress,
            latitude: active.latitude,
            longitude: active.longitude,
          );
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // Bounds run on the IST business clock (like all schedule rules), and
    // the initial value is clamped into [first, last] — a restored draft
    // with a stale past date used to violate the picker's assertion.
    final first = istToday();
    final last = first.add(const Duration(days: 365));
    var initial =
        ref.read(eventDraftProvider).date ?? first.add(const Duration(days: 3));
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
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

    final date = draft.date ?? istToday();
    final start =
        DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
    // A same-day event can't start at a time that's already passed — judged
    // on the IST business clock (matches the cascade and place_order),
    // never the device's timezone.
    if (!start.isAfter(nowInIst())) {
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

  /// Change the event location through the ONE transactional flow.
  ///
  /// This screen is reachable from Home, Cart and Checkout with a live cart and
  /// plan, so it must not write the location directly: the flow validates the
  /// pin, previews which cart lines / venue / property details the move
  /// invalidates, and applies only on confirmation. A fresh plan has no
  /// consequences, so it still applies immediately.
  Future<void> _pickEventLocation() => changeEventLocationFlow(context, ref);

  void _applyCategory(EventCategory cat) {
    HapticFeedback.selectionClick();
    setState(() => _categorySlug = cat.slug);
    ref.read(eventDraftProvider.notifier).setCategory(cat);
  }

  /// Bring the package section into view (called after tiers load). Fires once.
  void _scrollToPackage() {
    if (_didEditScroll) return;
    final ctx = _packageKey.currentContext;
    if (ctx == null) return; // not laid out yet — a later frame retries
    _didEditScroll = true;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  /// Visually mutes [child] while editing. The actual interaction guard is the
  /// NULL callback passed into the child (occasion/location), which removes the
  /// tap action for pointer, keyboard AND semantics — an IgnorePointer here
  /// would only stop the pointer.
  Widget _mutedInEdit(bool editing, Widget child) =>
      editing ? Opacity(opacity: 0.55, child: child) : child;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(eventDraftProvider);
    final catsAsync = ref.watch(eventCategoriesProvider);
    // THE shared cascade — drives the Continue button state and the hint
    // under it, so this screen agrees with the home card, checkout and the
    // server about what "complete" means.
    final step = planningNextStep(draft);
    // On top of the cascade, Continue requires the tier list to have
    // actually LOADED (non-empty) with a selection that resolves against
    // it — loading, error, empty, or a stale/deactivated selection must
    // not allow navigation. The picker auto-replaces invalid selections
    // when data lands; this gate covers the window before/without that.
    final tiersAsync = ref.watch(eventTiersProvider);
    final activeTiers = tiersAsync.valueOrNull ?? const <EventTier>[];
    final tierResolved = resolveSelectedTier(activeTiers, draft.tierId) != null;
    String? tierBlock;
    if (step.route != AppRoutes.eventDetails && !tierResolved) {
      tierBlock = tiersAsync.isLoading
          ? 'Loading packages…'
          : tiersAsync.hasError
              ? "Couldn't load packages — use Retry in the package section"
              : activeTiers.isEmpty
                  ? 'No packages available yet'
                  : 'Pick a package for your event';
    }
    final blockedHint =
        step.route == AppRoutes.eventDetails ? step.hint : tierBlock;

    // Strict, screen-aware edit context: only source=eventPlan + section
    // event|package activates edit mode here; anything else is normal mode.
    final edit = PlanEditContext.of(
      GoRouterState.of(context),
      PlanEditScreen.eventDetails,
    );
    // Bring the package section into view once tiers have loaded (its height
    // is only correct after the async content lands). Runs at most once.
    if (edit.section == EditSection.package &&
        !_didEditScroll &&
        tiersAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPackage());
    }

    return PopScope(
      // In edit mode, intercept OS/system back so it returns to the Event Plan
      // for a DIRECT deep link too (a pushed edit already pops there). Normal
      // mode keeps the default back behaviour.
      canPop: !edit.isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) returnFromEdit(context);
      },
      child: AppScaffold(
        padded: false,
        appBar: AppBar(
          title: Text(edit.isEditing ? 'Edit event' : 'Plan your event'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            // Edit mode returns to the Event Plan (pop, or go there on a deep
            // link) and keeps the already-applied edits; normal mode keeps the
            // existing back-to-home fallback.
            onPressed: () => edit.isEditing
                ? returnFromEdit(context)
                : (context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.userHome)),
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
              child: catsAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
                // Honest failure state — previously loading, error and empty
                // all rendered the same endless spinner.
                error: (_, __) => _InlineLoadError(
                  message: "Couldn't load occasions",
                  onRetry: () => ref.invalidate(eventCategoriesProvider),
                ),
                data: (cats) => cats.isEmpty
                    ? Text(
                        'No occasions available yet.',
                        style: AppTextStyles.caption,
                      )
                    // Occasion is READ-ONLY in edit mode: setCategory silently
                    // rewrites session + guest count, which can invalidate the
                    // venue/cart — deferred to Phase 3. A null onSelect removes
                    // the tap action for pointer, keyboard AND semantics.
                    : _mutedInEdit(
                        edit.isEditing,
                        _CategoryGrid(
                          categories: cats,
                          selectedSlug: _categorySlug,
                          onSelect: edit.isEditing ? null : _applyCategory,
                        ),
                      ),
              ),
            ),
            _Section(
              title: 'Session',
              required: true,
              child: _SessionChips(
                selected: draft.session,
                onSelect: (s) {
                  HapticFeedback.selectionClick();
                  ref.read(eventDraftProvider.notifier).setSession(s);
                },
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
                  // Location change is READ-ONLY in edit mode: it drives
                  // discovery/serviceability and needs the Phase 3 candidate +
                  // cart-impact preflight before it may mutate. A null onTap
                  // removes the tap action for pointer, keyboard AND semantics.
                  _mutedInEdit(
                    edit.isEditing,
                    _PickerRow(
                      icon: Icons.location_on_outlined,
                      onTap: edit.isEditing ? null : _pickEventLocation,
                      value: (draft.location == null ||
                              draft.location!.trim().isEmpty)
                          ? 'Add event location'
                          : draft.location!,
                    ),
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
              key: _packageKey,
              title: 'Choose a package',
              child: _TierPicker(
                selectedTierId: draft.tierId,
                editing: edit.isEditing,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    // Edit mode: "Done" always returns to the Event Plan (edits
                    // are already applied). Normal mode: the shared-cascade +
                    // loaded-tier gate, unchanged.
                    onPressed: edit.isEditing
                        ? () => returnFromEdit(context)
                        : (blockedHint != null ? null : _onContinue),
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
                          edit.isEditing ? 'Done' : 'Continue',
                          style: AppTextStyles.buttonLabel.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.0,
                          ),
                        ),
                        if (!edit.isEditing) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // The blocked hint is a normal-mode affordance; Done never
                  // blocks, so it's hidden in edit mode.
                  if (!edit.isEditing && blockedHint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSizes.sm),
                      child: Text(
                        blockedHint,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Continue: commit any mid-edit guest input (blur), then re-read the
  /// LATEST draft and follow the cascade's route — never a step computed
  /// before the commit. Fully planned drafts skip straight to restaurant
  /// browsing; otherwise the next branch screen opens.
  void _onContinue() {
    FocusManager.instance.primaryFocus?.unfocus();
    final latest = ref.read(eventDraftProvider);
    final step = planningNextStep(latest);
    if (step.route == AppRoutes.eventDetails) {
      // A field changed between build and tap (e.g. guest edit committed to
      // an out-of-range value) — surface the reason, stay here.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(step.hint), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    // Re-verify the tier against the LOADED active list at tap time — the
    // build-time gate normally prevents reaching here otherwise, but the
    // state can change between frames.
    final tiers =
        ref.read(eventTiersProvider).valueOrNull ?? const <EventTier>[];
    if (resolveSelectedTier(tiers, latest.tierId) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a package for your event before continuing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    if (step.route == AppRoutes.userHome) {
      final t = DateTime.now().millisecondsSinceEpoch;
      context.push('${AppRoutes.userHome}?scrollTo=restaurants&t=$t');
      return;
    }
    context.push(step.route);
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
    super.key,
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

// ───────────────────────── Session chips ─────────────────────────

/// Required session selection. A category pre-seeds its default session,
/// but the customer can always change it here — previously session was ONLY
/// ever set implicitly by picking a category and had no UI of its own.
class _SessionChips extends StatelessWidget {
  const _SessionChips({required this.selected, required this.onSelect});

  static const sessions = ['Lunch', 'High Tea', 'Dinner'];

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.sm,
      children: [
        for (final s in sessions)
          InkWell(
            onTap: () => onSelect(s),
            borderRadius: BorderRadius.circular(AppSizes.radiusPill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: BoxDecoration(
                color: s == selected ? AppColors.primary : AppColors.surfaceAlt,
                border: Border.all(
                  color: s == selected ? AppColors.primary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
              ),
              child: Text(
                s,
                style: AppTextStyles.bodyBold.copyWith(
                  color: s == selected ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Inline load error ─────────────────────────

/// Compact in-section failure row: message + Retry. Keeps the section
/// visible and recoverable instead of an endless spinner.
class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSizes.sm),
          Expanded(child: Text(message, style: AppTextStyles.caption)),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
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

  /// Null disables selection (read-only edit gate) — the chips expose no tap
  /// action to pointer, keyboard or semantics.
  final ValueChanged<EventCategory>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final select = onSelect;
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        for (final c in categories)
          _CategoryChip(
            category: c,
            selected: c.slug == selectedSlug,
            onTap: select == null ? null : () => select(c),
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

  /// Null disables the chip (read-only edit gate).
  final VoidCallback? onTap;

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
  // Product guest range — shared with the validation cascade and mirrored
  // by place_order, so the field, the gate and the server agree.
  static const int _min = kGuestMin;
  static const int _max = kGuestMax;
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
                // Commit every parseable keystroke so the DRAFT can never
                // lag the visible value (Continue validates the draft).
                // No clamping mid-typing — rewriting text under the cursor
                // is hostile; blur/submit normalises. Empty or partial
                // input simply leaves the draft at its last valid value,
                // and blur snaps the text back to it.
                onChanged: (v) {
                  final parsed = int.tryParse(v.trim());
                  if (parsed != null && parsed != widget.count) {
                    widget.onChanged(parsed);
                  }
                },
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

  /// Null disables the row entirely — InkWell exposes no tap action to
  /// pointer, keyboard or semantics (used for the read-only edit gate).
  final VoidCallback? onTap;

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
  const _TierPicker({required this.selectedTierId, this.editing = false});
  final String? selectedTierId;

  /// In edit mode the package is NEVER auto-selected/reconciled — that would
  /// silently mutate the plan just by opening an edit. The list renders with
  /// nothing selected until the customer taps; Done may return with the
  /// package still needing attention. Normal planning keeps the auto-select.
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiersAsync = ref.watch(eventTiersProvider);
    return tiersAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      // Honest failure state with Retry — the old silent fallback list
      // carried non-UUID tier ids that the live database rejects.
      error: (_, __) => _InlineLoadError(
        message: "Couldn't load packages",
        onRetry: () => ref.invalidate(eventTiersProvider),
      ),
      data: (tiers) {
        if (tiers.isEmpty) {
          return Text(
            'No packages available yet — please check back soon.',
            style: AppTextStyles.caption,
          );
        }
        // Resolve the draft's selection against the ACTIVE list. Null means
        // unselected OR invalid — a persisted draft may still carry a
        // legacy fallback id ('budget'/'standard'/'premium') or a tier that
        // was deactivated since.
        //
        // In NORMAL planning, a null result is replaced with the first active
        // tier so the selected card is always real and visible and Continue
        // can never proceed on an invisible, invalid tier. In EDIT mode this
        // auto-replacement is suppressed (see below): opening an edit must
        // never silently change the package.
        final selected = resolveSelectedTier(tiers, selectedTierId);
        // Auto-select a valid default ONLY in normal planning. In edit mode a
        // missing/invalid/deactivated selection is left as-is (nothing shown
        // selected) so opening an edit never silently changes the package.
        if (selected == null && !editing) {
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
                  selected: t.id == selected?.id,
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
      },
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
