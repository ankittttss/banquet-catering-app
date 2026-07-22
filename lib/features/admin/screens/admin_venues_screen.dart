import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/services/photon_geocoder.dart';
import '../../../data/models/banquet_venue.dart';
import '../../../data/models/user_profile.dart';
import '../../../shared/providers/banquet_providers.dart';
import '../../../shared/providers/repositories_providers.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../widgets/admin_ui.dart';

/// Admin banquet-venue manager. Onboard halls, keep their map location pinned,
/// assign operators and flip venues active/inactive. Redesigned to the indigo
/// admin identity; the DB guard (phase40) still enforces that an active venue
/// carries a pinned location, and the picker captures coordinates from
/// geocoder suggestions so they're never forgotten.
class AdminVenuesScreen extends ConsumerWidget {
  const AdminVenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venuesAsync = ref.watch(adminVenuesProvider);
    final operators = ref.watch(banquetOperatorsProvider).valueOrNull;
    final operatorNames = <String, String>{
      for (final p in operators ?? const <UserProfile>[])
        p.id: p.name ?? p.email ?? 'Operator',
    };

    final subtitle = venuesAsync.maybeWhen(
      data: (v) =>
          '${v.where((x) => x.isActive).length} active · ${v.length} total',
      orElse: () => null,
    );

