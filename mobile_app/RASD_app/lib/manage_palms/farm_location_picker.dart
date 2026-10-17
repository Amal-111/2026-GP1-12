import 'package:flutter/material.dart';
import '../theme/palm_icon.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import 'palm_store.dart';
import '../map/map_tiles.dart';

/// Real map (from the internet) where the user taps to place the palm
/// or the sensor.
/// - Pinch / scroll to zoom, drag to move.
/// - Switch between satellite and street map.
/// - Palms already added are shown as small markers.
class FarmLocationPicker extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final ValueChanged<({double latitude, double longitude})> onPicked;
  final IconData pinIcon;

  const FarmLocationPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onPicked,
    this.pinIcon = Icons.park_rounded,
  });

  /// Where the map opens when no location is chosen yet (sample farm).
  /// TODO: use the farm's real location from the database.
  static const LatLng farmCenter = RasdMap.farmCenter;

  @override
  State<FarmLocationPicker> createState() => _FarmLocationPickerState();
}

class _FarmLocationPickerState extends State<FarmLocationPicker> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _satellite = true;

  LatLng? get _pin {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  @override
  void didUpdateWidget(covariant FarmLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the location was typed or set by "Use Current Location",
    // move the map so the pin can be seen.
    final pin = _pin;
    if (pin == null || !_mapReady) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final camera = _mapController.camera;
      if (!camera.visibleBounds.contains(pin)) {
        _mapController.move(pin, camera.zoom);
      }
    });
  }

  void _onTap(LatLng point) {
    widget.onPicked((
      latitude: double.parse(point.latitude.toStringAsFixed(6)),
      longitude: double.parse(point.longitude.toStringAsFixed(6)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pin ?? FarmLocationPicker.farmCenter,
                initialZoom: 17,
                minZoom: 3,
                maxZoom: 19,
                onTap: (_, point) => _onTap(point),
                onMapReady: () => _mapReady = true,
              ),
              children: [
                RasdMap.tiles(satellite: _satellite),
                MarkerLayer(
                  markers: [
                    // Palms already in the farm.
                    ...PalmStore.instance.palms.map(
                      (p) => Marker(
                        point: LatLng(p.latitude, p.longitude),
                        width: 18,
                        height: 18,
                        child: Tooltip(
                          message: 'Palm #${p.id}',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.secondary,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The new location.
                    if (pin != null)
                      Marker(
                        point: pin,
                        width: 48,
                        height: 56,
                        alignment: Alignment.topCenter,
                        child: _Pin(icon: widget.pinIcon),
                      ),
                  ],
                ),
                RasdMap.attribution(satellite: _satellite),
              ],
            ),

            // Hint at the top.
            Positioned(
              top: 10,
              left: 60,
              right: 60,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pin == null
                          ? 'Tap on the map to set the location'
                          : 'Tap again to move the pin',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Map buttons on the right.
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                children: [
                  _MapButton(
                    icon: _satellite ? Icons.map_outlined : Icons.satellite_alt,
                    tooltip: _satellite ? 'Street map' : 'Satellite',
                    onTap: () => setState(() => _satellite = !_satellite),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.add,
                    tooltip: 'Zoom in',
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom out',
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    ),
                  ),
                  if (pin != null) ...[
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.center_focus_strong,
                      tooltip: 'Go to pin',
                      onTap: () => _mapController.move(
                        pin,
                        _mapController.camera.zoom,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MapRoundButton(icon: icon, tooltip: tooltip, onTap: onTap);
  }
}

class _Pin extends StatelessWidget {
  final IconData icon;
  const _Pin({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.location_on, size: 56, color: Colors.white),
        const Icon(Icons.location_on, size: 50, color: AppColors.primary),
        Positioned(
          top: 9,
          child: appIcon(icon, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}
