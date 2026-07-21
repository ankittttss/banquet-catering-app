import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/photon_geocoder.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../data/models/venue_type.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../plan_edit_context.dart';
import '../plan_edit_flows.dart';
import '../planning_next_step.dart';
import '../widgets/plan_flow_chrome.dart';

/// Best-effort background lookup for a venue saved WITHOUT coordinates:
/// geocode its address (falling back to its name) and pin the point onto the
/// draft. The notifier is captured up front so this outlives the picker
/// sheet; [EventDraftController.pinVenueCoords] ignores the result if the
/// user changed venue meanwhile. Failures are silent — the restaurant list
/// then shows the honest popularity sort instead of a wrong location.
Future<void> _geocodeVenueCoords(
  EventDraftController notifier,
  BanquetVenue venue,
) async {
  final query = (venue.address?.trim().isNotEmpty ?? false)
      ? venue.address!.trim()
      : venue.name;
  final geocoder = PhotonGeocoder();
  try {
    final results = await geocoder.search(query, limit: 1);
    if (results.isEmpty) return;
    notifier.pinVenueCoords(
      venueId: venue.id,
      latitude: results.first.latitude,
      longitude: results.first.longitude,
    );
  } catch (_) {
    // Best effort only.
  } finally {
    geocoder.dispose();
  }
}

/// Open the banquet picker. On a fresh pick with [proceedOnPick] the flow
/// continues straight to the restaurant browser; when re-opened via
/// "Change venue" ([proceedOnPick] = false) it just returns, and
/// [selectedBanquetVenueCheckProvider] re-validates the new choice.
Future<void> _openBanquetPicker(
  BuildContext context,
  WidgetRef ref, {
  required bool proceedOnPick,
  bool editReturn = false,
}) async {
  final picked = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BanquetPickerSheet(returnSelection: editReturn),
  );
  if (!context.mounted) return;
  if (picked == _BanquetPickerSheet.changeLocationResult) {
    // Run the SAME transactional location change as everywhere else (candidate
    // → impact preview → confirm). Jumping to Event Details here used to
    // bypass it, letting the location mutate with no cart/venue impact check.
    final changed = await changeEventLocationFlow(context, ref);
    if (!context.mounted || !changed) return;
    // A confirmed new location clears the venue, so reopen the picker to
    // choose a hall near it.
    await _openBanquetPicker(
      context,
      ref,
      proceedOnPick: proceedOnPick,
      editReturn: editReturn,
    );
    return;
  }
  // Edit mode: the sheet RETURNS the chosen venue instead of applying it, so
  // the new hall is checked against the cart and confirmed BEFORE any mutation
  // (no partial state — the transactional rule).
  if (editReturn) {
    if (picked is! BanquetVenue) return; // dismissed without picking
    final applied = await applyChosenVenueInEdit(
      context,
      ref,
      venueId: picked.id,
      venueName: picked.name,
      address: picked.address,
      latitude: picked.latitude,
      longitude: picked.longitude,
      capacity: picked.capacity,
    );
    if (!context.mounted || !applied) return;
    // Venue without a pin? Recover it from the address in the background.
    if (picked.latitude == null || picked.longitude == null) {
      unawaited(
        _geocodeVenueCoords(ref.read(eventDraftProvider.notifier), picked),
      );
    }
    returnFromEdit(context);
    return;
  }
  if (picked != true) return; // dismissed without picking
  if (proceedOnPick) {
    // Push (not go) so the planning steps stay on the back stack.
    final t = DateTime.now().millisecondsSinceEpoch;
    context.push('${AppRoutes.userHome}?scrollTo=restaurants&t=$t');
  }
}

