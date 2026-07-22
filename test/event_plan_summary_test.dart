import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/router/app_routes.dart';
import 'package:banquet_catering_app/data/models/banquet_venue.dart';
import 'package:banquet_catering_app/data/models/event_draft.dart';
import 'package:banquet_catering_app/data/models/event_tier.dart';
import 'package:banquet_catering_app/data/models/private_property.dart';
import 'package:banquet_catering_app/data/models/venue_type.dart';
import 'package:banquet_catering_app/features/user/event_plan_summary.dart';
import 'package:banquet_catering_app/shared/providers/banquet_providers.dart';

/// The shared summary is the ONE completion verdict used by the home card and
/// the Event Plan page. "Ready" must require all three authorities agreeing:
/// the planning cascade, the live tier list, and (for banquet) the live venue
/// check. A structurally complete draft is NOT enough.
void main() {
  final now = DateTime(2026, 8, 1, 12, 0); // fixed IST business clock
  const tierId = '00000000-0000-4000-8000-000000000111';

  const activeTier = EventTier(
    id: tierId,
    code: 'standard',
    label: 'Standard',
    description: '2 starters + 2 mains',
    perGuestMin: 250,
    perGuestMax: 400,
    sortOrder: 1,
  );

  /// Structurally complete draft — planningNextStep alone would say "done".
  EventDraft draft({
    VenueType? venueType = VenueType.banquetHall,
    String? banquetVenueId = 'v1',
    int? banquetVenueCapacity,
    int guestCount = 50,
    String? tier = tierId,
    PrivatePropertyDraft? property,
  }) =>
      EventDraft(
        eventName: 'Aanya Sangeet',
        session: 'Dinner',
        date: DateTime(2026, 8, 20),
        startTime: DateTime(2026, 8, 20, 19),
        endTime: DateTime(2026, 8, 20, 22),
        location: 'Grand Palace, Gachibowli',
        eventLatitude: 17.44,
        eventLongitude: 78.35,
        guestCount: guestCount,
        tierId: tier,
        tierCode: tier == null ? null : 'STANDARD',
        venueType: venueType,
        banquetVenueId: banquetVenueId,
        banquetVenueCapacity: banquetVenueCapacity,
        propertyDraft: property,
      );

  EventPlanSummary build({
    EventDraft? d,
    AsyncValue<List<EventTier>> tiers = const AsyncValue.data([activeTier]),
    AsyncValue<VenueCheck> venue =
        const AsyncValue.data(VenueCheck(VenueCheckState.valid)),
    int addonCount = 0,
  }) =>
      buildEventPlanSummary(
        draft: d ?? draft(),
        tiers: tiers,
        venueCheck: venue,
        addonCount: addonCount,
        now: now,
      );

  group('ready requires all three authorities', () {
    test('complete cascade + valid tier + valid venue → ready', () {
      final s = build();
      expect(s.readiness, EventPlanReadiness.ready);
      expect(s.isReady, isTrue);
      expect(s.packageText, 'Standard');
      expect(s.fraction, 1.0);
    });

    test('incomplete cascade → incomplete regardless of the live checks', () {
      final s = build(d: draft(banquetVenueId: null));
      expect(s.readiness, EventPlanReadiness.incomplete);
      expect(s.fraction, lessThan(1.0));
    });
  });

  group('package (tier) gating', () {
    test('tier list still LOADING → checking, never ready', () {
      final s = build(tiers: const AsyncValue.loading());
      expect(s.readiness, EventPlanReadiness.checking);
      expect(s.packageCheck, EventPlanCheck.checking);
      expect(s.packageText, contains('Checking'));
      expect(s.fraction, lessThan(1.0));
    });

    test('tier fetch ERROR → needs attention, never ready', () {
      final s = build(
        tiers: AsyncValue.error(Exception('down'), StackTrace.empty),
      );
      expect(s.readiness, EventPlanReadiness.needsAttention);
      expect(s.packageCheck, EventPlanCheck.error);
      expect(s.fraction, lessThan(1.0));
    });

    test('selected tier MISSING from the active list → needs attention', () {
      // Structurally complete, but the tier was deactivated/deleted.
      final s = build(tiers: const AsyncValue.data([]));
      expect(s.readiness, EventPlanReadiness.needsAttention);
      expect(s.packageCheck, EventPlanCheck.attention);
      expect(s.packageText, 'Package needs attention');
      expect(s.fraction, lessThan(1.0));
    });

    test('no tier selected at all → attention', () {
      final s = build(d: draft(tier: null));
      expect(s.packageCheck, EventPlanCheck.attention);
      expect(s.isReady, isFalse);
    });
  });

  group('banquet venue gating', () {
    test('venue check LOADING → checking, never ready', () {
      final s = build(venue: const AsyncValue.loading());
      expect(s.readiness, EventPlanReadiness.checking);
      expect(s.venueCheck, EventPlanCheck.checking);
      expect(s.fraction, lessThan(1.0));
    });

    test('venue check ERROR → needs attention, never ready', () {
      final s = build(
        venue: AsyncValue.error(Exception('offline'), StackTrace.empty),
      );
      expect(s.readiness, EventPlanReadiness.needsAttention);
      expect(s.venueCheck, EventPlanCheck.error);
    });

    test('venue TOO SMALL → needs attention, never ready', () {
      final s = build(
        venue: const AsyncValue.data(VenueCheck(VenueCheckState.tooSmall)),
      );
      expect(s.readiness, EventPlanReadiness.needsAttention);
      expect(s.venueCheck, EventPlanCheck.attention);
      expect(s.venueText, 'Venue needs attention');
      expect(s.fraction, lessThan(1.0));
    });

    test('venue UNAVAILABLE (deleted/deactivated) → needs attention', () {
      final s = build(
        venue: const AsyncValue.data(VenueCheck(VenueCheckState.unavailable)),
      );
      expect(s.readiness, EventPlanReadiness.needsAttention);
      expect(s.venueCheck, EventPlanCheck.attention);
    });

    test('private-property plan ignores the venue check entirely', () {
      const complete = PrivatePropertyDraft(
        type: PropertyType.home,
        addressLine1: '12 Rose Villa',
        cityPincode: 'Hyderabad 500081',
      );
      final s = build(
        d: draft(
          venueType: VenueType.privateProperty,
          banquetVenueId: null,
          property: complete,
        ),
        // Deliberately hostile venue state — must not affect a private plan.
        venue: AsyncValue.error(Exception('irrelevant'), StackTrace.empty),
      );
      expect(s.venueCheck, EventPlanCheck.notApplicable);
      expect(s.readiness, EventPlanReadiness.ready);
      expect(s.isPrivateProperty, isTrue);
    });
  });

  group('progress can never contradict the verdict', () {
    test('over-capacity banquet venue never shows a full bar (regression)', () {
      // The old home-screen progress counted "a venue id exists" and showed
      // 6/6 while the cascade said the hall no longer fits.
      final s = build(
        d: draft(guestCount: 300, banquetVenueCapacity: 200),
        venue: const AsyncValue.data(VenueCheck(VenueCheckState.tooSmall)),
      );
      expect(s.fraction, lessThan(1.0));
      expect(s.isReady, isFalse);
    });

    test('fraction reaches 1.0 only when readiness is ready', () {
      expect(build().fraction, 1.0);
      expect(build(tiers: const AsyncValue.data([])).fraction, lessThan(1.0));
    });
  });

  group('hasMeaningfulDraft', () {
    test('a brand-new empty draft is not meaningful', () {
      expect(hasMeaningfulDraft(const EventDraft()), isFalse);
      expect(
        build(d: const EventDraft()).readiness,
        EventPlanReadiness.notStarted,
      );
    });

    test('any single planning signal makes it meaningful', () {
      expect(hasMeaningfulDraft(const EventDraft(eventName: 'X')), isTrue);
      expect(hasMeaningfulDraft(const EventDraft(session: 'Dinner')), isTrue);
      expect(
          hasMeaningfulDraft(EventDraft(date: DateTime(2026, 8, 20))), isTrue);
      expect(
          hasMeaningfulDraft(const EventDraft(location: 'Somewhere')), isTrue);
      expect(hasMeaningfulDraft(const EventDraft(tierId: tierId)), isTrue);
      expect(
        hasMeaningfulDraft(const EventDraft(venueType: VenueType.banquetHall)),
        isTrue,
      );
      expect(
          hasMeaningfulDraft(const EventDraft(banquetVenueId: 'v1')), isTrue);
    });

    test('guest count alone does NOT count (it has a default)', () {
      expect(hasMeaningfulDraft(const EventDraft(guestCount: 200)), isFalse);
    });

    test('a category slug ALONE is meaningful planning state', () {
      // Session/guest seeding may not have run, and a restored legacy draft
      // can carry only the occasion.
      const d = EventDraft(categorySlug: 'wedding');
      expect(hasMeaningfulDraft(d), isTrue);
      expect(build(d: d).readiness, isNot(EventPlanReadiness.notStarted));
      expect(build(d: d).occasionText, 'Wedding');
    });

    test('a blank category slug is not meaningful', () {
      expect(
          hasMeaningfulDraft(const EventDraft(categorySlug: '   ')), isFalse);
    });
  });

  group('VenueCheckState.none never validates a selected hall (regression)',
      () {
    test('draft has a venue id but the live check says none → attention', () {
      // `none` means the live check does not agree a venue is selected. That
      // is unverified, NOT good — only `valid` may satisfy banquet readiness.
      final s = build(
        venue: const AsyncValue.data(VenueCheck(VenueCheckState.none)),
      );
      expect(s.venueCheck, EventPlanCheck.attention);
      expect(s.readiness, EventPlanReadiness.needsAttention);
      expect(s.isReady, isFalse);
      expect(s.fraction, lessThan(1.0));
    });
  });

  group('action hint and route agree with live validation', () {
    test('cascade incomplete → the cascade hint and route win', () {
      final s = build(d: draft(banquetVenueId: null));
      expect(s.actionRoute, AppRoutes.eventVenueType);
      expect(s.actionHint, 'Pick a banquet venue to finish');
    });

    test('package loading → checking hint, Event Plan', () {
      final s = build(tiers: const AsyncValue.loading());
      expect(s.actionHint, 'Checking your package…');
      expect(s.actionRoute, AppRoutes.eventPlan);
    });

    test('package error → retry hint, Event Plan', () {
      final s = build(
        tiers: AsyncValue.error(Exception('down'), StackTrace.empty),
      );
      expect(s.actionHint, contains('retry'));
      expect(s.actionRoute, AppRoutes.eventPlan);
    });

    test('package missing/inactive → choose a package, Event Details', () {
      final s = build(tiers: const AsyncValue.data([]));
      expect(s.actionHint, 'Choose an available package');
      expect(s.actionRoute, AppRoutes.eventDetails);
    });

    test('venue loading → checking hint, Event Plan', () {
      final s = build(venue: const AsyncValue.loading());
      expect(s.actionHint, 'Checking your venue…');
      expect(s.actionRoute, AppRoutes.eventPlan);
    });

    test('venue error → retry hint, Event Plan', () {
      final s = build(
        venue: AsyncValue.error(Exception('offline'), StackTrace.empty),
      );
      expect(s.actionHint, contains('retry'));
      expect(s.actionRoute, AppRoutes.eventPlan);
    });

    test('venue too small → choose a suitable venue, Venue Type', () {
      final s = build(
        venue: const AsyncValue.data(VenueCheck(VenueCheckState.tooSmall)),
      );
      expect(s.actionHint, 'Choose a suitable venue');
      expect(s.actionRoute, AppRoutes.eventVenueType);
    });

    test('fully valid → the ACTION describes opening the plan, not food', () {
      final s = build();
      // The home card promises what tapping actually does.
      expect(s.actionHint, 'View your complete event plan');
      expect(s.actionRoute, AppRoutes.eventPlan);
      expect(s.actionRoute, isNot(AppRoutes.userHome));
      // …while the plan page independently describes the plan's condition.
      expect(s.statusMessage, contains('add dishes'));
      expect(s.statusMessage, isNot(s.actionHint));
    });

    test('package problems outrank venue problems', () {
      final s = build(
        tiers: const AsyncValue.data([]),
        venue: const AsyncValue.data(VenueCheck(VenueCheckState.tooSmall)),
      );
      expect(s.actionRoute, AppRoutes.eventDetails); // package first
    });

    test('EVERY actionHint matches where actionRoute actually goes', () {
      // What the customer is promised must match the destination, in every
      // reachable state — the ready state is the one that used to lie.
      final cases = <String, EventPlanSummary>{
        'cascade incomplete': build(d: draft(banquetVenueId: null)),
        'package loading': build(tiers: const AsyncValue.loading()),
        'package error': build(
          tiers: AsyncValue.error(Exception('x'), StackTrace.empty),
        ),
        'package missing': build(tiers: const AsyncValue.data([])),
        'venue loading': build(venue: const AsyncValue.loading()),
        'venue error': build(
          venue: AsyncValue.error(Exception('x'), StackTrace.empty),
        ),
        'venue too small': build(
          venue: const AsyncValue.data(VenueCheck(VenueCheckState.tooSmall)),
        ),
        'ready': build(),
      };

      cases.forEach((name, s) {
        // Nothing may ever route the customer back to Home.
        expect(s.actionRoute, isNot(AppRoutes.userHome), reason: name);

        if (s.actionRoute == AppRoutes.eventPlan) {
          // Opening the plan must not be described as doing something else
          // (e.g. "add dishes", which happens on the restaurant list).
          expect(
            s.actionHint.toLowerCase(),
            isNot(contains('add dishes')),
            reason: '$name promises food selection but opens the plan',
          );
        }
        if (s.actionRoute == AppRoutes.eventDetails) {
          expect(s.actionHint.toLowerCase(), contains('package'), reason: name);
        }
        if (s.actionRoute == AppRoutes.eventVenueType) {
          expect(s.actionHint.toLowerCase(), contains('venue'), reason: name);
        }
      });
    });
  });

  group('summary content', () {
    test('a custom event name is NOT presented as the occasion', () {
      final s = build();
      expect(s.eventName, 'Aanya Sangeet');
      expect(s.occasionText, isNull); // no category slug on this draft
    });

    test('occasion is derived from the category slug when present', () {
      final s = build(
        d: draft().copyWith(categorySlug: 'baby_shower'),
      );
      expect(s.occasionText, 'Baby shower');
      expect(s.eventName, 'Aanya Sangeet'); // still separate
    });

    test('session, date and a start–end time range are exposed', () {
      final s = build();
      expect(s.sessionText, 'Dinner');
      expect(s.dateText, 'Thu, 20 Aug');
      expect(s.timeText, '7:00 PM – 10:00 PM');
      expect(s.guestsText, '50 guests');
    });

    test('package exposes its live label and per-guest range', () {
      final s = build();
      expect(s.packageText, 'Standard');
      expect(s.packageRangeText, '₹250–400 per guest');
    });

    test('a valid venue exposes its live capacity', () {
      final s = build(
        venue: const AsyncValue.data(
          VenueCheck(
            VenueCheckState.valid,
            venue: BanquetVenue(
              id: 'v1',
              ownerProfileId: 'op',
              name: 'Grand Palace',
              capacity: 500,
            ),
          ),
        ),
      );
      expect(s.venueText, 'Grand Palace');
      expect(s.venueCapacityText, 'Up to 500 guests');
    });

    test('no package range / capacity is invented when unresolved', () {
      final s = build(tiers: const AsyncValue.loading());
      expect(s.packageRangeText, isNull);
    });
  });
}
