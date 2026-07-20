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