/// Apply a venue-type selection. In edit mode a switch that would discard data
/// (a selected hall, or property details + setup add-ons) is confirmed first,
/// spelling out exactly what clears; in normal planning it applies immediately.
Future<void> _selectVenueType(
  BuildContext context,
  WidgetRef ref,
  bool editing,
  VenueType target,
) async {
  HapticFeedback.selectionClick();
  final draft = ref.read(eventDraftProvider);
  if (draft.venueType == target) return; // re-tapping the current type: no-op
  final notifier = ref.read(eventDraftProvider.notifier);

  if (!editing) {
    notifier.setVenueType(target);
    return;
  }

  // Spell out what switching discards (setVenueType clears the other branch).
  final clears = <String>[];
  final losesHallLocation =
      target == VenueType.privateProperty && draft.banquetVenueId != null;
  if (target == VenueType.privateProperty) {
    if (losesHallLocation) {
      // The hall WAS the event location, so both go — say so plainly.
      clears.add(
        'your selected banquet venue'
        '${draft.banquetVenueName != null ? ' (${draft.banquetVenueName})' : ''}',
      );
      clears.add('the event location it set');
    }
  } else {
    final p = draft.propertyDraft;
    final hasPropertyDetails = p != null &&
        (p.type != null ||
            (p.addressLine1?.trim().isNotEmpty ?? false) ||
            (p.landmark?.trim().isNotEmpty ?? false) ||
            (p.cityPincode?.trim().isNotEmpty ?? false));
    if (hasPropertyDetails) clears.add('your private-property details');
    if (draft.addonQuantities.isNotEmpty) {
      clears.add('your setup & equipment add-ons');
    }
  }

  if (clears.isEmpty) {
    notifier.setVenueType(target); // nothing to lose
    _afterSwitch(context, target, losesHallLocation);
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Switch to ${target.label.toLowerCase()}?'),
      content: Text(
        'This will clear ${_joinClauses(clears)}.'
        // The cart is deliberately left alone here: it is re-checked against
        // the NEW location by the transactional flow once one is picked.
        '${losesHallLocation ? "\n\nYou'll pick your property's location next — "
            "your cart stays until then, and we'll check it against the new "
            "location." : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Switch'),
        ),
      ],
    ),
  );
  // Cancel preserves the complete banquet plan untouched.
  if (confirmed != true || !context.mounted) return;
  notifier.setVenueType(target);
  _afterSwitch(context, target, losesHallLocation);
}

/// After switching to private property from a selected hall the plan has NO
/// location left, so send the customer straight to the property step where a
/// new pinned location is required before it can complete.
///
/// REPLACE (not push): the venue screen is now describing a choice that no
/// longer applies, so leaving it underneath would make Back from the property
/// step land on a stale banquet screen — and a second "back" would then reach
/// the plan, duplicating it. With a replacement, Done / AppBar back / system
/// back all resolve to exactly one Event Plan, whether the venue step was
/// pushed from the plan or entered directly.
void _afterSwitch(BuildContext context, VenueType target, bool lostLocation) {
  if (!lostLocation || target != VenueType.privateProperty) return;
  if (!context.mounted) return;
  context.pushReplacement(PlanEditContext.editProperty());
}

String _joinClauses(List<String> items) => items.length == 1
    ? items.first
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

class VenueTypeScreen extends ConsumerWidget {
  const VenueTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(eventDraftProvider);
    final edit = PlanEditContext.of(
      GoRouterState.of(context),
      PlanEditScreen.venueType,
    );

    // Prerequisite guard (screen-level, reusing the shared planning cascade
    // to avoid router redirect-loops): the venue step needs a complete Event
    // Details section. When planningNextStep still points back to Event
    // Details, that section is incomplete — gate here rather than let the
    // customer pick a venue for a half-planned event.
    final step = planningNextStep(draft);
    if (step.route == AppRoutes.eventDetails) {
      return _IncompleteDetailsView(hint: step.hint);
    }

    final selected = draft.venueType;
    final hasVenue = draft.banquetVenueId != null;
    final venueCheck = selected == VenueType.banquetHall
        ? ref.watch(selectedBanquetVenueCheckProvider)
        : null;

    // Continue is enabled for: private property; banquet with no venue yet
    // (Continue opens the picker); or banquet with a live VALID venue. It is
    // blocked while checking, on a check error, or when the selection is too
    // small / unavailable — the summary card drives re-selection there.
    final bool canContinue;
    if (selected == null) {
      canContinue = false;
    } else if (selected == VenueType.privateProperty) {
      canContinue = true;
    } else if (!hasVenue) {
      canContinue = true;
    } else {
      canContinue = venueCheck!.maybeWhen(
        data: (c) => c.state == VenueCheckState.valid,
        orElse: () => false,
      );
    }

