import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../data/models/venue_type.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../widgets/plan_flow_chrome.dart';

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
          final picked = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const _BanquetPickerSheet(),
          );
          if (picked != true) return;
        }
        if (!context.mounted) return;
        final t = DateTime.now().millisecondsSinceEpoch;
        context.go('${AppRoutes.userHome}?scrollTo=restaurants&t=$t');
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
                      'Free site recce by your chef',
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
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusPill),
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
              "Your booking is routed to this venue's operator for confirmation.",
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: AppSizes.lg),
            Expanded(
              child: venues.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(
                  'Could not load venues: $e',
                  style: AppTextStyles.caption,
                ),
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
                    itemBuilder: (_, i) => _PickerVenueRow(
                      venue: rows[i],
                      onTap: () {
                        ref
                            .read(eventDraftProvider.notifier)
                            .setBanquetVenue(
                              venueId: rows[i].id,
                              venueName: rows[i].name,
                            );
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
                  if (venue.capacity != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Up to ${venue.capacity} guests',
                      style: AppTextStyles.captionBold
                          .copyWith(color: AppColors.primary),
                    ),
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

