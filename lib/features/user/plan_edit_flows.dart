import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/router/app_routes.dart';
import '../../shared/providers/cart_providers.dart';
import '../../shared/providers/event_providers.dart';
import '../../shared/providers/repositories_providers.dart';
import 'location_change.dart';
import 'planning_session.dart';
import 'widgets/address_search_sheet.dart';

/// User-facing Event Plan flows: "Start fresh" and the transactional
/// event-location / banquet-venue changes. These live outside the widget so the
/// confirm/cancel/retry orchestration is one linear function with explicit
/// `context.mounted` guards, and the mutation itself is delegated to
/// [planning_session] (unit-tested without a widget tree).

/// "Start fresh": confirm, then clear the event draft AND the cart, then open
/// Event Details for a new plan. Cancel changes nothing. Saved addresses,
/// favourites and past orders are untouched.
Future<void> startFreshFlow(BuildContext context, WidgetRef ref) async {
  final cartCount = ref.read(cartProvider).length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Start fresh?'),
      content: Text(
        'This clears your event details, venue and setup add-ons, and empties '
        'your cart'
        // A count of LINES (selections), not item quantities — each line bills
        // per guest, so "3 items" would be wrong.
        '${cartCount > 0 ? ' ($cartCount cart selection${cartCount == 1 ? '' : 's'})' : ''}'
        '.\n\nYour saved addresses, favourites and past orders stay.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Start fresh'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  clearPlanningSession(
    draftController: ref.read(eventDraftProvider.notifier),
    cartController: ref.read(cartProvider.notifier),
  );
  // A fresh plan begins at Event Details. go() (not push) so the emptied plan
  // isn't left on the back stack.
  context.go(AppRoutes.eventDetails);
}

/// Transactional event-location change: pick an address (candidate), preview
/// its impact on the venue/property/cart, and apply ONLY on confirmation.
/// Nothing mutates until the final apply — cancel, an unpinnable address, or a
/// failed check all leave the draft and cart exactly as they were.
///
/// Returns true when a new location was applied.
Future<bool> changeEventLocationFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  // GPS is offered here: this IS the approved planning flow.
  final res =
      await AddressSearchSheet.show(context, allowCurrentLocation: true);
  if (res == null || !context.mounted) return false;

  final label = res.displayAddress.trim().isNotEmpty
      ? res.displayAddress
      : (res.shortLabel.trim().isNotEmpty ? res.shortLabel : res.name);
  // An address we can't pin can't be verified against any kitchen — reject it
  // instead of accepting an unverifiable event location.
  final candidate = LocationCandidate.tryCreate(
    address: label,
    latitude: res.latitude,
    longitude: res.longitude,
  );
  if (candidate == null) {
    await _tellUnlocatable(context, 'that address');
    return false;
  }

  final impact = await _runImpactWithRetry(
    context,
    () => checkEventLocationChange(
      candidate: candidate,
      draft: ref.read(eventDraftProvider),
      cart: ref.read(cartProvider),
      repository: ref.read(menuRepositoryProvider),
    ),
  );
  if (impact == null || !context.mounted) return false; // cancelled / gave up

  // Nothing clears and nothing is unserviceable → just apply the address.
  if (impact.hasConsequences) {
    final confirmed = await _confirmImpact(context, candidate.address, impact,
        isVenue: false);
    if (confirmed != true || !context.mounted) return false;
  }
  applyEventLocationChange(
    draftController: ref.read(eventDraftProvider.notifier),
    cartController: ref.read(cartProvider.notifier),
    candidate: candidate,
    impact: impact,
  );
  return true;
}