    Future<void> onContinue() async {
      HapticFeedback.lightImpact();
      if (selected == VenueType.privateProperty) {
        // Edit mode: continue into property details (which returns to the plan
        // when done); normal mode pushes the next planning step.
        context.push(
          edit.isEditing
              ? PlanEditContext.editProperty()
              : AppRoutes.eventProperty,
        );
        return;
      }
      // Banquet: no venue yet → open the picker. In edit mode the pick is
      // impact-checked and returns to the plan; normal mode proceeds forward.
      if (!hasVenue) {
        await _openBanquetPicker(
          context,
          ref,
          proceedOnPick: !edit.isEditing,
          editReturn: edit.isEditing,
        );
        return;
      }
      // Banquet with a valid venue: edit mode is done → back to the plan;
      // normal mode goes to the restaurant browser.
      if (edit.isEditing) {
        returnFromEdit(context);
        return;
      }
      final t = DateTime.now().millisecondsSinceEpoch;
      context.push('${AppRoutes.userHome}?scrollTo=restaurants&t=$t');
    }

    return PopScope(
      // Edit mode: system/OS back returns to the Event Plan (pop when pushed,
      // go on a direct deep link). Normal mode keeps default back.
      canPop: !edit.isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) returnFromEdit(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceWarm,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              PlanFlowHeader(
                title: edit.isEditing ? 'Edit venue' : "Where's the event?",
                stepLabel: 'Venue',
                onBack: edit.isEditing ? () => returnFromEdit(context) : null,
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
                    Text(
                      'Hall or your place?',
                      style: AppTextStyles.display.copyWith(
                        fontSize: 28,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      'Both work for any tier. Private property unlocks setup & equipment.',
                      style: AppTextStyles.bodyMuted.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: AppSizes.xl),
                    _VenueCard(
                      type: VenueType.banquetHall,
                      selected: selected == VenueType.banquetHall,
                      title: 'Banquet hall',
                      subtitle: 'A curated venue from our network',
                      overline: 'EASIEST · A VENUE FROM OUR NETWORK',
                      overlineColor: AppColors.primary,
                      accentColor: AppColors.primary,
                      // Honest, workflow-backed value props only: the hall fee
                      // is a real charge in place_order; the venue is the event
                      // location, so the catering is delivered there; the
                      // booking is routed to the venue operator for confirmation;
                      // service staff are an add-on. (We deliberately avoid
                      // "no equipment to rent" — the app simply has no banquet
                      // equipment add-on flow; that doesn't guarantee any given
                      // hall provides equipment.)
                      bullets: const [
                        'Hall fee in your quote',
                        'We deliver to the venue',
                        'Operator-confirmed booking',
                        'Add service staff',
                      ],
                      imageUrl:
                          'https://images.unsplash.com/photo-1530023367847-a683933f4172?auto=format&fit=crop&w=900&q=80',
                      fallbackTint: AppColors.primarySoft,
                      onTap: () => _selectVenueType(
                        context,
                        ref,
                        edit.isEditing,
                        VenueType.banquetHall,
                      ),
                    ),
                    if (selected == VenueType.banquetHall && hasVenue) ...[
                      const SizedBox(height: AppSizes.md),
                      _SelectedVenueCard(
                        check: venueCheck!,
                        guestCount: draft.guestCount,
                        onChange: () => _openBanquetPicker(
                          context,
                          ref,
                          proceedOnPick: false,
                          editReturn: edit.isEditing,
                        ),
                        onRetry: () =>
                            ref.invalidate(selectedBanquetVenueCheckProvider),
                      ),
                    ],
                    const SizedBox(height: AppSizes.lg),
                    _VenueCard(
                      type: VenueType.privateProperty,
                      selected: selected == VenueType.privateProperty,
                      title: 'Private property',
                      subtitle: 'Your home, farmhouse, terrace, lawn',
                      overline: 'MOST PERSONAL · HOSTED AT YOUR PLACE',
                      overlineColor: AppColors.success,
                      accentColor: AppColors.success,
                      badgeLabel: 'NEW · MOST FLEXIBLE',
                      bullets: const [
                        'Hosted at your place',
                        'Setup & equipment add-ons',
                        'Add service staff',
                      ],
                      imageUrl:
                          'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=900&q=80',
                      fallbackTint: AppColors.catGreenLt,
                      onTap: () => _selectVenueType(
                        context,
                        ref,
                        edit.isEditing,
                        VenueType.privateProperty,
                      ),
                    ),
                    const SizedBox(height: AppSizes.lg),
                  ],
                ),
              ),
              PlanFlowFooter(
                labelLine1: selected == null ? 'Pick one' : 'You picked',
                labelLine2: selected == null
                    ? 'Hall or private property'
                    : selected.label,
                buttonLabel: edit.isEditing &&
                        selected == VenueType.banquetHall &&
                        hasVenue
                    ? 'Done'
                    : 'Continue',
                onPressed: canContinue ? () => onContinue() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────── Selected banquet venue (live re-validated) ─────────────────

class _SelectedVenueCard extends StatelessWidget {
  const _SelectedVenueCard({
    required this.check,
    required this.guestCount,
    required this.onChange,
    required this.onRetry,
  });

  final AsyncValue<VenueCheck> check;
  final int guestCount;
  final VoidCallback onChange;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return check.when(
      loading: () => _Shell(
        borderColor: AppColors.border,
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSizes.md),
            Text('Checking your venue…', style: AppTextStyles.body),
          ],
        ),
      ),
      error: (_, __) => _Warn(
        color: AppColors.error,
        icon: Icons.wifi_off_rounded,
        title: "Couldn't verify this venue",
        body: 'Check your connection and try again — you can continue once '
            "it's confirmed.",
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
      data: (c) {
        switch (c.state) {
          case VenueCheckState.none:
            return const SizedBox.shrink();
          case VenueCheckState.valid:
            return _ValidVenue(venue: c.venue!, onChange: onChange);
          case VenueCheckState.tooSmall:
            final cap = c.venue?.capacity;
            return _Warn(
              color: AppColors.accentDark,
              icon: Icons.groups_rounded,
              title: 'This venue no longer fits your guests',
              body: cap == null
                  ? 'It can\'t seat $guestCount guests. Pick a bigger venue.'
                  : '${c.venue!.name} seats up to $cap — you have $guestCount '
                      'guests. Pick a bigger venue.',
              actionLabel: 'Pick a bigger venue',
              onAction: onChange,
            );
          case VenueCheckState.unavailable:
            return _Warn(
              color: AppColors.accentDark,
              icon: Icons.error_outline_rounded,
              title: 'This venue is no longer available',
              body: 'It was removed or deactivated. Choose another venue to '
                  'continue.',
              actionLabel: 'Choose another venue',
              onAction: onChange,
            );
        }
      },
    );
  }
}

