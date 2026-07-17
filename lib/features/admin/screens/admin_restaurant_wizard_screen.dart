import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/photon_geocoder.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/admin_restaurant_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/restaurant_card.dart';
import '../../../shared/widgets/veg_dot.dart';
import '../../user/widgets/photo_picker_sheet.dart';
import '../widgets/menu_item_form_sheet.dart';
import '../widgets/restaurant_status_badge.dart';

// Admin console indigo.
const _indigo = Color(0xFF4338CA);

const _emojiPresets = ['🍽️', '🍛', '🥘', '🍗', '🥗', '🍜', '🫓', '🍰'];
const _bgPresets = [
  '#FFF3E0',
  '#EDE7F6',
  '#E8F5E9',
  '#FFF8E1',
  '#FFEBEE',
  '#EBF4FF',
  '#FCE8F0',
  '#F3E8FF',
];

/// 5-step restaurant onboarding: Basics → Location & pricing → Images →
/// Menu → Preview & publish.
///
/// Step 1 creates the row as a hidden draft immediately, so progress is
/// never lost — an abandoned wizard shows up under the "Draft" filter and
/// can be finished from the management page. Publishing runs through the
/// phase34 DB gate; its error message is shown verbatim if the restaurant
/// is still incomplete.
class AdminRestaurantWizardScreen extends ConsumerStatefulWidget {
  const AdminRestaurantWizardScreen({super.key, this.restaurantId});

  /// When set, the wizard opens in edit mode: the existing restaurant is
  /// loaded and every step is prefilled. Used by the management page's
  /// "Edit details" and to resume abandoned drafts.
  final String? restaurantId;

  @override
  ConsumerState<AdminRestaurantWizardScreen> createState() =>
      _AdminRestaurantWizardScreenState();
}

