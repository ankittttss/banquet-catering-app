import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/photon_geocoder.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';

const _indigo = Color(0xFF4338CA);

/// Admin banquet-venue manager: onboard halls, keep their map locations
/// pinned, assign operators, and flip venues active/inactive.
///
/// Venues used to be hand-inserted in the database — which is how rows
/// without coordinates could exist, silently degrading the customer's
/// "restaurants near your event" sort back to their home address. Here the
/// address is picked from geocoder suggestions so coordinates are captured
/// automatically, and an ACTIVE venue cannot be saved without a pinned
/// location (mirrored by the banquet_venues_active_needs_location DB guard).
class AdminVenuesScreen extends ConsumerWidget {
  const AdminVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(adminVenuesProvider);
    final operators = ref.watch(banquetOperatorsProvider).valueOrNull;
    // ownerProfileId → operator display name, best-effort.
    final operatorNames = <String, String>{
      for (final p in operators ?? const <UserProfile>[])
        p.id: p.name ?? p.email ?? 'Operator',
    };

    return AppScaffold(
      appBar: AppBar(
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(PhosphorIconsBold.arrowLeft),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('Banquet venues'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        icon: const Icon(PhosphorIconsBold.plus),
        label: const Text('Add venue'),
        onPressed: () => _VenueFormSheet.show(context),
      ),
      body: venuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(adminVenuesProvider),
        ),
        data: (venues) {
          if (venues.isEmpty) {
            return const EmptyState(
              icon: PhosphorIconsDuotone.buildings,
              title: 'No venues yet',
              message:
                  'Add the first banquet hall — customers pick one of these '
                  'while planning a hall event.',
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(adminVenuesProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, AppSizes.md, 0, 96),
              itemCount: venues.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (_, i) => _VenueRow(
                venue: venues[i],
                operatorName: operatorNames[venues[i].ownerProfileId],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Venue row ─────────────────────────

class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.venue, this.operatorName});
  final BanquetVenue venue;
  final String? operatorName;

  bool get _missingPin => venue.latitude == null || venue.longitude == null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: () => _VenueFormSheet.show(context, existing: venue),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  PhosphorIconsDuotone.buildings,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            venue.name,
                            style: AppTextStyles.bodyBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSizes.xs),
                        _Pill(
                          label: venue.isActive ? 'ACTIVE' : 'INACTIVE',
                          bg: venue.isActive
                              ? AppColors.catGreenLt
                              : AppColors.surfaceAlt,
                          fg: venue.isActive
                              ? AppColors.catGreen
                              : AppColors.textMuted,
                        ),
                      ],
                    ),
                    if (venue.address != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        venue.address!,
                        style: AppTextStyles.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSizes.xs),
                    Wrap(
                      spacing: AppSizes.xs,
                      runSpacing: 4,
                      children: [
                        if (_missingPin)
                          const _Pill(
                            label: 'NO MAP PIN',
                            bg: AppColors.catGoldLt,
                            fg: AppColors.accentDark,
                          ),
                        if (venue.capacity != null)
                          _Pill(
                            label: 'UP TO ${venue.capacity}',
                            bg: AppColors.catBlueLt,
                            fg: AppColors.catBlue,
                          ),
                        if (operatorName != null)
                          _Pill(
                            label: operatorName!.toUpperCase(),
                            bg: AppColors.surfaceAlt,
                            fg: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(color: fg, fontSize: 9),
      ),
    );
  }
}

// ───────────────────────── Add / edit form sheet ─────────────────────────

class _VenueFormSheet extends ConsumerStatefulWidget {
  const _VenueFormSheet({this.existing});
  final BanquetVenue? existing;

  static Future<bool?> show(BuildContext context, {BanquetVenue? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      builder: (_) => _VenueFormSheet(existing: existing),
    );
  }

  @override
  ConsumerState<_VenueFormSheet> createState() => _VenueFormSheetState();
}