class _ValidVenue extends StatelessWidget {
  const _ValidVenue({required this.venue, required this.onChange});
  final BanquetVenue venue;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      borderColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.catGreenLt,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: AppColors.success, size: 22),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 15, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('Selected venue',
                            style: AppTextStyles.captionBold
                                .copyWith(color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(venue.name,
                        style: AppTextStyles.bodyBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          if (venue.address != null) ...[
            const SizedBox(height: AppSizes.sm),
            Text(venue.address!,
                style: AppTextStyles.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              if (venue.capacity != null)
                Text('Up to ${venue.capacity} guests',
                    style: AppTextStyles.captionBold
                        .copyWith(color: AppColors.primary)),
              const Spacer(),
              TextButton(
                onPressed: onChange,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Change venue',
                    style: AppTextStyles.bodyBold
                        .copyWith(color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Warning/blocking summary for a stale, too-small or unverifiable selection.
class _Warn extends StatelessWidget {
  const _Warn({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      borderColor: color,
      background: AppColors.catGoldLt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyBold.copyWith(color: color)),
                    const SizedBox(height: 2),
                    Text(body, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell(
      {required this.child, required this.borderColor, this.background});
  final Widget child;
  final Color borderColor;
  final Color? background;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

/// Shown when someone reaches the venue step before Event Details is
/// complete (deep link / stale navigation). Sends them back to finish it.
class _IncompleteDetailsView extends StatelessWidget {
  const _IncompleteDetailsView({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PlanFlowHeader(
              title: "Where's the event?",
              stepLabel: 'Venue',
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.event_note_rounded,
                            color: AppColors.primary, size: 30),
                      ),
                      const SizedBox(height: AppSizes.md),
                      Text('Finish your event details first',
                          style: AppTextStyles.heading2,
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppSizes.xs),
                      Text(hint,
                          style: AppTextStyles.bodyMuted,
                          textAlign: TextAlign.center),
                      const SizedBox(height: AppSizes.lg),
                      FilledButton(
                        onPressed: () => context.go(AppRoutes.eventDetails),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(220, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSm),
                          ),
                        ),
                        child: const Text('Go to event details'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Venue card ─────────────────────────

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.type,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.overline,
    required this.overlineColor,
    required this.accentColor,
    required this.bullets,
    required this.imageUrl,
    required this.fallbackTint,
    required this.onTap,
    this.badgeLabel,
  });

  final VenueType type;
  final bool selected;
  final String title;
  final String subtitle;
  final String overline;
  final Color overlineColor;
  final Color accentColor;
  final List<String> bullets;
  final String imageUrl;
  final Color fallbackTint;
  final VoidCallback onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: selected ? accentColor : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroImage(
                imageUrl: imageUrl,
                fallbackTint: fallbackTint,
                title: title,
                subtitle: subtitle,
                badgeLabel: badgeLabel,
                selected: selected,
                accentColor: accentColor,
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overline,
                      style: AppTextStyles.captionBold.copyWith(
                        color: overlineColor,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    // Two-column grid of bullets so the card stays compact.
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSizes.sm,
                        crossAxisSpacing: AppSizes.sm,
                        childAspectRatio: 4.4,
                      ),
                      itemCount: bullets.length,
                      itemBuilder: (_, i) => _Bullet(
                        text: bullets[i],
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({
    required this.imageUrl,
    required this.fallbackTint,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accentColor,
    this.badgeLabel,
  });

  final String imageUrl;
  final Color fallbackTint;
  final String title;
  final String subtitle;
  final bool selected;
  final Color accentColor;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: fallbackTint),
            errorWidget: (_, __, ___) => Container(color: fallbackTint),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.4, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          if (badgeLabel != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
                child: Text(
                  badgeLabel!,
                  style: AppTextStyles.captionBold.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: _Radio(selected: selected, accentColor: accentColor),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.display.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.accentColor});
  final bool selected;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accentColor : Colors.white,
        border: Border.all(
          color: selected ? accentColor : Colors.white,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.check_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Banquet picker sheet ─────────────────────────

class _BanquetPickerSheet extends ConsumerWidget {
  const _BanquetPickerSheet({this.returnSelection = false});

  /// When true (editing from the plan), tapping a venue POPS the chosen
  /// [BanquetVenue] instead of applying it, so the caller can check cart impact
  /// and confirm before mutating. Normal planning applies on tap as before.
  final bool returnSelection;

  /// Sheet result meaning "take me to Event Details to fix the location".
  /// The sheet itself NEVER navigates — its context dies with the pop; the
  /// awaiting venue screen handles the navigation with its own live context.
  static const changeLocationResult = 'change-location';

  void _changeLocation(BuildContext context) {
    Navigator.of(context).pop(changeLocationResult);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(eventDraftProvider);
    final radius = ref.watch(venueSearchRadiusProvider);
    final venues = ref.watch(nearbyVenuesProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Text('Pick a banquet venue', style: AppTextStyles.display),
            const SizedBox(height: AppSizes.xs),
            Text(
              draft.hasEventCoords
                  ? 'Venues within ${radius.round()} km of your event '
                      'location, nearest first.'
                  : "Your booking is routed to this venue's operator for confirmation.",
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.lg),
            Expanded(
              // No event coordinates → we can't search "near" anything.
              // Never fall back to the saved home address here; ask the
              // customer to confirm the event location instead.
              child: !draft.hasEventCoords
                  ? _PickerMessage(
                      icon: Icons.explore_off_rounded,
                      title: 'Confirm your event location',
                      message: 'Pick the event address from the suggestions on '
                          'the event details page so we can find banquet '
                          'halls near it.',
                      primaryLabel: 'Set event location',
                      onPrimary: () => _changeLocation(context),
                    )
                  : venues.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _PickerMessage(
                        icon: Icons.wifi_off_rounded,
                        title: "Couldn't load venues",
                        message: 'Something went wrong while searching near '
                            'your event location. Check your connection and '
                            'try again.',
                        primaryLabel: 'Retry',
                        onPrimary: () => ref.invalidate(nearbyVenuesProvider),
                      ),
                      data: (rows) {
                        if (rows.isEmpty) {
                          final canExpand = radius < 100;
                          final area = draft.location ?? 'your event location';
                          return _PickerMessage(
                            icon: Icons.location_city_rounded,
                            title: 'No venues near your event yet',
                            message: 'We couldn\'t find an active banquet hall '
                                'within ${radius.round()} km of $area'
                                '${draft.guestCount > 0 ? ' for ${draft.guestCount} guests' : ''}.',
                            primaryLabel: canExpand
                                ? 'Expand search to 100 km'
                                : 'Change location',
                            onPrimary: canExpand
                                ? () => ref
                                    .read(venueSearchRadiusProvider.notifier)
                                    .state = 100
                                : () => _changeLocation(context),
                            secondaryLabel:
                                canExpand ? 'Change location' : null,
                            onSecondary: canExpand
                                ? () => _changeLocation(context)
                                : null,
                          );
                        }
                        return ListView.separated(
                          controller: scrollCtrl,
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSizes.sm),
                          itemBuilder: (_, i) => _PickerVenueRow(
                            venue: rows[i],
                            onTap: () {
                              // Capacity gate for venues with a KNOWN
                              // capacity (place_order re-checks those too;
                              // null-capacity venues are never blocked).
                              // Mostly a backstop now that the nearby query
                              // already hides known-too-small venues.
                              final capacity = rows[i].capacity;
                              final guests =
                                  ref.read(eventDraftProvider).guestCount;
                              if (capacity != null && guests > capacity) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${rows[i].name} seats up to $capacity '
                                      'guests — you have $guests. Reduce the '
                                      'guest count or pick a bigger venue.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              // Edit mode: hand the venue back to the caller,
                              // which checks cart impact + confirms before any
                              // mutation. Normal mode applies immediately.
                              if (returnSelection) {
                                Navigator.of(context).pop(rows[i]);
                                return;
                              }
                              final notifier =
                                  ref.read(eventDraftProvider.notifier);
                              notifier.setBanquetVenue(
                                venueId: rows[i].id,
                                venueName: rows[i].name,
                                address: rows[i].address,
                                latitude: rows[i].latitude,
                                longitude: rows[i].longitude,
                                capacity: rows[i].capacity,
                              );
                              // Venue has no pin? Recover it from the address in
                              // the background — doesn't block the tap.
                              if (rows[i].latitude == null ||
                                  rows[i].longitude == null) {
                                unawaited(
                                  _geocodeVenueCoords(notifier, rows[i]),
                                );
                              }
                              Navigator.of(context).pop(true);
                            },
                          ),
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

/// Centered informational state inside the picker sheet: icon + copy plus a
/// primary action, with an optional secondary. Used for the
/// "confirm your event location" and honest no-venues-nearby states.
class _PickerMessage extends StatelessWidget {
  const _PickerMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              title,
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.xs),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
              child: Text(
                message,
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(220, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
              ),
              child: Text(primaryLabel),
            ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: AppSizes.sm),
              TextButton(
                onPressed: onSecondary,
                child: Text(
                  secondaryLabel!,
                  style:
                      AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickerVenueRow extends StatelessWidget {
  const _PickerVenueRow({required this.venue, required this.onTap});
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
              child: const Icon(
                Icons.apartment_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(venue.name, style: AppTextStyles.bodyBold),
                  if (venue.address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      venue.address!,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: AppSizes.sm,
                    children: [
                      if (venue.distanceKm != null)
                        Text(
                          venue.distanceKm! < 1
                              ? 'Under 1 km from your event'
                              : '${venue.distanceKm!.toStringAsFixed(1)} km '
                                  'from your event',
                          style: AppTextStyles.captionBold
                              .copyWith(color: AppColors.success),
                        ),
                      if (venue.capacity != null)
                        Text(
                          'Up to ${venue.capacity} guests',
                          style: AppTextStyles.captionBold
                              .copyWith(color: AppColors.primary),
                        ),
                    ],
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
