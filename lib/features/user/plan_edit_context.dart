import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';

/// Which planning screen is reading the edit context. Section validity is
/// screen-specific, so `section=setup` on Event Details (or `section=event`
/// on the Setup screen) is rejected rather than treated as a half-valid edit.
enum PlanEditScreen { eventDetails, setup, venueType, property }

/// The sub-area an edit targets. Whitelisted — anything else is normal mode.
enum EditSection { event, package, setup, venue, property }

/// Typed, STRICTLY validated edit context parsed from a route's query string.
///
/// Edit mode activates only for an exact `source=eventPlan` + a `section` that
/// is valid FOR THE ASKING SCREEN. Every deviation falls back to
/// [PlanEditContext.normal] (the existing forward-cascade planning flow):
///   • missing / unknown `source`
///   • missing / unknown `section`
///   • a valid section on the wrong screen (e.g. `setup` on Event Details)
///
/// This is the ONLY place edit URLs are parsed OR built, so the whitelist can
/// never drift between the two. Callers never handle raw query strings.
class PlanEditContext {
  const PlanEditContext._(this.section);

  /// The active edit section, or null in normal mode.
  final EditSection? section;

  /// Normal planning mode — no edit-mode behaviour.
  static const normal = PlanEditContext._(null);

  bool get isEditing => section != null;

  /// Parse + validate [state]'s query against the [screen] doing the asking.
  static PlanEditContext of(GoRouterState state, PlanEditScreen screen) =>
      fromQuery(state.uri.queryParameters, screen);

  /// Pure core of [of] — validates a raw query map. Exposed for tests so the
  /// whitelist can be exercised without constructing a GoRouterState.
  static PlanEditContext fromQuery(
    Map<String, String> query,
    PlanEditScreen screen,
  ) {
    if (query['source'] != _source) return normal;
    final section = _sectionFrom(query['section']);
    if (section == null) return normal;
    if (!_allowedOn(screen).contains(section)) return normal;
    return PlanEditContext._(section);
  }

  static const _source = 'eventPlan';

  static EditSection? _sectionFrom(String? raw) => switch (raw) {
        'event' => EditSection.event,
        'package' => EditSection.package,
        'setup' => EditSection.setup,
        'venue' => EditSection.venue,
        'property' => EditSection.property,
        _ => null,
      };

  static Set<EditSection> _allowedOn(PlanEditScreen screen) => switch (screen) {
        PlanEditScreen.eventDetails => const {
            EditSection.event,
            EditSection.package,
          },
        PlanEditScreen.setup => const {EditSection.setup},
        PlanEditScreen.venueType => const {EditSection.venue},
        PlanEditScreen.property => const {EditSection.property},
      };

  // ── URL builders — the ONLY sanctioned way to construct an edit URL ──

  /// Event Details, scrolled to the event fields (name/session/date/time/guests).
  static String editEvent() => _url(AppRoutes.eventDetails, 'event');

  /// Event Details, scrolled to the package/tier section.
  static String editPackage() => _url(AppRoutes.eventDetails, 'package');

  /// The setup & equipment (add-ons) screen.
  static String editSetup() => _url(AppRoutes.eventSetup, 'setup');

  /// The venue-type screen — switch hall/private, or change the banquet hall.
  static String editVenue() => _url(AppRoutes.eventVenueType, 'venue');

  /// The private-property screen — edit property type + address details.
  static String editProperty() => _url(AppRoutes.eventProperty, 'property');

  static String _url(String base, String section) =>
      '$base?source=$_source&section=$section';
}

/// Return from an edit to the Event Plan page.
///
/// Pops when there is a route underneath (the edit was launched FROM the plan
/// page), otherwise falls back to the plan page for a direct/deep-linked edit
/// URL. Because every planning write is immediate, this also "keeps" the edits
/// — there is no staged Save/Cancel to undo.
void returnFromEdit(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.eventPlan);
  }
}
