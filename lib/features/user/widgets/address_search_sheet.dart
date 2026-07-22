import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/photon_geocoder.dart';
import '../../../data/models/user_address.dart';
import '../../../shared/providers/address_providers.dart';
import '../../../shared/providers/location_providers.dart';

/// Bottom sheet: search for a place via Photon/OSM and return the chosen
/// [GeocodeResult]. The caller is responsible for saving to the repo.
class AddressSearchSheet extends ConsumerStatefulWidget {
  const AddressSearchSheet._({required this.allowCurrentLocation});

  /// Whether the device-GPS shortcut is offered. Defaults to FALSE: GPS is
  /// scoped to the approved event-planning flows (setting or changing the
  /// event location), so opening this sheet anywhere else — e.g. the saved
  /// address book — never prompts for location permission.
  final bool allowCurrentLocation;

  static Future<GeocodeResult?> show(
    BuildContext context, {
    bool allowCurrentLocation = false,
  }) {
    return showModalBottomSheet<GeocodeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AddressSearchSheet._(allowCurrentLocation: allowCurrentLocation),
    );
  }

  @override
  ConsumerState<AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends ConsumerState<AddressSearchSheet> {
  final _geo = PhotonGeocoder();
  final _ctl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<GeocodeResult> _results = const [];

  /// True while a GPS lookup is in flight (the tile shows a spinner).
  bool _gpsBusy = false;

  /// A GPS-specific message shown under the tile when a lookup fails — never
  /// blocks the sheet; manual search below stays fully usable.
  String? _gpsError;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    _geo.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _run(q));
  }

  Future<void> _run(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Bias toward India.
      final res = await _geo.search(q, lat: 20.5937, lng: 78.9629);
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep the user-facing copy short but include the cause so the
        // device build is debuggable from the UI when the network path
        // is misbehaving.
        _error = 'Could not search ($e). Check your connection.';
        _loading = false;
      });
    }
  }

  /// Resolve the device location and return it as a [GeocodeResult]. GPS is
  /// touched ONLY here — on an explicit tap while planning — so permission is
  /// requested at the moment of intent, never at launch. Any failure (service
  /// off, permission denied, lookup error) is shown inline and leaves the
  /// manual address search fully available.
  Future<void> _useCurrentLocation() async {
    if (_gpsBusy) return;
    setState(() {
      _gpsBusy = true;
      _gpsError = null;
    });
    try {
      final addr = await ref.read(currentLocationProvider)();
      if (!mounted) return;
      Navigator.of(context).pop(_resultFromResolved(addr));
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsBusy = false;
        _gpsError = _gpsMessage(e.kind);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsBusy = false;
        _gpsError = 'Couldn\'t get your location. Search your address below.';
      });
    }
  }

  static String _gpsMessage(LocationError kind) => switch (kind) {
        LocationError.serviceDisabled =>
          'Location is off. Turn it on, or search your address below.',
        LocationError.permissionDenied ||
        LocationError.permissionDeniedForever =>
          'Location permission denied. Search your address below instead.',
        LocationError.unknown =>
          'Couldn\'t get your location. Search your address below.',
      };

  GeocodeResult _resultFromResolved(ResolvedAddress a) {
    final parts = [a.line1, a.line2, a.city]
        .where((s) => s != null && s.trim().isNotEmpty)
        .cast<String>()
        .toList();
    final label =
        parts.isEmpty ? 'Pinned to your current location' : parts.join(', ');
    return GeocodeResult(
      name: 'Current location',
      displayAddress: label,
      latitude: a.lat,
      longitude: a.lng,
      shortLabel: 'Current location',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtl) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusXl),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSizes.md),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppSizes.radiusPill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.md,
                  AppSizes.pagePadding,
                  AppSizes.sm,
                ),
                child: Row(
                  children: [
                    Text('Search an address', style: AppTextStyles.heading1),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(PhosphorIconsBold.x),
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.pagePadding),
                child: TextField(
                  controller: _ctl,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: 'Search "Banjara Hills" or "Paradise Biryani"',
                    hintStyle:
                        AppTextStyles.body.copyWith(color: AppColors.textMuted),
                    prefixIcon: const Icon(
                      PhosphorIconsBold.magnifyingGlass,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              _buildGpsTile(),
              Expanded(
                child: _buildBody(scrollCtl),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Use my current location" affordance — the only GPS entry point, and only
  /// in the approved planning flows. Shows a spinner while resolving and an
  /// inline, non-blocking message on failure.
  Widget _buildGpsTile() {
    if (!widget.allowCurrentLocation) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSizes.pagePaddingSm),
          child: InkWell(
            onTap: _gpsBusy ? null : _useCurrentLocation,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.sm,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: _gpsBusy
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Text(
                      _gpsBusy
                          ? 'Getting your location…'
                          : 'Use my current location',
                      style: AppTextStyles.bodyBold
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_gpsError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              2,
              AppSizes.pagePadding,
              AppSizes.xs,
            ),
            child: Text(
              _gpsError!,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }

  Widget _buildBody(ScrollController scrollCtl) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Center(
          child: Text(
            _error!,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final isPreSearch = _ctl.text.trim().length < 2;
    if (_results.isEmpty) {
      if (isPreSearch) {
        // Before the user starts typing, surface saved addresses so the
        // sheet is useful immediately — taps return a synthetic
        // GeocodeResult so the existing caller flow works unchanged.
        return _SavedAddressesEmptyState(
          scrollCtl: scrollCtl,
          onPick: (a) => Navigator.of(context).pop(_resultFromSaved(a)),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsDuotone.mapPin,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            Text(
              'No places found. Try a different search.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      controller: scrollCtl,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePaddingSm),
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) {
        final r = _results[i];
        return ListTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: const Icon(PhosphorIconsFill.mapPin,
                color: AppColors.primary, size: 18),
          ),
          title: Text(
            r.name.isEmpty ? r.shortLabel : r.name,
            style: AppTextStyles.bodyBold,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            r.displayAddress,
            style: AppTextStyles.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context).pop(r),
        );
      },
    );
  }

  /// Wrap a saved [UserAddress] in a [GeocodeResult] so callers that only
  /// know about Photon results don't need a separate type for "user
  /// picked a saved one".
  GeocodeResult _resultFromSaved(UserAddress a) => GeocodeResult(
        name: a.label.label,
        displayAddress: a.fullAddress,
        latitude: a.latitude ?? 0,
        longitude: a.longitude ?? 0,
        shortLabel: a.shortLabel ?? a.fullAddress,
      );
}

/// "Search History" / saved-address list shown when no query is typed.
/// Lives on its own widget so the parent doesn't have to subscribe to
/// the addresses provider when it isn't visible.
class _SavedAddressesEmptyState extends ConsumerWidget {
  const _SavedAddressesEmptyState({
    required this.scrollCtl,
    required this.onPick,
  });

  final ScrollController scrollCtl;
  final ValueChanged<UserAddress> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(addressesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsDuotone.mapPin,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            Text(
              'Start typing a locality, street, or landmark.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      data: (saved) {
        if (saved.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(PhosphorIconsDuotone.mapPin,
                    size: 56, color: AppColors.textMuted),
                const SizedBox(height: AppSizes.md),
                Text(
                  'Start typing a locality, street, or landmark.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          controller: scrollCtl,
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePaddingSm,
            AppSizes.sm,
            AppSizes.pagePaddingSm,
            AppSizes.md,
          ),
          itemCount: saved.length + 1,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.sm,
                  AppSizes.sm,
                  AppSizes.sm,
                  AppSizes.sm,
                ),
                child: Text(
                  'YOUR SAVED ADDRESSES',
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              );
            }
            final a = saved[i - 1];
            return ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: const Icon(
                  PhosphorIconsFill.bookmarkSimple,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              title: Text(
                a.label.label,
                style: AppTextStyles.bodyBold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                a.fullAddress,
                style: AppTextStyles.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onPick(a),
            );
          },
        );
      },
    );
  }
}