class _AdminRestaurantWizardScreenState
    extends ConsumerState<AdminRestaurantWizardScreen> {
  static const _titles = [
    'Basics',
    'Location & pricing',
    'Images',
    'Menu',
    'Preview & publish',
  ];

  int _step = 0;
  Restaurant? _draft;
  bool _busy = false;
  bool _loading = false;
  String? _error;

  // Step 1 — basics.
  final _nameCtrl = TextEditingController();
  final _cuisinesCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  bool _pureVeg = false;

  // Step 2 — location & pricing.
  final _addressCtrl = TextEditingController();
  final _geocoder = PhotonGeocoder();
  Timer? _geoDebounce;
  List<GeocodeResult> _suggestions = const [];
  bool _searching = false;
  double? _lat;
  double? _lng;
  final _priceCtrl = TextEditingController();
  final _minGuestsCtrl = TextEditingController();
  final _deliveryChargeCtrl = TextEditingController();
  final _etaMinCtrl = TextEditingController();
  final _etaMaxCtrl = TextEditingController();

  // Step 3 — branding.
  String _emoji = '🍽️';
  String _bgHex = '#FFF3E0';
  bool _uploadingLogo = false;
  bool _uploadingCover = false;

  @override
  void initState() {
    super.initState();
    if (widget.restaurantId != null) _loadExisting(widget.restaurantId!);
  }

  /// Edit mode: fetch the restaurant and prefill every step.
  Future<void> _loadExisting(String id) async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(adminRestaurantRepositoryProvider).fetchById(id);
      if (!mounted) return;
      if (r == null) {
        setState(() {
          _loading = false;
          _error = 'Restaurant not found.';
        });
        return;
      }
      _draft = r;
      _nameCtrl.text = r.name;
      _cuisinesCtrl.text = r.cuisinesDisplay ?? '';
      _tagCtrl.text = r.tag ?? '';
      _pureVeg = r.isPureVeg;
      _addressCtrl.text = r.address ?? '';
      _lat = r.latitude;
      _lng = r.longitude;
      if (r.pricePerPlate != null) {
        _priceCtrl.text = r.pricePerPlate!.toStringAsFixed(0);
      }
      if (r.minGuests != null) _minGuestsCtrl.text = '${r.minGuests}';
      if (r.deliveryCharge > 0) {
        _deliveryChargeCtrl.text = r.deliveryCharge.toStringAsFixed(0);
      }
      if (r.deliveryMinMinutes != null) {
        _etaMinCtrl.text = '${r.deliveryMinMinutes}';
      }
      if (r.deliveryMaxMinutes != null) {
        _etaMaxCtrl.text = '${r.deliveryMaxMinutes}';
      }
      _emoji = r.heroEmoji ?? _emoji;
      _bgHex = r.heroBgHex ?? _bgHex;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errText(e);
      });
    }
  }

  @override
  void dispose() {
    _geoDebounce?.cancel();
    for (final c in [
      _nameCtrl,
      _cuisinesCtrl,
      _tagCtrl,
      _addressCtrl,
      _priceCtrl,
      _minGuestsCtrl,
      _deliveryChargeCtrl,
      _etaMinCtrl,
      _etaMaxCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Step actions ──────────────────────────────────────────────────────────

  Future<void> _saveBasics() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Restaurant name is required.');
      return;
    }
    await _run(() async {
      final repo = ref.read(adminRestaurantRepositoryProvider);
      if (_draft == null) {
        // The moment of birth: a hidden draft row. Everything after this
        // is an update — abandoning the wizard loses nothing.
        _draft = await repo.createDraft(
          name: name,
          cuisinesDisplay: _cuisinesCtrl.text,
          isPureVeg: _pureVeg,
          tag: _tagCtrl.text,
        );
      } else {
        _draft = await repo.update(
          _draft!.id,
          name: name,
          cuisinesDisplay: _cuisinesCtrl.text.trim(),
          isPureVeg: _pureVeg,
          tag: _tagCtrl.text, // empty clears
        );
      }
      ref.invalidate(adminRestaurantListProvider);
      _step = 1;
    });
  }

  Future<void> _saveLocationAndPricing() async {
    await _run(() async {
      final repo = ref.read(adminRestaurantRepositoryProvider);
      _draft = await repo.update(
        _draft!.id,
        address:
            _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        latitude: _lat,
        longitude: _lng,
        pricePerPlate: double.tryParse(_priceCtrl.text.trim()),
        minGuests: int.tryParse(_minGuestsCtrl.text.trim()),
        deliveryCharge: double.tryParse(_deliveryChargeCtrl.text.trim()),
        deliveryMinMinutes: int.tryParse(_etaMinCtrl.text.trim()),
        deliveryMaxMinutes: int.tryParse(_etaMaxCtrl.text.trim()),
      );
      _step = 2;
    });
  }

  Future<void> _saveBranding() async {
    await _run(() async {
      final repo = ref.read(adminRestaurantRepositoryProvider);
      _draft = await repo.update(
        _draft!.id,
        heroEmoji: _emoji,
        heroBgHex: _bgHex,
      );
      _step = 3;
    });
  }

  Future<void> _publish() async {
    await _run(() async {
      final repo = ref.read(adminRestaurantRepositoryProvider);
      _draft = await repo.setStatus(_draft!.id, RestaurantStatus.published);
      // Refresh admin + customer worlds: the new restaurant is live.
      ref.invalidate(adminRestaurantListProvider);
      ref.invalidate(restaurantsProvider);
      ref.invalidate(menuItemsProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${_draft!.name}" is live for customers 🎉'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    });
  }

  void _saveDraftAndExit() {
    // Every step already persisted — just leave.
    ref.invalidate(adminRestaurantListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${_draft?.name ?? 'Draft'}" saved as draft'),
      ),
    );
    context.pop();
  }

  /// Shared busy/error wrapper for the async step actions.
  Future<void> _run(Future<void> Function() body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await body();
    } catch (e) {
      _error = _errText(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _errText(Object e) {
    if (e is PostgrestException) return e.message;
    final s = e.toString();
    if (s.startsWith('Bad state: ')) return s.substring('Bad state: '.length);
    return s.split('\n').first;
  }

  // ── Geocoding (step 2) ────────────────────────────────────────────────────

  void _onAddressChanged(String value) {
    _lat = null; // typed text invalidates the previously pinned point
    _lng = null;
    _geoDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _geoDebounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _searching = true);
      final results = await _geocoder.search(value, limit: 5);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _suggestions = results;
      });
    });
  }

  void _pickSuggestion(GeocodeResult r) {
    setState(() {
      _addressCtrl.text = r.displayAddress;
      _lat = r.latitude;
      _lng = r.longitude;
      _suggestions = const [];
    });
  }

  // ── Images (step 3) ───────────────────────────────────────────────────────

  Future<void> _pickImage({required bool cover}) async {
    final result = await showPhotoPickerSheet(
      context,
      title: cover ? 'Cover image' : 'Restaurant logo',
    );
    if (result is! PhotoPickedBytes) {
      if (result is PhotoPickerError && mounted) {
        setState(() => _error = result.message);
      }
      return;
    }
    setState(() {
      _error = null;
      if (cover) {
        _uploadingCover = true;
      } else {
        _uploadingLogo = true;
      }
    });
    try {
      final repo = ref.read(adminRestaurantRepositoryProvider);
      final url = cover
          ? await repo.uploadCover(
              restaurantId: _draft!.id, bytes: result.bytes)
          : await repo.uploadLogo(
              restaurantId: _draft!.id, bytes: result.bytes);
      _draft = cover
          ? _draft!.copyWith(coverImageUrl: url)
          : _draft!.copyWith(logoUrl: url);
    } catch (e) {
      _error = _errText(e);
    } finally {
      if (mounted) {
        setState(() {
          _uploadingLogo = false;
          _uploadingCover = false;
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final published = _draft?.status == RestaurantStatus.published;
    return AppScaffold(
      padded: false,
      appBar: AppBar(
        title: Text(_draft == null ? 'Onboard restaurant' : _draft!.name),
        leading: IconButton(
          icon: const Icon(PhosphorIconsBold.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_draft != null && !published)
            TextButton(
              onPressed: _busy ? null : _saveDraftAndExit,
              child: const Text('Save & exit'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProgressHeader(step: _step, titles: _titles),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      AppSizes.md,
                      AppSizes.pagePadding,
                      AppSizes.xl,
                    ),
                    child: switch (_step) {
                      0 => _buildBasics(),
                      1 => _buildLocationPricing(),
                      2 => _buildImages(),
                      3 => _buildMenu(),
                      _ => _buildPreview(),
                    },
                  ),
                ),
                _Footer(
                  step: _step,
                  busy: _busy,
                  error: _error,
                  onBack: _step == 0 || _busy
                      ? null
                      : () => setState(() {
                            _error = null;
                            _step -= 1;
                          }),
                  primaryLabel: switch (_step) {
                    0 => _draft == null
                        ? 'Create draft & continue'
                        : 'Save & continue',
                    1 => 'Save & continue',
                    2 => 'Save & continue',
                    3 => 'Continue',
                    // Editing an already-live restaurant: nothing to publish.
                    _ => published ? 'Done' : 'Publish now',
                  },
                  onPrimary: _busy
                      ? null
                      : switch (_step) {
                          0 => _saveBasics,
                          1 => _saveLocationAndPricing,
                          2 => _saveBranding,
                          3 => () => setState(() => _step = 4),
                          _ => published ? () => context.pop() : _publish,
                        },
                ),
              ],
            ),
    );
  }

  // ── Step 1: basics ────────────────────────────────────────────────────────

  Widget _buildBasics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Restaurant name *'),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _dec('e.g. Spice Route Catering'),
        ),
        const SizedBox(height: AppSizes.md),
        _label('Cuisines'),
        TextField(
          controller: _cuisinesCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _dec('e.g. North Indian · Mughlai · Biryani'),
        ),
        const SizedBox(height: AppSizes.md),
        _label('Card tag (optional)'),
        TextField(
          controller: _tagCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _dec('e.g. Bestseller / Event Special'),
        ),
        const SizedBox(height: AppSizes.sm),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.veg,
          title: Text('Pure veg kitchen', style: AppTextStyles.bodyBold),
          subtitle: Text(
            'Shows the pure-veg badge and the veg-only home filter',
            style: AppTextStyles.caption,
          ),
          value: _pureVeg,
          onChanged: (v) => setState(() => _pureVeg = v),
        ),
        const SizedBox(height: AppSizes.sm),
        _hint(
          'The restaurant is created as a hidden draft — customers can\'t '
          'see it until you publish in the last step.',
        ),
      ],
    );
  }

  // ── Step 2: location & pricing ────────────────────────────────────────────

  Widget _buildLocationPricing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Address *'),
        TextField(
          controller: _addressCtrl,
          onChanged: _onAddressChanged,
          maxLines: 2,
          minLines: 1,
          decoration: _dec('Search the restaurant address…').copyWith(
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _lat != null
                    ? const Icon(
                        PhosphorIconsFill.mapPin,
                        color: AppColors.success,
                        size: 20,
                      )
                    : null,
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSizes.xs),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final s in _suggestions)
                  ListTile(
                    dense: true,
                    leading: const Icon(PhosphorIconsRegular.mapPin, size: 18),
                    title: Text(s.name, style: AppTextStyles.bodyBold),
                    subtitle: Text(
                      s.displayAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    onTap: () => _pickSuggestion(s),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSizes.xs),
        _hint(
          _lat == null
              ? 'Pick a suggestion to pin the map location — it powers the '
                  '"nearest first" sorting customers see.'
              : 'Location pinned ✓',
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Price per plate (₹) *'),
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec('e.g. 300'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Min guests *'),
                  TextField(
                    controller: _minGuestsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec('e.g. 10'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        _label('Delivery charge (₹)'),
        TextField(
          controller: _deliveryChargeCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _dec('e.g. 1200'),
        ),
        const SizedBox(height: AppSizes.md),
        _label('Prep / delivery time (minutes)'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _etaMinCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('From, e.g. 30'),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: TextField(
                controller: _etaMaxCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('To, e.g. 45'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: images & branding ─────────────────────────────────────────────

  Widget _buildImages() {
    final d = _draft!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Card logo * (square works best)'),
        _ImageTile(
          url: d.logoUrl,
          uploading: _uploadingLogo,
          emptyLabel: 'Upload logo',
          onTap: _busy ? null : () => _pickImage(cover: false),
        ),
        const SizedBox(height: AppSizes.md),
        _label('Cover image (optional, wide)'),
        _ImageTile(
          url: d.coverImageUrl,
          uploading: _uploadingCover,
          emptyLabel: 'Upload cover',
          onTap: _busy ? null : () => _pickImage(cover: true),
        ),
        const SizedBox(height: AppSizes.lg),
        _label('Fallback emoji (shown while the image loads)'),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final e in _emojiPresets)
              InkWell(
                onTap: () => setState(() => _emoji = e),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _emoji == e
                        ? AppColors.fromHex(_bgHex)
                        : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    border: Border.all(
                      color: _emoji == e ? _indigo : AppColors.border,
                      width: _emoji == e ? 2 : 1,
                    ),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.lg),
        _label('Card background tint'),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final hex in _bgPresets)
              InkWell(
                onTap: () => setState(() => _bgHex = hex),
                borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.fromHex(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _bgHex == hex ? _indigo : AppColors.border,
                      width: _bgHex == hex ? 2.5 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Step 4: menu ──────────────────────────────────────────────────────────

  Widget _buildMenu() {
    final d = _draft!;
    final itemsAsync = ref.watch(adminRestaurantMenuProvider(d.id));
    final items = itemsAsync.valueOrNull ?? const <MenuItem>[];
    final available = items.where((i) => i.isAvailable).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$available available · ${items.length} total',
                style: AppTextStyles.bodyMuted,
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
              ),
              onPressed: _busy ? null : () => _addOrEditItem(),
              icon: const Icon(PhosphorIconsBold.plus, size: 16),
              label: const Text('Add item'),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        if (available == 0)
          _hint('At least one available menu item is required to publish.'),
        const SizedBox(height: AppSizes.sm),
        if (itemsAsync.isLoading && items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.xl),
              child: CircularProgressIndicator(),
            ),
          )
        else
          for (final item in items) ...[
            _MenuItemRow(
              item: item,
              onEdit: () => _addOrEditItem(existing: item),
              onToggle: (v) => _toggleItem(item, v),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
      ],
    );
  }

  Future<void> _addOrEditItem({MenuItem? existing}) async {
    final saved = await MenuItemFormSheet.show(
      context,
      existing: existing,
      lockedRestaurant: _draft,
    );
    if (saved == true) {
      ref.invalidate(adminRestaurantMenuProvider(_draft!.id));
    }
  }

  Future<void> _toggleItem(MenuItem item, bool value) async {
    await ref
        .read(menuRepositoryProvider)
        .setMenuItemAvailability(id: item.id, isAvailable: value);
    ref.invalidate(adminRestaurantMenuProvider(_draft!.id));
    ref.invalidate(adminMenuItemsProvider);
    ref.invalidate(menuItemsProvider);
  }

  // ── Step 5: preview & publish ─────────────────────────────────────────────

  Widget _buildPreview() {
    final d = _draft!;
    final items =
        ref.watch(adminRestaurantMenuProvider(d.id)).valueOrNull ?? const [];
    final hasAvailableItem = items.any((i) => i.isAvailable);

    final checks = <(String, bool)>[
      ('Name', d.name.trim().isNotEmpty),
      ('Price per plate', (d.pricePerPlate ?? 0) > 0),
      ('Minimum guests', (d.minGuests ?? 0) > 0),
      (
        'Address & map location',
        (d.address ?? '').isNotEmpty &&
            d.latitude != null &&
            d.longitude != null
      ),
      ('Logo or cover image', d.logoUrl != null || d.coverImageUrl != null),
      ('At least 1 available menu item', hasAvailableItem),
    ];
    final ready = checks.every((c) => c.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Customer preview', style: AppTextStyles.heading2),
            const Spacer(),
            RestaurantStatusBadge(status: d.status),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          'This is the exact card customers will see on the home feed.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSizes.md),
        RestaurantCard(restaurant: d, interactive: false),
        const SizedBox(height: AppSizes.lg),
        Text('Publish checklist', style: AppTextStyles.heading2),
        const SizedBox(height: AppSizes.sm),
        Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (final (label, ok) in checks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        ok
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.circle,
                        size: 18,
                        color: ok ? AppColors.success : AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: AppTextStyles.body.copyWith(
                            color: ok
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        if (!ready)
          _hint(
            'You can still save as a draft — the missing details can be '
            'added later from the management page.',
          ),
      ],
    );
  }

  // ── Small shared bits ─────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.xs),
        child: Text(
          text,
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _hint(String text) => Container(
        padding: const EdgeInsets.all(AppSizes.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.catBlueLt,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              PhosphorIconsRegular.info,
              size: 16,
              color: AppColors.catBlue,
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.caption.copyWith(color: AppColors.catBlue),
              ),
            ),
          ],
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: _indigo, width: 1.4),
        ),
      );
}

// ───────────────────────── Progress header ─────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.titles});

  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.sm,
        AppSizes.pagePadding,
        AppSizes.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${step + 1} of ${titles.length} · ${titles[step]}',
            style: AppTextStyles.captionBold
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              for (var i = 0; i < titles.length; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= step ? _indigo : AppColors.border,
                      borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                    ),
                  ),
                ),
                if (i < titles.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Footer ─────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.step,
    required this.busy,
    required this.error,
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final int step;
  final bool busy;
  final String? error;
  final VoidCallback? onBack;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Text(
              error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
          Row(
            children: [
              if (step > 0) ...[
                OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: AppTextStyles.buttonLabel
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                    backgroundColor: _indigo,
                    minimumSize: const Size.fromHeight(48),
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          primaryLabel,
                          style: AppTextStyles.buttonLabel
                              .copyWith(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Image tile ─────────────────────────

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.url,
    required this.uploading,
    required this.emptyLabel,
    required this.onTap,
  });

  final String? url;
  final bool uploading;
  final String emptyLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: uploading ? null : onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: uploading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : url == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        PhosphorIconsRegular.uploadSimple,
                        size: 24,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        emptyLabel,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(url!, fit: BoxFit.cover),
                      Positioned(
                        right: AppSizes.sm,
                        bottom: AppSizes.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusXs),
                          ),
                          child: Text(
                            'Change',
                            style: AppTextStyles.captionBold
                                .copyWith(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ───────────────────────── Menu item row ─────────────────────────

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.item,
    required this.onEdit,
    required this.onToggle,
  });

  final MenuItem item;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          VegDot(isVeg: item.isVeg),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold,
                ),
                Text(
                  '₹${item.price.toStringAsFixed(0)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
            color: AppColors.textSecondary,
            onPressed: onEdit,
          ),
          Switch.adaptive(
            value: item.isAvailable,
            activeThumbColor: _indigo,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
