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

class VenueTypeScreen extends ConsumerWidget {
  const VenueTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(eventDraftProvider);
    final selected = draft.venueType;

    Future<void> onContinue() async {
      HapticFeedback.lightImpact();
      if (selected == VenueType.banquetHall) {
        // Hall path needs a specific venue selected before we can route
        // the booking to a banquet operator. If the draft already has one
        // from an earlier visit, skip the sheet and head straight to the
        // restaurant browser.
        final alreadyPicked = draft.banquetVenueId != null;
        if (!alreadyPicked) {
          final picked = await showModalBottomSheet<Object>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const _BanquetPickerSheet(),
          );
          if (!context.mounted) return;
          if (picked == _BanquetPickerSheet.changeLocationResult) {
            // The customer wants to fix the event location. Navigate from
            // THIS screen's (mounted-checked) context, never the sheet's,
            // and use go() so the stack is replaced — pushing would stack
            // a duplicate Event Details page on the
            // Event Details → venue → picker path, while popping would
            // miss it entirely on the home "Continue planning" → venue
            // path (no Event Details below us there).
            context.go(AppRoutes.eventDetails);
            return;
          }
          if (picked != true) return;
        }
        if (!context.mounted) return;
        // Push (not go) so the planning steps stay on the back stack —
        // the user can return to change guests / venue / details without
        // restarting the order.
        final t = DateTime.now().millisecondsSinceEpoch;
        context.push('${AppRoutes.userHome}?scrollTo=restaurants&t=$t');
      } else {
        context.push(AppRoutes.eventProperty);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PlanFlowHeader(
              title: "Where's the event?",
              step: 2,
              stepLabel: 'Venue',
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
                    overline: 'EASIEST · WE COORDINATE EVERYTHING',
                    overlineColor: AppColors.primary,
                    accentColor: AppColors.primary,
                    bullets: const [
                      'Hall fee included in quote',
                      'In-house kitchen prep',
                      'Trained service staff',
                      'No equipment to rent',
                    ],
                    imageUrl:
                        'https://images.unsplash.com/photo-1530023367847-a683933f4172?auto=format&fit=crop&w=900&q=80',
                    fallbackTint: AppColors.primarySoft,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(eventDraftProvider.notifier)
                          .setVenueType(VenueType.banquetHall);
                    },
                  ),
                  const SizedBox(height: AppSizes.lg),
                  _VenueCard(
                    type: VenueType.privateProperty,
                    selected: selected == VenueType.privateProperty,
                    title: 'Private property',
                    subtitle: 'Your home, farmhouse, terrace, lawn',
                    overline: 'MOST PERSONAL · WE BRING EVERYTHING TO YOU',
                    overlineColor: AppColors.success,
                    accentColor: AppColors.success,
                    badgeLabel: 'NEW · MOST FLEXIBLE',
                    bullets: const [
                      'Cook live or pre-served',
                      'Setup, decor, equipment add-ons',
                      'Discreet service team',
                    ],
                    imageUrl:
                        'https://images.unsplash.com/photo-1519225421980-715cb0215aed?auto=format&fit=crop&w=900&q=80',
                    fallbackTint: AppColors.catGreenLt,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(eventDraftProvider.notifier)
                          .setVenueType(VenueType.privateProperty);
                    },
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
              buttonLabel: 'Continue',
              onPressed: selected == null ? null : () => onContinue(),
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
  const _BanquetPickerSheet();

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
                              final notifier =
                                  ref.read(eventDraftProvider.notifier);
                              notifier.setBanquetVenue(
                                venueId: rows[i].id,
                                venueName: rows[i].name,
                                address: rows[i].address,
                                latitude: rows[i].latitude,
                                longitude: rows[i].longitude,
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
