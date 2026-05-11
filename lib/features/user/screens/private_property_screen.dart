import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/material_icon_map.dart';
import '../../../data/models/private_property.dart';
import '../../../shared/providers/event_providers.dart';
import '../widgets/plan_flow_chrome.dart';

class PrivatePropertyScreen extends ConsumerStatefulWidget {
  const PrivatePropertyScreen({super.key});

  @override
  ConsumerState<PrivatePropertyScreen> createState() =>
      _PrivatePropertyScreenState();
}

class _PrivatePropertyScreenState
    extends ConsumerState<PrivatePropertyScreen> {
  late final TextEditingController _line1Ctrl;
  late final TextEditingController _landmarkCtrl;
  late final TextEditingController _cityCtrl;

  @override
  void initState() {
    super.initState();
    final p = ref.read(eventDraftProvider).propertyDraft;
    _line1Ctrl = TextEditingController(text: p?.addressLine1 ?? '');
    _landmarkCtrl = TextEditingController(text: p?.landmark ?? '');
    _cityCtrl = TextEditingController(text: p?.cityPincode ?? '');
  }

  @override
  void dispose() {
    _line1Ctrl.dispose();
    _landmarkCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _commitAddress() {
    ref.read(eventDraftProvider.notifier).setPropertyAddress(
          line1: _line1Ctrl.text,
          landmark: _landmarkCtrl.text,
          cityPincode: _cityCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(eventDraftProvider);
    final property = draft.propertyDraft ?? const PrivatePropertyDraft();
    final canContinue = property.isComplete;

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PlanFlowHeader(
              title: 'About your property',
              step: 2,
              stepLabel: 'Venue',
              subtitleOverride: 'So the team comes ready',
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
                    _AddressCard(
                      line1Ctrl: _line1Ctrl,
                      landmarkCtrl: _landmarkCtrl,
                      cityCtrl: _cityCtrl,
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
              buttonLabel: 'Setup & equipment',
              onPressed: canContinue
                  ? () {
                      _commitAddress();
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.eventSetup);
                    }
                  : null,
            ),
          ],
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
              color:
                  selected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              type.label,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyBold.copyWith(
                color: selected
                    ? AppColors.primary
                    : AppColors.textPrimary,
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

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.line1Ctrl,
    required this.landmarkCtrl,
    required this.cityCtrl,
    required this.onAnyEdited,
  });

  final TextEditingController line1Ctrl;
  final TextEditingController landmarkCtrl;
  final TextEditingController cityCtrl;
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
              InkWell(
                onTap: () {
                  // Map picker would open here. No-op for the MVP build —
                  // the form already supports typing the address.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: Duration(seconds: 2),
                      content: Text('Map picker is coming soon'),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Use map',
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          _LabeledField(
            label: 'Address line 1',
            controller: line1Ctrl,
            onChanged: (_) => onAnyEdited(),
            hint: 'Sunset Farm, Lane 4',
          ),
          const SizedBox(height: AppSizes.md),
          _LabeledField(
            label: 'Landmark / area',
            controller: landmarkCtrl,
            onChanged: (_) => onAnyEdited(),
            hint: 'Behind ITC Maratha, Madh Island',
          ),
          const SizedBox(height: AppSizes.md),
          _LabeledField(
            label: 'City & pincode',
            controller: cityCtrl,
            onChanged: (_) => onAnyEdited(),
            hint: 'Mumbai 400061',
            keyboardType: TextInputType.text,
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
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;
  final TextInputType? keyboardType;

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
          keyboardType: keyboardType,
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