    return AdminScaffold(
      active: AdminNav.venues,
      floatingActionButton: AdminFab(
        label: 'Add venue',
        onTap: () => _openSheet(context, ref),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminBar(
            title: 'Banquet venues',
            subtitle: subtitle,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: venuesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AdminColors.indigo),
              ),
              error: (e, _) => AppErrorView(
                error: e,
                onRetry: () => ref.invalidate(adminVenuesProvider),
              ),
              data: (venues) {
                if (venues.isEmpty) {
                  return const AdminMessageState(
                    icon: PhosphorIconsBold.mapPin,
                    title: 'No venues yet',
                    message:
                        'Add a banquet venue to show it in the customer venue picker.',
                  );
                }
                return RefreshIndicator(
                  color: AdminColors.indigo,
                  onRefresh: () async => ref.invalidate(adminVenuesProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Reserve room for the pinned "Add venue" button so it
                    // never covers the last venue card.
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      AdminScaffold.fabScrollPadding,
                    ),
                    itemCount: venues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _VenueRow(
                      venue: venues[i],
                      operatorName: operatorNames[venues[i].ownerProfileId],
                      onTap: () =>
                          _openSheet(context, ref, existing: venues[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, WidgetRef ref,
      {BanquetVenue? existing}) {
    showAdminSheet<void>(
      context,
      title: existing == null ? 'Add venue' : 'Edit venue',
      builder: (_) => _VenueForm(existing: existing),
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow(
      {required this.venue, required this.onTap, this.operatorName});
  final BanquetVenue venue;
  final String? operatorName;
  final VoidCallback onTap;

  bool get _noPin => venue.latitude == null || venue.longitude == null;

  @override
  Widget build(BuildContext context) {
    final active = venue.isActive;
    return AdminCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AdminColors.liveBg : AdminColors.archBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(PhosphorIconsDuotone.mapPin,
                size: 22, color: active ? AdminColors.live : AdminColors.arch),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(venue.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminText.h2),
                    ),
                    const SizedBox(width: 8),
                    AdminPill(
                      label: active ? 'ACTIVE' : 'INACTIVE',
                      fg: active ? AdminColors.live : AdminColors.arch,
                      bg: active ? AdminColors.liveBg : AdminColors.archBg,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(venue.address ?? 'No address set',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AdminText.cap),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (venue.capacity != null)
                      _MetaChip(
                          icon: PhosphorIconsRegular.users,
                          label: 'up to ${venue.capacity}'),
                    if (operatorName != null)
                      _MetaChip(
                          icon: PhosphorIconsRegular.diamond,
                          label: operatorName!),
                  ],
                ),
                if (_noPin) ...[
                  const SizedBox(height: 8),
                  const AdminPill(
                    label: 'NO MAP PIN',
                    icon: PhosphorIconsFill.info,
                    fg: AdminColors.susp,
                    bg: AdminColors.suspBg,
                    small: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(PhosphorIconsBold.caretRight,
              size: 18, color: AdminColors.tx3),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AdminColors.tx3),
        const SizedBox(width: 4),
        Text(label, style: AdminText.cap),
      ],
    );
  }
}

// ─────────────────────── Add / edit venue form ───────────────────────

class _VenueForm extends ConsumerStatefulWidget {
  const _VenueForm({this.existing});
  final BanquetVenue? existing;
  @override
  ConsumerState<_VenueForm> createState() => _VenueFormState();
}

class _VenueFormState extends ConsumerState<_VenueForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _capacityCtrl;

  double? _lat;
  double? _lng;
  String? _address;
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
    _capacityCtrl = TextEditingController(text: v?.capacity?.toString() ?? '');
    _address = v?.address;
    _lat = v?.latitude;
    _lng = v?.longitude;
    _ownerId = v?.ownerProfileId;
    _isActive = v?.isActive ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  bool get _canActivate =>
      (_address?.trim().isNotEmpty ?? false) && _lat != null && _lng != null;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final capacity = int.tryParse(_capacityCtrl.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Give the venue a name.');
      return;
    }
    if (_ownerId == null) {
      setState(() => _error = 'Pick the banquet operator who runs this venue.');
      return;
    }
    if (_isActive && !_canActivate) {
      setState(() => _error =
          'An active venue needs a pinned location — search the address and tap a suggestion.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(banquetRepositoryProvider);
      final addr = (_address?.trim().isEmpty ?? true) ? null : _address!.trim();
      if (_isEdit) {
        await repo.updateVenue(
          venueId: widget.existing!.id,
          ownerProfileId: _ownerId!,
          name: name,
          address: addr,
          latitude: _lat,
          longitude: _lng,
          capacity: capacity,
          isActive: _isActive,
        );
      } else {
        await repo.createVenue(
          ownerProfileId: _ownerId!,
          name: name,
          address: addr,
          latitude: _lat,
          longitude: _lng,
          capacity: capacity,
          isActive: _isActive,
        );
      }
      ref.invalidate(adminVenuesProvider);
      ref.invalidate(allBanquetVenuesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      adminToast(context, _isEdit ? 'Venue saved' : 'Venue added',
          success: true);
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

  @override
  Widget build(BuildContext context) {
    final operatorsAsync = ref.watch(banquetOperatorsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminField(
          label: 'Venue name',
          required: true,
          child: TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: adminTextStyle,
            decoration: adminInput('e.g. Lotus Banquet Hall'),
          ),
        ),
        const SizedBox(height: 14),
        AdminField(
          label: 'Address',
          required: true,
          hint: 'auto-pins coordinates',
          child: AdminAddressPin(
            initialText: _address,
            pinned: _lat != null && _lng != null,
            onPick: (addr, lat, lng) => setState(() {
              _address = addr;
              _lat = lat;
              _lng = lng;
            }),
            onTyping: () {
              // typed text without a suggestion drops any prior pin
              if (_lat != null || _lng != null)
                setState(() {
                  _lat = null;
                  _lng = null;
                });
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AdminField(
                label: 'Capacity',
                required: true,
                child: TextField(
                  controller: _capacityCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: adminTextStyle,
                  decoration: adminInput('0'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdminField(
                label: 'Operator',
                child: operatorsAsync.when(
                  loading: () => _selectShell(const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )),
                  error: (e, _) => Text('Load failed: ${_friendly(e)}',
                      style: AdminText.cap.copyWith(color: AdminColors.danger)),
                  data: (ops) {
                    if (ops.isEmpty) {
                      return Text('Create an operator account first.',
                          style:
                              AdminText.cap.copyWith(color: AdminColors.susp));
                    }
                    final ids = ops.map((o) => o.id).toSet();
                    if (_ownerId == null && ops.length == 1)
                      _ownerId = ops.first.id;
                    return _selectShell(
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: ids.contains(_ownerId) ? _ownerId : null,
                          hint: Text('Pick', style: AdminText.body),
                          style: adminTextStyle,
                          items: [
                            for (final o in ops)
                              DropdownMenuItem(
                                value: o.id,
                                child: Text(o.name ?? o.email ?? 'Operator',
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setState(() => _ownerId = v),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ActiveToggleRow(
          value: _isActive,
          canActivate: _canActivate,
          onChanged: (v) {
            if (v && !_canActivate) {
              setState(() => _error =
                  'Add an address + map pin before making the venue active.');
              return;
            }
            setState(() {
              _isActive = v;
              _error = null;
            });
          },
        ),
        if (!_canActivate) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(PhosphorIconsFill.info,
                  size: 14, color: AdminColors.susp),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'An address + map pin is required before a venue can be made active.',
                    style: AdminText.cap.copyWith(color: AdminColors.susp)),
              ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: AdminText.cap.copyWith(color: AdminColors.danger)),
        ],
        const SizedBox(height: 16),
        AdminButton(
          label: _saving ? 'Saving…' : (_isEdit ? 'Save changes' : 'Add venue'),
          size: 'lg',
          expand: true,
          disabled: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _selectShell(Widget child) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AdminColors.line, width: 1.5),
        ),
        child: child,
      );
}

class _ActiveToggleRow extends StatelessWidget {
  const _ActiveToggleRow({
    required this.value,
    required this.canActivate,
    required this.onChanged,
  });
  final bool value;
  final bool canActivate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Active', style: AdminText.h3),
                SizedBox(height: 2),
                Text('Active venues appear in the customer venue picker',
                    style: AdminText.cap),
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
