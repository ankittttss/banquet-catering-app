import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/material_icon_map.dart';
import '../../../data/models/addon.dart';
import '../../../shared/providers/addon_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../widgets/plan_flow_chrome.dart';

class SetupEquipmentScreen extends ConsumerStatefulWidget {
  const SetupEquipmentScreen({super.key});

  @override
  ConsumerState<SetupEquipmentScreen> createState() =>
      _SetupEquipmentScreenState();
}

class _SetupEquipmentScreenState
    extends ConsumerState<SetupEquipmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Seed the default selection the first time the user lands here so
      // the screen feels "Pre-filled for N guests" out of the box.
      final draft = ref.read(eventDraftProvider);
      if (draft.addonQuantities.isEmpty) {
        final seed = ref.read(defaultAddonSelectionProvider);
        seed.forEach((id, qty) {
          ref
              .read(eventDraftProvider.notifier)
              .setAddonQuantity(id, qty);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(eventDraftProvider);
    final catalog = ref.watch(addonCatalogProvider);
    final bundles = ref.watch(addonBundlesProvider);
    final total = ref.watch(addonsTotalProvider);
    final count = ref.watch(addonsCountProvider);
    final guests = draft.guestCount;

    // Group catalog by .group for the SECTION headers.
    final byGroup = <String, List<Addon>>{};
    for (final a in catalog) {
      byGroup.putIfAbsent(a.group, () => []).add(a);
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PlanFlowHeader(
              title: 'Setup & equipment',
              step: 2,
              stepLabel: 'Venue',
              subtitleOverride: 'Optional add-ons for your property',
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
                  _PrefilledBanner(guests: guests),
                  const SizedBox(height: AppSizes.lg),
                  _BundlesRow(bundles: bundles),
                  const SizedBox(height: AppSizes.lg),
                  for (final group in byGroup.keys) ...[
                    _GroupHeader(label: group),
                    const SizedBox(height: AppSizes.sm),
                    _GroupCard(items: byGroup[group]!),
                    const SizedBox(height: AppSizes.lg),
                  ],
                ],
              ),
            ),
            PlanFlowFooter(
              labelLine1: '$count add-ons · setup',
              labelLine2: Formatters.currency(total),
              labelLine2Color: AppColors.primary,
              buttonLabel: 'Pick the menu',
              onPressed: () {
                HapticFeedback.lightImpact();
                // After setup we route the user to a recce booking if
                // they haven't already done one, otherwise straight to
                // restaurants.
                if (draft.recce?.isComplete == true) {
                  final t = DateTime.now().millisecondsSinceEpoch;
                  context.go(
                    '${AppRoutes.userHome}?scrollTo=restaurants&t=$t',
                  );
                } else {
                  context.push(AppRoutes.eventRecce);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Pre-filled banner ─────────────────────────

class _PrefilledBanner extends StatelessWidget {
  const _PrefilledBanner({required this.guests});
  final int guests;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.diamond_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-filled for $guests guests',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 4),
                Text(
                  "We've estimated the basics. Adjust quantities anytime — pay for what you use.",
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Bundles row ─────────────────────────

class _BundlesRow extends ConsumerWidget {
  const _BundlesRow({required this.bundles});
  final List<AddonBundle> bundles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK BUNDLES',
          style: AppTextStyles.overline.copyWith(
            color: AppColors.accentDark,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: bundles.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSizes.sm),
            itemBuilder: (_, i) => _BundleCard(
              bundle: bundles[i],
              onTap: () {
                HapticFeedback.lightImpact();
                ref
                    .read(eventDraftProvider.notifier)
                    .applyAddonBundle(bundles[i].quantities);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text('${bundles[i].name} applied'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle, required this.onTap});
  final AddonBundle bundle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.fromHex(bundle.tintHex);
    final color = AppColors.fromHex(bundle.colorHex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: tint),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bundle.name,
              style: AppTextStyles.captionBold.copyWith(
                color: color,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                bundle.description,
                style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Group header & card ─────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.overline.copyWith(
        color: AppColors.accentDark,
        fontSize: 11,
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.items});
  final List<Addon> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider,
              ),
            _AddonRow(addon: items[i]),
          ],
        ],
      ),
    );
  }
}

class _AddonRow extends ConsumerWidget {
  const _AddonRow({required this.addon});
  final Addon addon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(eventDraftProvider).addonQuantities[addon.id] ?? 0;
    final total = addon.unitPrice * qty;
    final iconBg = AppColors.fromHex(addon.iconBgHex);
    final iconFg = AppColors.fromHex(addon.iconHex);

    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(
              materialIconByName(addon.iconName),
              color: iconFg,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(addon.label, style: AppTextStyles.heading3),
                if (addon.recommended) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusXs),
                    ),
                    child: Text(
                      'RECOMMENDED',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.accentDark,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  addon.subtitle,
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 13),
                ),
                const SizedBox(height: AppSizes.sm),
                // Wrap so a long total can drop to a second line on narrow
                // viewports instead of overflowing the stepper.
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyBold,
                        children: [
                          TextSpan(text: Formatters.currency(addon.unitPrice)),
                          TextSpan(
                            text: ' / ${addon.unitLabel}',
                            style: AppTextStyles.bodyMuted
                                .copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (qty > 0)
                      Text(
                        '· ${Formatters.currency(total)} total',
                        style: AppTextStyles.bodyBold
                            .copyWith(color: AppColors.primary, fontSize: 13),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          _QtyStepper(
            value: qty,
            onMinus: () => ref
                .read(eventDraftProvider.notifier)
                .bumpAddon(addon.id, -1),
            onPlus: () => ref
                .read(eventDraftProvider.notifier)
                .bumpAddon(addon.id, 1),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 1.4),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove_rounded, onTap: onMinus),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
            ),
          ),
          _StepBtn(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}
