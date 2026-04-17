import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/presentation/address_label_presentation.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/event_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../../shared/widgets/primary_button.dart';

class EventDetailsScreen extends ConsumerStatefulWidget {
  const EventDetailsScreen({super.key});

  @override
  ConsumerState<EventDetailsScreen> createState() =>
      _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  final _locationCtrl = TextEditingController();
  final _guestsCtrl = TextEditingController(text: '50');

  @override
  void initState() {
    super.initState();
    final current = ref.read(eventDraftProvider);
    if (current.location != null && current.location!.trim().isNotEmpty) {
      _locationCtrl.text = current.location!;
    } else {
      // Pre-fill with default saved address when no location set yet.
      final def = ref.read(defaultAddressProvider);
      if (def != null) {
        _locationCtrl.text = def.fullAddress;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(eventDraftProvider.notifier)
              .setLocation(def.fullAddress);
        });
      }
    }
    _guestsCtrl.text = current.guestCount.toString();
  }

  Future<void> _pickSavedAddress() async {
    final addresses = await ref.read(addressesProvider.future);
    if (!mounted) return;
    if (addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No saved addresses. Add some from your profile.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose a saved address',
                  style: AppTextStyles.heading2),
              const SizedBox(height: AppSizes.md),
              for (final a in addresses)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(a.label.icon, color: AppColors.primary),
                  title: Text(a.label.label,
                      style: AppTextStyles.bodyBold),
                  subtitle: Text(
                    a.fullAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    _locationCtrl.text = a.fullAddress;
                    ref
                        .read(eventDraftProvider.notifier)
                        .setLocation(a.fullAddress);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _guestsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 2)),
      firstDate: now.add(const Duration(hours: 24)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      ref.read(eventDraftProvider.notifier).setDate(picked);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked == null) return;
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    final notifier = ref.read(eventDraftProvider.notifier);
    isStart ? notifier.setStartTime(dt) : notifier.setEndTime(dt);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(eventDraftProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppSizes.sm),
          Text('WHEN', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          AppCard(
            onTap: _pickDate,
            child: Row(
              children: [
                const Icon(PhosphorIconsDuotone.calendar,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Event date', style: AppTextStyles.captionBold),
                      const SizedBox(height: 2),
                      Text(
                        draft.date == null
                            ? 'Pick a date'
                            : Formatters.date(draft.date!),
                        style: AppTextStyles.heading3,
                      ),
                    ],
                  ),
                ),
                const Icon(PhosphorIconsBold.caretRight,
                    color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text('SESSION', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            children: [
              for (final s in ['Lunch', 'High Tea', 'Dinner'])
                CategoryChip(
                  label: s,
                  selected: draft.session == s,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(eventDraftProvider.notifier).setSession(s);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  onTap: () => _pickTime(true),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start time', style: AppTextStyles.captionBold),
                      const SizedBox(height: 2),
                      Text(
                        draft.startTime == null
                            ? '—'
                            : Formatters.time(draft.startTime!),
                        style: AppTextStyles.heading3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: AppCard(
                  onTap: () => _pickTime(false),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End time', style: AppTextStyles.captionBold),
                      const SizedBox(height: 2),
                      Text(
                        draft.endTime == null
                            ? '—'
                            : Formatters.time(draft.endTime!),
                        style: AppTextStyles.heading3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Text('WHERE', style: AppTextStyles.overline),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _pickSavedAddress(),
                icon: const Icon(PhosphorIconsBold.bookmarks, size: 16),
                label: const Text('Saved'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 0,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          TextField(
            controller: _locationCtrl,
            maxLines: 2,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Venue or full address',
              prefixIcon: Icon(PhosphorIconsBold.mapPin),
            ),
            onChanged: (v) =>
                ref.read(eventDraftProvider.notifier).setLocation(v),
          ),
          const SizedBox(height: AppSizes.lg),
          Text('GUESTS', style: AppTextStyles.overline),
          const SizedBox(height: AppSizes.sm),
          AppCard(
            child: Row(
              children: [
                const Icon(PhosphorIconsDuotone.users,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guest count', style: AppTextStyles.captionBold),
                      TextField(
                        controller: _guestsCtrl,
                        keyboardType: TextInputType.number,
                        style: AppTextStyles.heading3,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (v) {
                          final n = int.tryParse(v) ?? 0;
                          ref
                              .read(eventDraftProvider.notifier)
                              .setGuestCount(n);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xxl),
          PrimaryButton(
            label: 'Continue to menu',
            icon: PhosphorIconsBold.arrowRight,
            onPressed: draft.isComplete
                ? () => context.push(AppRoutes.menu)
                : null,
          ),
          const SizedBox(height: AppSizes.lg),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}
