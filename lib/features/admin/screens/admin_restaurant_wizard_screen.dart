import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/constants/app_colors.dart';
import '../../../data/models/menu_category.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/restaurant.dart';
import '../../../shared/providers/admin_restaurant_providers.dart';
import '../../../shared/providers/menu_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/restaurant_card.dart';
import '../../user/widgets/photo_picker_sheet.dart';
import '../widgets/admin_ui.dart';
import '../widgets/menu_item_form_sheet.dart';

/// Fixed cuisine vocabulary, mirroring the Admin Console design. Admins can
/// still add one outside this list (see [AdminChipSelect.allowCustom]) — the
/// list exists to keep the common cases spelled consistently, since the
/// customer-facing kitchen search matches on this text.
const _cuisineOptions = [
  'North Indian',
  'South Indian',
  'Mughlai',
  'Gujarati',
  'Punjabi',
  'Chinese',
  'Continental',
  'Chaat',
];

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

/// Cuisines are stored as one human display string ("North Indian · Mughlai").
/// These two helpers are the only place that format is interpreted, so the
/// chip picker can round-trip existing free-text records without a migration.
///
/// Legacy rows were typed by hand, so the split tolerates comma separators and
/// stray whitespace as well as the "·" the app writes.
List<String> splitCuisines(String? display) {
  if (display == null || display.trim().isEmpty) return const [];
  return display
      .split(RegExp(r'[·,]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Inverse of [splitCuisines] — the exact format written back to the record.
String joinCuisines(List<String> values) => values.join(' · ');

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
  final _tagCtrl = TextEditingController();
  List<String> _cuisines = [];
  bool _pureVeg = false;

  // Step 2 — location & pricing. The address text + pin are owned by
  // [AdminAddressPin]; we keep only the resolved values.
  String _address = '';
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
      _cuisines = splitCuisines(r.cuisinesDisplay);
      _tagCtrl.text = r.tag ?? '';
      _pureVeg = r.isPureVeg;
      _address = r.address ?? '';
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
    for (final c in [
      _nameCtrl,
      _tagCtrl,
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
          cuisinesDisplay: joinCuisines(_cuisines),
          isPureVeg: _pureVeg,
          tag: _tagCtrl.text,
        );
      } else {
        _draft = await repo.update(
          _draft!.id,
          name: name,
          cuisinesDisplay: joinCuisines(_cuisines),
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
        address: _address.trim().isEmpty ? null : _address.trim(),
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
      adminToast(context, '"${_draft!.name}" is live for customers 🎉');
      context.pop();
    });
  }

  void _saveDraftAndExit() {
    // Every step already persisted — just leave.
    ref.invalidate(adminRestaurantListProvider);
    adminToast(context, '"${_draft?.name ?? 'Draft'}" saved as draft');
    context.pop();
  }

  /// Back behaviour for the header arrow: step back through the wizard first,
  /// and only leave the screen from the first step. (Previously the arrow
  /// always exited, which read as "discard" mid-flow.)
  void _onHeaderBack() {
    if (_step > 0 && !_busy) {
      setState(() {
        _error = null;
        _step -= 1;
      });
      return;
    }
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
    return AdminScaffold(
      active: AdminNav.kitchens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminBar(
            title: _draft == null ? 'Onboard kitchen' : _draft!.name,
            subtitle: 'Step ${_step + 1} of ${_titles.length} · '
                '${_titles[_step]}',
            onBack: _onHeaderBack,
            trailing:
                _draft == null ? null : AdminBadge(status: _draft!.status),
          ),
          _StepBar(step: _step, count: _titles.length),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AdminColors.indigo),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
            // Persistent draft escape hatch, as in the design — available on
            // every step once the draft row exists and isn't already live.
            onSaveDraft: (_draft != null && !published && !_busy)
                ? _saveDraftAndExit
                : null,
            primaryLabel: switch (_step) {
              0 =>
                _draft == null ? 'Create draft & continue' : 'Save & continue',
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
        AdminField(
          label: 'Kitchen name',
          required: true,
          child: TextField(
            controller: _nameCtrl,
            style: adminTextStyle,
            textCapitalization: TextCapitalization.words,
            decoration: adminInput('e.g. Spice Route Catering'),
          ),
        ),
        const SizedBox(height: 16),
        AdminField(
          label: 'Cuisines',
          hint: 'Tap to select',
          child: AdminChipSelect(
            options: _cuisineOptions,
            selected: _cuisines,
            allowCustom: true,
            customHint: 'Other cuisine…',
            onChanged: (next) => setState(() => _cuisines = next),
          ),
        ),
        const SizedBox(height: 16),
        AdminField(
          label: 'Card tag',
          hint: 'Optional',
          child: TextField(
            controller: _tagCtrl,
            style: adminTextStyle,
            textCapitalization: TextCapitalization.words,
            decoration: adminInput('e.g. Bestseller / Event Special'),
          ),
        ),
        const SizedBox(height: 16),
        _VegCard(
          value: _pureVeg,
          onChanged: (v) => setState(() => _pureVeg = v),
        ),
        const SizedBox(height: 16),
        const AdminHint(
          'The kitchen is created as a hidden draft — customers cannot see it '
          'until you publish in the last step.',
        ),
      ],
    );
  }

  // ── Step 2: location & pricing ────────────────────────────────────────────

  Widget _buildLocationPricing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminField(
          label: 'Address',
          required: true,
          child: AdminAddressPin(
            initialText: _address,
            pinned: _lat != null && _lng != null,
            onTyping: () => setState(() {
              // Typed text invalidates the previously pinned point.
              _lat = null;
              _lng = null;
            }),
            onPick: (address, lat, lng) => setState(() {
              _address = address;
              _lat = lat;
              _lng = lng;
            }),
          ),
        ),
        const SizedBox(height: 10),
        const AdminHint(
          'Pick a suggestion to pin the map location — it powers the '
          '"nearest first" sorting customers see.',
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AdminField(
                label: 'Price per plate (₹)',
                required: true,
                child: TextField(
                  controller: _priceCtrl,
                  style: adminTextStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: adminInput('300'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AdminField(
                label: 'Min guests',
                required: true,
                child: TextField(
                  controller: _minGuestsCtrl,
                  style: adminTextStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: adminInput('10'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdminField(
          label: 'Delivery charge (₹)',
          child: TextField(
            controller: _deliveryChargeCtrl,
            style: adminTextStyle,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: adminInput('1200'),
          ),
        ),
        const SizedBox(height: 16),
        AdminField(
          label: 'Prep / delivery time (minutes)',
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _etaMinCtrl,
                  style: adminTextStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: adminInput('From, e.g. 30'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _etaMaxCtrl,
                  style: adminTextStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: adminInput('To, e.g. 45'),
                ),
              ),
            ],
          ),
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
        AdminField(
          label: 'Card logo',
          required: true,
          hint: 'Square works best',
          child: AdminImageTile(
            url: d.logoUrl,
            uploading: _uploadingLogo,
            emptyLabel: 'Upload logo',
            onTap: _busy ? null : () => _pickImage(cover: false),
          ),
        ),
        const SizedBox(height: 16),
        AdminField(
          label: 'Cover image',
          hint: 'Optional',
          child: AdminImageTile(
            url: d.coverImageUrl,
            uploading: _uploadingCover,
            emptyLabel: 'Upload cover',
            onTap: _busy ? null : () => _pickImage(cover: true),
          ),
        ),
        const SizedBox(height: 16),
        AdminField(
          label: 'Fallback emoji',
          hint: 'Shown while loading',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _emojiPresets)
                InkWell(
                  onTap: () => setState(() => _emoji = e),
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _emoji == e
                          ? AppColors.fromHex(_bgHex)
                          : AdminColors.bg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color:
                            _emoji == e ? AdminColors.indigo : AdminColors.line,
                        width: _emoji == e ? 2 : 1.5,
                      ),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AdminField(
          label: 'Card background tint',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in _bgPresets)
                InkWell(
                  onTap: () => setState(() => _bgHex = hex),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.fromHex(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _bgHex == hex
                            ? AdminColors.indigo
                            : AdminColors.line,
                        width: _bgHex == hex ? 2.5 : 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
    // Category names for the "Starters · ₹220" sub-line on each dish row.
    final categoryNames = <String, String>{
      for (final c in ref.watch(menuCategoriesProvider).valueOrNull ??
          const <MenuCategory>[])
        c.id: c.name,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$available available · ${items.length} total',
                style: AdminText.body,
              ),
            ),
            AdminButton(
              label: 'Add dish',
              size: 'sm',
              leading: PhosphorIconsBold.plus,
              disabled: _busy,
              onPressed: () => _addOrEditItem(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (available == 0)
          const AdminHint(
            'At least one available dish is required to publish.',
          ),
        const SizedBox(height: 12),
        if (itemsAsync.isLoading && items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(color: AdminColors.indigo),
            ),
          )
        else
          for (final item in items) ...[
            _MenuItemRow(
              item: item,
              categoryName: categoryNames[item.categoryId],
              onEdit: () => _addOrEditItem(existing: item),
              onToggle: (v) => _toggleItem(item, v),
            ),
            const SizedBox(height: 10),
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
      ('At least 1 available dish', hasAvailableItem),
    ];
    final ready = checks.every((c) => c.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminOverline('Customer preview'),
        const SizedBox(height: 6),
        Text(
          'The exact card customers will see on the home feed.',
          style: AdminText.cap,
        ),
        const SizedBox(height: 12),
        RestaurantCard(restaurant: d, interactive: false),
        const SizedBox(height: 22),
        Text('Publish checklist', style: AdminText.h2),
        const SizedBox(height: 10),
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final (label, ok) in checks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: ok ? AdminColors.liveBg : AdminColors.draftBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          ok ? PhosphorIconsBold.check : PhosphorIconsBold.x,
                          size: 12,
                          color: ok ? AdminColors.live : AdminColors.tx3,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          label,
                          style: AdminText.body.copyWith(
                            color: ok ? AdminColors.tx : AdminColors.tx3,
                            fontWeight: ok ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (ready)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AdminColors.liveBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(PhosphorIconsFill.checkCircle,
                    size: 18, color: AdminColors.live),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'All checks pass — ready to go live.',
                    style: AdminText.cap.copyWith(
                      color: AdminColors.live,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const AdminHint(
            'You can still save as a draft — the missing details can be added '
            'later from the management page.',
          ),
      ],
    );
  }
}

// ───────────────────────── Step progress bar ─────────────────────────

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.count});
  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      color: AdminColors.card,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? AdminColors.indigo : AdminColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            if (i < count - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Pure-veg card ─────────────────────────

class _VegCard extends StatelessWidget {
  const _VegCard({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.all(14),
      borderColor: value ? AdminColors.live : null,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value ? AdminColors.liveBg : AdminColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: AdminVegMark(isVeg: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pure veg kitchen', style: AdminText.h3),
                const SizedBox(height: 2),
                Text(
                  'Shows the pure-veg badge and the veg-only home filter',
                  style: AdminText.cap,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AdminToggle(value: value, onChanged: onChanged),
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
    required this.onSaveDraft,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final int step;
  final bool busy;
  final String? error;
  final VoidCallback? onBack;
  final VoidCallback? onSaveDraft;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      // AdminScaffold already applies the bottom SafeArea, so no manual
      // MediaQuery padding here (that would double-inset the footer).
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(top: BorderSide(color: AdminColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(PhosphorIconsFill.warningCircle,
                    size: 15, color: AdminColors.danger),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    error!,
                    style: AdminText.cap.copyWith(color: AdminColors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (step > 0) ...[
                AdminButton(
                  label: 'Back',
                  variant: AdminBtn.ghost,
                  size: 'lg',
                  leading: PhosphorIconsBold.arrowLeft,
                  disabled: onBack == null,
                  onPressed: onBack,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: AdminButton(
                  label: busy ? 'Working…' : primaryLabel,
                  size: 'lg',
                  expand: true,
                  disabled: busy || onPrimary == null,
                  onPressed: onPrimary,
                ),
              ),
            ],
          ),
          if (onSaveDraft != null) ...[
            const SizedBox(height: 8),
            AdminButton(
              label: 'Save draft & exit',
              variant: AdminBtn.ghost,
              expand: true,
              onPressed: onSaveDraft,
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Menu item row ─────────────────────────

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({
    required this.item,
    required this.categoryName,
    required this.onEdit,
    required this.onToggle,
  });

  final MenuItem item;

  /// Resolved category label ("Starters"); null while categories load or if
  /// the dish points at a category that no longer exists.
  final String? categoryName;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          AdminVegMark(isVeg: item.isVeg),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.h3,
                ),
                const SizedBox(height: 2),
                Text(
                  categoryName == null
                      ? '₹${item.price.toStringAsFixed(0)}'
                      : '$categoryName · ₹${item.price.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.cap,
                ),
              ],
            ),
          ),
          AdminIconButton(
            icon: PhosphorIconsRegular.pencilSimple,
            onTap: onEdit,
          ),
          const SizedBox(width: 6),
          AdminToggle(value: item.isAvailable, onChanged: onToggle),
        ],
      ),
    );
  }
}