class _VenueFormSheetState extends ConsumerState<_VenueFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _capacityCtrl;

  final _geocoder = PhotonGeocoder();
  Timer? _geoDebounce;
  List<GeocodeResult> _suggestions = const [];
  bool _searching = false;

  double? _lat;
  double? _lng;
  String? _ownerId;
  bool _isActive = true;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _addressCtrl = TextEditingController(text: v?.address ?? '');
    _capacityCtrl = TextEditingController(text: v?.capacity?.toString() ?? '');
    _lat = v?.latitude;
    _lng = v?.longitude;
    _ownerId = v?.ownerProfileId;
    _isActive = v?.isActive ?? true;
  }

  @override
  void dispose() {
    _geoDebounce?.cancel();
    _geocoder.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  // ── Geocoding — same pattern as the restaurant wizard ──

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

  // ── Save ──

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final capacity = int.tryParse(_capacityCtrl.text.trim());

    if (name.isEmpty) {
      setState(() => _error = 'Give the venue a name.');
      return;
    }
    if (_ownerId == null) {
      setState(() => _error = 'Pick the banquet operator who runs this venue.');
      return;
    }
    // Mirror of the DB guard (banquet_venues_active_needs_location): an
    // active venue must carry an address AND a pinned location, otherwise
    // customers get restaurants sorted around the wrong point.
    if (_isActive && (address.isEmpty || _lat == null || _lng == null)) {
      setState(() {
        _error = 'An active venue needs a pinned location — search the '
            'address and tap a suggestion. Or save it as inactive for now.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(banquetRepositoryProvider);
      if (_isEdit) {
        await repo.updateVenue(
          venueId: widget.existing!.id,
          ownerProfileId: _ownerId!,
          name: name,
          address: address.isEmpty ? null : address,
          latitude: _lat,
          longitude: _lng,
          capacity: capacity,
          isActive: _isActive,
        );
      } else {
        await repo.createVenue(
          ownerProfileId: _ownerId!,
          name: name,
          address: address.isEmpty ? null : address,
          latitude: _lat,
          longitude: _lng,
          capacity: capacity,
          isActive: _isActive,
        );
      }
      // Refresh the admin list and the customer-side picker.
      ref.invalidate(adminVenuesProvider);
      ref.invalidate(allBanquetVenuesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _friendly(e);
        });
      }
    }
  }

  static String _friendly(Object e) {
    if (e is PostgrestException) return e.message;
    final first = e.toString().split('\n').first;
    return first.length > 160 ? '${first.substring(0, 160)}…' : first;
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final operatorsAsync = ref.watch(banquetOperatorsProvider);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Text(
                _isEdit ? 'Edit venue' : 'Add venue',
                style: AppTextStyles.display,
              ),
              const SizedBox(height: AppSizes.lg),
              _label('Venue name *'),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _dec('e.g. Grand Palace Banquets'),
              ),
              const SizedBox(height: AppSizes.md),
              _label('Address *'),
              TextField(
                controller: _addressCtrl,
                onChanged: _onAddressChanged,
                maxLines: 2,
                minLines: 1,
                decoration: _dec('Search the venue address…').copyWith(
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
                          leading: const Icon(
                            PhosphorIconsRegular.mapPin,
                            size: 18,
                          ),
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
              Text(
                _lat == null
                    ? 'Pick a suggestion to pin the map location — it drives '
                        'the "restaurants near your event" sorting customers see.'
                    : 'Location pinned ✓',
                style: AppTextStyles.caption.copyWith(
                  color:
                      _lat == null ? AppColors.accentDark : AppColors.success,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _label('Capacity (guests)'),
              TextField(
                controller: _capacityCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('e.g. 300'),
              ),
              const SizedBox(height: AppSizes.md),
              _label('Banquet operator *'),
              operatorsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Text(
                  'Could not load operators: ${_friendly(e)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
                data: (ops) {
                  if (ops.isEmpty) {
                    return Text(
                      'No banquet-operator accounts exist yet — create one '
                      'first, then add the venue.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.accentDark),
                    );
                  }
                  // Preselect when there's exactly one operator; guard the
                  // dropdown against a saved owner that no longer exists.
                  final ids = ops.map((o) => o.id).toSet();
                  final value = ids.contains(_ownerId) ? _ownerId : null;
                  if (value == null && ops.length == 1) {
                    _ownerId = ops.first.id;
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: ids.contains(_ownerId) ? _ownerId : null,
                    decoration: _dec('Pick an operator'),
                    items: [
                      for (final o in ops)
                        DropdownMenuItem(
                          value: o.id,
                          child: Text(
                            o.name ?? o.email ?? 'Operator',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _ownerId = v),
                  );
                },
              ),
              const SizedBox(height: AppSizes.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Active', style: AppTextStyles.bodyBold),
                subtitle: Text(
                  'Active venues appear in the customer venue picker.',
                  style: AppTextStyles.caption,
                ),
                value: _isActive,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSizes.md),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _indigo,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Add venue'),
              ),
              const SizedBox(height: AppSizes.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.xs),
        child: Text(
          text,
          style: AppTextStyles.captionBold
              .copyWith(color: AppColors.textSecondary),
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      );
}
