import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/material_icon_map.dart';
import '../../../data/models/event_draft.dart';
import '../../../data/models/private_property.dart';
import '../../../shared/providers/event_providers.dart';
import '../location_change.dart';
import '../plan_edit_context.dart';
import '../plan_edit_flows.dart';
import '../widgets/plan_flow_chrome.dart';

class PrivatePropertyScreen extends ConsumerStatefulWidget {
  const PrivatePropertyScreen({super.key});

  @override
  ConsumerState<PrivatePropertyScreen> createState() =>
      _PrivatePropertyScreenState();
}

class _PrivatePropertyScreenState extends ConsumerState<PrivatePropertyScreen> {
  late final TextEditingController _line1Ctrl;
  late final TextEditingController _landmarkCtrl;

  @override
  void initState() {
    super.initState();
    final p = ref.read(eventDraftProvider).propertyDraft;
    _line1Ctrl = TextEditingController(text: p?.addressLine1 ?? '');
    _landmarkCtrl = TextEditingController(text: p?.landmark ?? '');
  }

  @override
  void dispose() {
    _line1Ctrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  /// Commit the typed property details.
  ///
  /// The city/area line is NEVER typed — it is the CONFIRMED event location, so
  /// the written detail can't drift away from the coordinates the order is
  /// routed to. Without a confirmed, pinned location there is nothing to anchor
  /// to, so we write nothing at all.
  ///
  /// NOTE (compatibility): [PrivatePropertyDraft.cityPincode] currently carries
  /// the confirmed FULL location string, not a structured "city + postcode".
  /// It stays on that field so existing order payloads keep working; replace it
  /// with structured locality/postcode fields when those exist.
  void _commitAddress() {
    final draft = ref.read(eventDraftProvider);
    if (!_hasConfirmedLocation(draft)) return;
    ref.read(eventDraftProvider.notifier).setPropertyAddress(
          line1: _line1Ctrl.text,
          landmark: _landmarkCtrl.text,
          cityPincode: draft.location,
        );
  }

  /// A private property is only addressable once the event location is
  /// confirmed AND pinned — the pin is what serviceability is checked against.
  static bool _hasConfirmedLocation(EventDraft draft) =>
      (draft.location?.trim().isNotEmpty ?? false) &&
      hasUsableCoords(draft.eventLatitude, draft.eventLongitude);

  /// Drop typed text as soon as the DRAFT's property details are cleared (a
  /// confirmed location change does exactly that). Without this the controllers
  /// still hold the old building/landmark text and the very next commit would
  /// silently write those stale values back onto the new location.
  void _dropStaleTextIfCleared(EventDraft next) {
    final p = next.propertyDraft;
    bool blank(String? v) => v == null || v.trim().isEmpty;
    if (blank(p?.addressLine1) && _line1Ctrl.text.isNotEmpty) {
      _line1Ctrl.clear();
    }
    if (blank(p?.landmark) && _landmarkCtrl.text.isNotEmpty) {
      _landmarkCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<EventDraft>(
      eventDraftProvider,
      (_, next) => _dropStaleTextIfCleared(next),
    );
    final draft = ref.watch(eventDraftProvider);
    final property = draft.propertyDraft ?? const PrivatePropertyDraft();
    final locationConfirmed = _hasConfirmedLocation(draft);
    // Never let a property "complete" without the pin its address is anchored to.
    final canContinue = locationConfirmed && property.isComplete;
    final edit = PlanEditContext.of(
      GoRouterState.of(context),
      PlanEditScreen.property,
    );

    return PopScope(
      // Edit mode: system/OS back returns to the Event Plan (pop when pushed,
      // go on a direct deep link). Normal mode keeps default back.
      canPop: !edit.isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _commitAddress(); // keep the typed address before leaving
          returnFromEdit(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceWarm,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              PlanFlowHeader(
                title: edit.isEditing ? 'Edit property' : 'About your property',
                stepLabel: 'Venue',
                subtitleOverride: 'So the team comes ready',
                onBack: edit.isEditing
                    ? () {
                        _commitAddress();
                        returnFromEdit(context);
                      }
                    : null,
              ),
              Expanded(
                child: GestureDetector(
                  // Tapping outside a field commits the typed values into the
                  // draft and drops focus so the sticky footer always reflects
                  // the latest input.
                  onTap: () {
                    _commitAddress();
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      AppSizes.sm,
                      AppSizes.pagePadding,
                      AppSizes.md,
                    ),
                    children: [
                      _PropertyTypeCard(
                        selected: property.type,
                        onSelect: (t) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(eventDraftProvider.notifier)
                              .setPropertyType(t);
                        },
                      ),
                      const SizedBox(height: AppSizes.lg),
                      // Without a confirmed, pinned event location there is
                      // nothing to anchor the property address to — collecting
                      // one would let it contradict the delivery coordinates.
                      if (!locationConfirmed)
                        _ConfirmLocationCard(
                          onSetLocation: () =>
                              changeEventLocationFlow(context, ref),
                        )
                      else
                        _AddressCard(
                          line1Ctrl: _line1Ctrl,
                          landmarkCtrl: _landmarkCtrl,
                          eventLocation: draft.location!,
                          onAnyEdited: _commitAddress,
                        ),
                      const SizedBox(height: AppSizes.lg),
                    ],
                  ),
                ),
              ),
              PlanFlowFooter(
                labelLine1: canContinue ? 'Property saved' : 'Almost there',
                labelLine2: canContinue
                    ? property.shortLabel
                    : 'Pick a type & add the address',
                buttonLabel: edit.isEditing ? 'Done' : 'Setup & equipment',
                onPressed: canContinue
                    ? () {
                        _commitAddress();
                        HapticFeedback.lightImpact();
                        // Edit mode returns to the plan; normal mode continues to
                        // the next planning step.
                        if (edit.isEditing) {
                          returnFromEdit(context);
                        } else {
                          context.push(AppRoutes.eventSetup);
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Property type card ─────────────────────────

class _PropertyTypeCard extends StatelessWidget {
  const _PropertyTypeCard({required this.selected, required this.onSelect});
  final PropertyType? selected;
  final ValueChanged<PropertyType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROPERTY TYPE',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.accentDark,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What kind of place?',
            style: AppTextStyles.display.copyWith(fontSize: 22, height: 1.15),
          ),
          const SizedBox(height: AppSizes.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSizes.sm,
              mainAxisSpacing: AppSizes.sm,
              childAspectRatio: 1.05,
            ),
            itemCount: PropertyType.values.length,
            itemBuilder: (_, i) {
              final t = PropertyType.values[i];
              return _PropertyTile(
                type: t,
                selected: t == selected,
                onTap: () => onSelect(t),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PropertyTile extends StatelessWidget {
  const _PropertyTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final PropertyType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.md,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              materialIconByName(type.iconName),
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              type.label,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyBold.copyWith(
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Address card ─────────────────────────

/// Shown when the event location isn't confirmed yet: the property address has
/// nothing to anchor to, so we ask for the location first (transactionally)
/// instead of collecting an address that could contradict the delivery pin.
class _ConfirmLocationCard extends StatelessWidget {
  const _ConfirmLocationCard({required this.onSetLocation});
  final VoidCallback onSetLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADDRESS',
            style: AppTextStyles.overline
                .copyWith(color: AppColors.accentDark, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            'Confirm your event location first',
            style: AppTextStyles.display.copyWith(fontSize: 22, height: 1.15),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            'We pin your property to the event location so the kitchens we '
            'show — and the team we send — match the place on the map.',
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSizes.md),
          FilledButton(
            onPressed: onSetLocation,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(220, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
            ),
            child: const Text('Set event location'),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.line1Ctrl,
    required this.landmarkCtrl,
    required this.eventLocation,
    required this.onAnyEdited,
  });

  final TextEditingController line1Ctrl;
  final TextEditingController landmarkCtrl;

  /// The CONFIRMED event location. Displayed read-only and stored as the
  /// property's city/area line, so the written address can never contradict
  /// the coordinates the order is routed to.
  final String eventLocation;
  final VoidCallback onAnyEdited;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADDRESS',
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.accentDark,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Where exactly?',
                      style: AppTextStyles.display
                          .copyWith(fontSize: 22, height: 1.15),
                    ),
                  ],
                ),
              ),
              // "Use map" removed — no map picker exists yet; the button was
              // a no-op that only showed a coming-soon snackbar. The typed
              // address form below is the real input.
            ],
          ),
          const SizedBox(height: AppSizes.md),
          // Free text, but explicitly NOT a second routable address — the pin
          // below is what the order is routed to. This only helps the team find
          // the right gate/floor once they arrive.
          _LabeledField(
            label: 'Building & entrance details',
            controller: line1Ctrl,
            onChanged: (_) => onAnyEdited(),
            hint: 'Sunset Farm, gate 4, 2nd floor',
          ),
          const SizedBox(height: AppSizes.md),
          _LabeledField(
            label: 'Landmark for the team',
            controller: landmarkCtrl,
            onChanged: (_) => onAnyEdited(),
            hint: 'Behind ITC Maratha',
          ),
          const SizedBox(height: AppSizes.md),
          // Read-only on purpose: this is the confirmed event location, not a
          // second address the customer can type. Change it via the event
          // location flow (which re-checks the cart) — never by typing here.
          Text(
            'City & area',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border:
                  Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    eventLocation,
                    style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'From your confirmed event location.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.body
                .copyWith(color: AppColors.textMuted, fontSize: 15),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
