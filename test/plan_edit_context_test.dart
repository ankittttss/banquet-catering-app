import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/features/user/plan_edit_context.dart';

/// The parser is the single gate for edit mode. It must be STRICT: only an
/// exact source=eventPlan + a section valid FOR THE ASKING SCREEN activates
/// editing. Everything else — missing/unknown source, missing/unknown section,
/// or a valid section on the wrong screen — is normal mode. Malformed input
/// can never open an unsafe edit surface.
void main() {
  /// Parse the query of [uri] via the pure core (what `of` delegates to).
  PlanEditContext parse(String uri, PlanEditScreen screen) =>
      PlanEditContext.fromQuery(Uri.parse(uri).queryParameters, screen);

  group('valid (source, section) on the matching screen', () {
    test('event on Event Details', () {
      final c = parse(
        '/user/event?source=eventPlan&section=event',
        PlanEditScreen.eventDetails,
      );
      expect(c.isEditing, isTrue);
      expect(c.section, EditSection.event);
    });

    test('package on Event Details', () {
      final c = parse(
        '/user/event?source=eventPlan&section=package',
        PlanEditScreen.eventDetails,
      );
      expect(c.section, EditSection.package);
    });

    test('setup on the Setup screen', () {
      final c = parse(
        '/user/event/setup?source=eventPlan&section=setup',
        PlanEditScreen.setup,
      );
      expect(c.section, EditSection.setup);
    });

    test('venue on the Venue-type screen', () {
      final c = parse(
        '/user/event/venue?source=eventPlan&section=venue',
        PlanEditScreen.venueType,
      );
      expect(c.isEditing, isTrue);
      expect(c.section, EditSection.venue);
    });

    test('property on the Property screen', () {
      final c = parse(
        '/user/event/property?source=eventPlan&section=property',
        PlanEditScreen.property,
      );
      expect(c.isEditing, isTrue);
      expect(c.section, EditSection.property);
    });
  });

  group('venue/property URL builders round-trip on their own screen', () {
    test('editVenue() parses back to venue, and ONLY on the venue screen', () {
      final url = PlanEditContext.editVenue();
      expect(parse(url, PlanEditScreen.venueType).section, EditSection.venue);
      // Same URL, wrong screens → normal mode.
      for (final screen in [
        PlanEditScreen.eventDetails,
        PlanEditScreen.setup,
        PlanEditScreen.property,
      ]) {
        expect(parse(url, screen).isEditing, isFalse, reason: '$screen');
      }
    });

    test('editProperty() parses back to property, and ONLY on that screen', () {
      final url = PlanEditContext.editProperty();
      expect(
        parse(url, PlanEditScreen.property).section,
        EditSection.property,
      );
      for (final screen in [
        PlanEditScreen.eventDetails,
        PlanEditScreen.setup,
        PlanEditScreen.venueType,
      ]) {
        expect(parse(url, screen).isEditing, isFalse, reason: '$screen');
      }
    });
  });

  group('venue/property sections are rejected on the wrong screen', () {
    test('every section is accepted by exactly ONE screen', () {
      const bySection = {
        'event': PlanEditScreen.eventDetails,
        'package': PlanEditScreen.eventDetails,
        'setup': PlanEditScreen.setup,
        'venue': PlanEditScreen.venueType,
        'property': PlanEditScreen.property,
      };
      for (final entry in bySection.entries) {
        for (final screen in PlanEditScreen.values) {
          final c = parse(
            '/x?source=eventPlan&section=${entry.key}',
            screen,
          );
          final shouldEdit = screen == entry.value;
          expect(
            c.isEditing,
            shouldEdit,
            reason: 'section=${entry.key} on $screen',
          );
        }
      }
    });

    test('venue/property still need the eventPlan source', () {
      expect(
        parse('/x?section=venue', PlanEditScreen.venueType).isEditing,
        isFalse,
      );
      expect(
        parse('/x?source=other&section=property', PlanEditScreen.property)
            .isEditing,
        isFalse,
      );
    });
  });

  group('valid section on the WRONG screen → normal mode', () {
    test('setup on Event Details is rejected', () {
      final c = parse(
        '/user/event?source=eventPlan&section=setup',
        PlanEditScreen.eventDetails,
      );
      expect(c.isEditing, isFalse);
      expect(c.section, isNull);
    });

    test('event on the Setup screen is rejected', () {
      final c = parse(
        '/user/event/setup?source=eventPlan&section=event',
        PlanEditScreen.setup,
      );
      expect(c.isEditing, isFalse);
    });

    test('package on the Setup screen is rejected', () {
      final c = parse(
        '/user/event/setup?source=eventPlan&section=package',
        PlanEditScreen.setup,
      );
      expect(c.isEditing, isFalse);
    });
  });

  group('missing / unknown / malformed → normal mode', () {
    test('no query at all', () {
      expect(
          parse('/user/event', PlanEditScreen.eventDetails).isEditing, isFalse);
    });

    test('wrong source', () {
      expect(
        parse('/user/event?source=cart&section=event',
                PlanEditScreen.eventDetails)
            .isEditing,
        isFalse,
      );
    });

    test('missing source (section only)', () {
      expect(
        parse('/user/event?section=event', PlanEditScreen.eventDetails)
            .isEditing,
        isFalse,
      );
    });

    test('missing section (source only)', () {
      expect(
        parse('/user/event?source=eventPlan', PlanEditScreen.eventDetails)
            .isEditing,
        isFalse,
      );
    });

    test('unknown section value', () {
      expect(
        parse('/user/event?source=eventPlan&section=location',
                PlanEditScreen.eventDetails)
            .isEditing,
        isFalse,
      );
    });

    test('an arbitrary route string as source is not honoured', () {
      expect(
        parse('/user/event?source=/user/cart&section=event',
                PlanEditScreen.eventDetails)
            .isEditing,
        isFalse,
      );
    });

    test('case-sensitive: EVENTPLAN is not eventPlan', () {
      expect(
        parse('/user/event?source=EVENTPLAN&section=event',
                PlanEditScreen.eventDetails)
            .isEditing,
        isFalse,
      );
    });
  });

  group('URL builders round-trip through the parser', () {
    test('editEvent → event on Event Details', () {
      final url = PlanEditContext.editEvent();
      expect(url, '/user/event?source=eventPlan&section=event');
      expect(
          parse(url, PlanEditScreen.eventDetails).section, EditSection.event);
    });

    test('editPackage → package on Event Details', () {
      final url = PlanEditContext.editPackage();
      expect(
          parse(url, PlanEditScreen.eventDetails).section, EditSection.package);
    });

    test('editSetup → setup on the Setup screen', () {
      final url = PlanEditContext.editSetup();
      expect(url, '/user/event/setup?source=eventPlan&section=setup');
      expect(parse(url, PlanEditScreen.setup).section, EditSection.setup);
    });

    test('a builder URL is still rejected on the wrong screen', () {
      // editSetup targets the setup route, but if its query landed on Event
      // Details it must NOT activate.
      expect(
        parse(PlanEditContext.editSetup(), PlanEditScreen.eventDetails)
            .isEditing,
        isFalse,
      );
    });
  });
}
