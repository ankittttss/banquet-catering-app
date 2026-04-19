import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/photon_geocoder.dart';

/// Bottom sheet: search for a place via Photon/OSM and return the chosen
/// [GeocodeResult]. The caller is responsible for saving to the repo.
class AddressSearchSheet extends StatefulWidget {
  const AddressSearchSheet._();

  static Future<GeocodeResult?> show(BuildContext context) {
    return showModalBottomSheet<GeocodeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddressSearchSheet._(),
    );
  }

  @override
  State<AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<AddressSearchSheet> {
  final _geo = PhotonGeocoder();
  final _ctl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<GeocodeResult> _results = const [];

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
        _error = 'Could not search. Check your connection.';
        _loading = false;
      });
    }
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
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusPill),
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
                    Text('Search an address',
                        style: AppTextStyles.heading1),
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
                    hintStyle: AppTextStyles.body
                        .copyWith(color: AppColors.textMuted),
                    prefixIcon: const Icon(
                      PhosphorIconsBold.magnifyingGlass,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Expanded(
                child: _buildBody(scrollCtl),
              ),
            ],
          ),
        ),
      ),
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
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsDuotone.mapPin,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            Text(
              _ctl.text.trim().length < 2
                  ? 'Start typing a locality, street, or landmark.'
                  : 'No places found. Try a different search.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      controller: scrollCtl,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pagePaddingSm),
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
}
