import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';

/// Real OSM-backed delivery map (via `flutter_map`). Shows pickup + drop
/// markers with a straight dashed connector. Pan/zoom enabled.
///
/// When [pickup]/[drop] aren't provided, falls back to a Hyderabad-centred
/// demo view so dev screens still render.
///
/// Named `MapPlaceholder` for backwards call-site compatibility; this is no
/// longer a placeholder.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({
    super.key,
    required this.pickupLabel,
    required this.dropLabel,
    this.pickup,
    this.drop,
    this.height = 280,
    this.showNavigateButton = true,
    this.onNavigate,
  });

  final String pickupLabel;
  final String dropLabel;
  final LatLng? pickup;
  final LatLng? drop;
  final double height;
  final bool showNavigateButton;
  final VoidCallback? onNavigate;

  // Hyderabad demo coords — used only when the caller hasn't passed real ones.
  static const _demoPickup = LatLng(17.4139, 78.4520); // Banjara Hills
  static const _demoDrop = LatLng(17.4239, 78.4483);

  @override
  Widget build(BuildContext context) {
    final p = pickup ?? _demoPickup;
    final d = drop ?? _demoDrop;
    // Centre the map halfway between the two points so both are visible.
    final centre = LatLng(
      (p.latitude + d.latitude) / 2,
      (p.longitude + d.longitude) / 2,
    );

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: centre,
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dawat.banquet_catering_app',
                maxZoom: 19,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [p, d],
                    color: AppColors.primary.withValues(alpha: 0.7),
                    strokeWidth: 3,
                    pattern: StrokePattern.dashed(segments: const [8, 6]),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: p,
                    width: 70,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: _Pin(
                      color: AppColors.accent,
                      icon: PhosphorIconsFill.storefront,
                      label: 'Pickup',
                    ),
                  ),
                  Marker(
                    point: d,
                    width: 70,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: _Pin(
                      color: AppColors.primary,
                      icon: PhosphorIconsFill.mapPin,
                      label: 'Drop',
                    ),
                  ),
                ],
              ),
              const _AttributionLayer(),
            ],
          ),
          if (showNavigateButton)
            Positioned(
              bottom: 16,
              right: 16,
              child: Material(
                color: AppColors.info,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                elevation: 3,
                child: InkWell(
                  onTap: onNavigate,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                      vertical: AppSizes.sm + 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsBold.navigationArrow,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Navigate',
                          style: AppTextStyles.buttonLabel.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon, required this.label});
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm + 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSizes.radiusXs),
          ),
          child: Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: Colors.white,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact "© OpenStreetMap" credit pinned to the bottom-left — required by
/// OSM's tile usage policy.
class _AttributionLayer extends StatelessWidget {
  const _AttributionLayer();

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      popupInitialDisplayDuration: const Duration(seconds: 3),
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () {},
        ),
      ],
    );
  }
}
