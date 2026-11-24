// Map widget for choosing a location by tapping (satellite / map view).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/palm_icon.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../map/map_tiles.dart';
import '../data/auth_store.dart';
/// Real map (from the internet) where the user taps to place the palm
/// or the sensor.
/// - Pinch / scroll to zoom, drag to move.
/// - Switch between satellite and street map.
/// - The marker represents the selected location.
class FarmLocationPicker extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final ValueChanged<({double latitude, double longitude})> onPicked;
  final IconData pinIcon;
  final bool showCurrentLocation;

  const FarmLocationPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onPicked,
    this.pinIcon = Icons.park_rounded,
    this.showCurrentLocation = false,
  });

  /// Where the map opens when no location is chosen yet (sample farm).
  /// TODO: use the farm's real location from the database.
  static const LatLng farmCenter = RasdMap.farmCenter;

  @override
  State<FarmLocationPicker> createState() => _FarmLocationPickerState();
}

class _FarmLocationPickerState extends State<FarmLocationPicker> {
  final MapController _mapController = MapController();
  /// True once the map has loaded.
  bool _mapReady = false;
  /// True for satellite view, false for map view.
  bool _satellite = true;
  bool _locating = false;
  int _manualSelections = 0;

  /// Returns a valid selected map position.
  LatLng? get _pin {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
      return null;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  /// Re-subscribes when the widget receives new parameters.
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

  /// Moves the pin to the tapped map position.
  void _onTap(LatLng point) {
    _manualSelections++;
    _pick(point);
  }

  void _pick(LatLng point) {
    widget.onPicked((
      latitude: double.parse(point.latitude.toStringAsFixed(6)),
      longitude: double.parse(point.longitude.toStringAsFixed(6)),
    ));
  }

  Future<void> _pickCurrentLocation() async {
    if (_locating) return;
    final manualSelections = _manualSelections;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationMessage('فعّل خدمة الموقع وحاول مرة أخرى.',
            'Turn on location services and try again.');
        return;
      }
      if (!mounted) return;

      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission == LocationPermission.deniedForever) {
        _locationMessage('اسمح بالوصول إلى الموقع من إعدادات التطبيق.',
            'Enable location permission in the app settings.');
        return;
      }
      if (permission == LocationPermission.denied) {
        _locationMessage('لم يتم منح إذن الموقع.',
            'Location permission was denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted || manualSelections != _manualSelections) return;
      final lat = position.latitude;
      final lng = position.longitude;
      if (!lat.isFinite || !lng.isFinite || lat.abs() > 90 || lng.abs() > 180) {
        _locationUnavailable();
        return;
      }
      final point = LatLng(lat, lng);
      _pick(point);
      if (_mapReady) _mapController.move(point, _mapController.camera.zoom);
    } on TimeoutException {
      _locationMessage('انتهت مهلة تحديد الموقع. حاول مرة أخرى.',
          'Location timed out. Please try again.');
    } on LocationServiceDisabledException {
      _locationMessage('فعّل خدمة الموقع وحاول مرة أخرى.',
          'Turn on location services and try again.');
    } on PermissionDeniedException {
      _locationMessage('لم يتم منح إذن الموقع.',
          'Location permission was denied.');
    } catch (_) {
      _locationUnavailable();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _locationUnavailable() {
    _locationMessage('تعذّر تحديد موقعك الحالي.',
        'Your current location is unavailable. Please try again.');
  }

  void _locationMessage(String arabic, String english) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AuthStore.arabic.value ? arabic : english)),
    );
  }

@override
Widget build(BuildContext context) {
final pin = _pin;

return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
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
? (isArabic
? 'اضغط على الخريطة لتحديد الموقع'
: 'Tap on the map to set the location')
: (isArabic
? 'اضغط مرة أخرى لتحريك العلامة'
: 'Tap again to move the pin'),
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
tooltip: _satellite
? (isArabic ? 'خريطة الشوارع' : 'Street map')
: (isArabic ? 'الأقمار الصناعية' : 'Satellite'),
                    onTap: () => setState(() => _satellite = !_satellite),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.add,
tooltip: isArabic ? 'تكبير' : 'Zoom in',
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.remove,
tooltip: isArabic ? 'تصغير' : 'Zoom out',
                    onTap: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    ),
                  ),
                  if (widget.showCurrentLocation) ...[
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: _locating ? Icons.hourglass_top : Icons.my_location,
                      tooltip: isArabic ? 'موقعي الحالي' : 'My Current Location',
                      onTap: _pickCurrentLocation,
                    ),
                  ],
                  if (pin != null) ...[
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.center_focus_strong,
tooltip: isArabic ? 'الانتقال إلى العلامة' : 'Go to pin',
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
},
);
}
}

/// Round button on the map.
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

/// Map pin drawing.
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