/// Apply a picked banquet venue as the event location while EDITING from the
/// plan: preview the cart impact, confirm, and apply — all transactional.
/// Returns true when applied; false on cancel, an unpinnable venue, or a failed
/// check (nothing changed). Navigation stays with the caller.
Future<bool> applyChosenVenueInEdit(
  BuildContext context,
  WidgetRef ref, {
  required String venueId,
  required String venueName,
  String? address,
  double? latitude,
  double? longitude,
  int? capacity,
}) async {
  // A hall with no pin cannot become the authoritative event location.
  if (!hasUsableCoords(latitude, longitude)) {
    await _tellUnlocatable(context, 'this venue');
    return false;
  }

  final impact = await _runImpactWithRetry(
    context,
    () => checkBanquetVenueImpact(
      venueLatitude: latitude,
      venueLongitude: longitude,
      cart: ref.read(cartProvider),
      repository: ref.read(menuRepositoryProvider),
    ),
  );
  if (impact == null || !context.mounted) return false;

  if (impact.hasConsequences) {
    final confirmed =
        await _confirmImpact(context, venueName, impact, isVenue: true);
    if (confirmed != true || !context.mounted) return false;
  }

  applyBanquetVenueChange(
    draftController: ref.read(eventDraftProvider.notifier),
    cartController: ref.read(cartProvider.notifier),
    venueId: venueId,
    venueName: venueName,
    address: address,
    latitude: latitude,
    longitude: longitude,
    capacity: capacity,
    impact: impact,
  );
  return true;
}

/// Runs a (non-mutating) impact [check] behind a modal spinner, retrying on
/// transient failure. Returns the impact, or null when the user cancels, gives
/// up, or the target turned out to be unpinnable — in every null case NOTHING
/// has been mutated.
Future<LocationImpact?> _runImpactWithRetry(
  BuildContext context,
  Future<LocationImpact> Function() check,
) async {
  while (true) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
    LocationImpact? impact;
    Object? failure;
    try {
      impact = await check();
      if (context.mounted) Navigator.of(context).pop(); // dismiss spinner
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      failure = e;
    }
    if (!context.mounted) return null;
    if (impact != null) return impact;

    // An unpinnable target is not transient — never offer Retry for it.
    if (failure is UnlocatableCandidate) {
      await _tellUnlocatable(context, failure.what);
      return null;
    }

    final retry = await _confirmRetry(
      context,
      title: "Couldn't check your cart",
      message:
          'We couldn\'t verify which kitchens can deliver here. Check your '
          'connection and try again.',
    );
    if (retry != true || !context.mounted) return null; // give up → no change
  }
}

/// Explains that a location can't be used, and changes nothing.
Future<void> _tellUnlocatable(BuildContext context, String what) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('We couldn\'t pin that location'),
      content: Text(
        'We couldn\'t place $what on the map, so we can\'t confirm which '
        'kitchens deliver there. Pick an address from the search suggestions '
        'instead.\n\nNothing in your plan or cart has changed.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmRetry(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}

/// The impact preview. Spells out exactly WHICH dishes are removed and why,
/// plus which selections clear, before anything is applied.
Future<bool?> _confirmImpact(
  BuildContext context,
  String target,
  LocationImpact impact, {
  required bool isVenue,
}) {
  final removeCount = impact.removedLineCount;
  final confirmLabel =
      removeCount > 0 ? 'Change & remove $removeCount' : 'Change location';

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isVenue ? 'Change banquet venue?' : 'Change event location?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVenue
                  ? 'Your event will move to “$target”.'
                  : 'Moving the event to “$target” will:',
            ),
            const SizedBox(height: 12),
            if (impact.venueWillClear)
              _bullet('Your selected banquet venue will be cleared — the event '
                  'no longer happens there.'),
            if (impact.propertyWillClear)
              _bullet('Your saved property address will be cleared (the '
                  'property type is kept).'),
            // Exact dishes, so the customer knows precisely what they lose.
            for (final line in impact.removed) _bullet(line.label),
            if (impact.keptLineCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  // Lines/selections, not item quantities.
                  '${impact.keptLineCount} other cart selection'
                  '${impact.keptLineCount == 1 ? '' : 's'} stay.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep current'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: removeCount > 0 ? AppColors.error : null,
          ),
          child: Text(isVenue && removeCount > 0
              ? 'Select & remove $removeCount'
              : confirmLabel),
        ),
      ],
    ),
  );
}

Widget _bullet(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
