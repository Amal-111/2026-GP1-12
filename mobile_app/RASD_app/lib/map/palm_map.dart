// Farm map: shows every palm as a coloured pin by health status.
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../theme/palm_icon.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../list/palm_details.dart';
import '../services/selected_farm_service.dart';
import 'map_tiles.dart';
import '../data/auth_store.dart';
/// Farm map: real map (satellite or street) with a marker for each palm.
/// Tap a marker to see the palm and open its details.
class FarmMapPage extends StatefulWidget {
  const FarmMapPage({super.key, this.farmId, this.highlightedPalmId});
  final String? highlightedPalmId;
  final String? farmId;

  @override
  State<FarmMapPage> createState() => _FarmMapPageState();
}

class _FarmMapPageState extends State<FarmMapPage> {
  final MapController _mapController = MapController();
  MapPalm? selectedPalm;
  /// True for satellite view, false for map view.
  bool _satellite = true;

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  StreamSubscription<DatabaseEvent>? _palmsSubscription;
  StreamSubscription<DatabaseEvent>? _farmSubscription;
  StreamSubscription<DatabaseEvent>? _devicesSubscription;
  List<MapPalm> _palms = [];
  Map<String, dynamic> _devices = {};
  String _farmName = 'Farm Map';
  LatLng? _farmCenter;
  LatLng? _currentPosition;
  bool _locating = false;
  bool _loadedPalms = false;

  /// Uses the provided farm ID or the current selected farm.
  String get activeFarmId => widget.farmId ?? SelectedFarmService.farmId;

  /// Initializes screen state.
  @override
  void initState() {
    super.initState();
    _watchFarm();
  }

  /// Re-subscribes when the widget receives new parameters.
  @override
  void didUpdateWidget(covariant FarmMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmId != widget.farmId) {
      _watchFarm();
    }
  }

  /// Safely converts a database value into a map.
  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) return {};
    return Map<String, dynamic>.from(value);
  }

  /// Safely reads a latitude/longitude value.
  double? _coordinate(Object? value) {
    final result = value is num ? value.toDouble() : double.tryParse('$value');
    return result?.isFinite == true ? result : null;
  }

  /// Reads the palm status from the database value.
  String _status(Object? value) {
    switch ((value ?? '').toString().replaceAll('_', '').replaceAll(' ', '').toLowerCase()) {
      case 'healthy':
        return 'Healthy';
      case 'suspected':
        return 'Suspected';
      case 'monitoring':
      case 'undermonitoring':
        return 'Monitoring';
      default:
        return 'Unknown';
    }
  }

  /// Listens to farm and palm changes in Realtime Database.
  void _watchFarm() {
    _palmsSubscription?.cancel();
    _farmSubscription?.cancel();
    _devicesSubscription?.cancel();
    _palms = [];
    _devices = {};
    _loadedPalms = false;
    _farmName = 'Farm Map';
    _farmCenter = null;

    final farmId = activeFarmId;
    _farmSubscription = _db.ref('farms/$farmId').onValue.listen((event) {
      final data = _asMap(event.snapshot.value);
      final lat = _coordinate(data['latitude']);
      final lng = _coordinate(data['longitude']);
      if (!mounted) return;
      setState(() {
        _farmName = (data['farmName'] ?? 'Farm Map').toString();
        if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          _farmCenter = LatLng(lat, lng);
        }
      });
      if (_loadedPalms && _palms.isEmpty && _farmCenter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showWholeFarm(_palms);
        });
      }
    });

    _devicesSubscription = _db.ref('monitoringDevices').onValue.listen((event) {
      if (!mounted) return;
      setState(() => _devices = _asMap(event.snapshot.value));
      _refreshPalmStatuses();
    });

    _palmsSubscription = _db.ref('palms/$farmId').onValue.listen((event) {
      final value = _asMap(event.snapshot.value);
      final used = <String, int>{};
      final result = <MapPalm>[];
      for (final entry in value.entries) {
        final data = _asMap(entry.value);
        final lat = _coordinate(data['latitude']);
        final lng = _coordinate(data['longitude']);
        if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
        final key = '$lat,$lng';
        final repeat = used[key] ?? 0;
        used[key] = repeat + 1;
        result.add(MapPalm(
          id: entry.key,
          status: _status(data['healthStatus']),
          deviceId: (data['deviceId'] ?? '').toString(),
          point: LatLng(lat + repeat * 0.00004, lng + repeat * 0.00004),
        ));
      }
      if (!mounted) return;
      final wasLoaded = _loadedPalms;
      setState(() {
        _palms = result;
        _loadedPalms = true;
        if (selectedPalm != null) {
          for (final palm in result) {
            if (palm.id == selectedPalm!.id) {
              selectedPalm = palm;
              break;
            }
          }
          if (!result.any((p) => p.id == selectedPalm?.id)) selectedPalm = null;
        } else if (widget.highlightedPalmId != null) {
          for (final palm in result) {
            if (palm.id == widget.highlightedPalmId) {
              selectedPalm = palm;
              break;
            }
          }
        }
      });
      _refreshPalmStatuses();
      if (!wasLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (selectedPalm != null) {
            _mapController.move(selectedPalm!.point, 18);
          } else {
            _showWholeFarm(_palms);
          }
        });
      }
    });
  }

  /// Recalculates palm statuses, e.g. when a device is offline.
  void _refreshPalmStatuses() {
    if (!mounted || _palms.isEmpty) return;
    setState(() {
      _palms = _palms.map((palm) {
        final device = _asMap(_devices[palm.deviceId]);
        final offline = palm.deviceId.isNotEmpty &&
            device['connectionStatus']?.toString().toLowerCase() == 'offline';
        return palm.copyWith(displayStatus: offline ? 'Offline' : palm.status);
      }).toList();
      if (selectedPalm != null) {
        final matches = _palms.where((p) => p.id == selectedPalm!.id);
        selectedPalm = matches.isEmpty ? null : matches.first;
      }
    });
  }

  /// Releases screen resources.
  @override
  void dispose() {
    _palmsSubscription?.cancel();
    _farmSubscription?.cancel();
    _devicesSubscription?.cancel();
    super.dispose();
  }

  /// Returns the palms currently shown on the map.
  List<MapPalm> get palms => _palms;

  /// Maps a palm status to its pin colour.
  Color statusColor(String status) {
    switch (status) {
      case 'Healthy':
        return AppColors.healthy;
      case 'Suspected':
        return AppColors.suspected;
      case 'Monitoring':
        return AppColors.monitoring;
      case 'Offline':
        return AppColors.offline;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Opens the details page of the tapped palm.
  void openPalmDetails(MapPalm palm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PalmDetailsPage(farmId: activeFarmId, palmId: palm.id),
      ),
    );
  }

  /// Moves the map so all palms of the farm can be seen.
  void _showWholeFarm(List<MapPalm> list) {
    if (list.isEmpty) {
      _mapController.move(_farmCenter ?? RasdMap.farmCenter, 17);
    } else if (list.length == 1) {
      _mapController.move(list.first.point, 18);
    } else {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(list.map((p) => p.point).toList()),
        padding: const EdgeInsets.all(70),
        maxZoom: 18,
      ));
    }
  }

  /// Centers the map on the device's current location without saving it.
  Future<void> _showCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _locationMessage('فعّلي خدمة الموقع (GPS) وحاولي مرة أخرى.',
            'Turn on location services and try again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _locationMessage('لم يتم منح إذن الموقع.', 'Location permission was denied.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _locationMessage('فعّلي إذن الموقع من إعدادات التطبيق.',
            'Enable location permission in the app settings.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _currentPosition = point);
      _mapController.move(point, 17);
    } on TimeoutException {
      _locationMessage('تعذّر تحديد الموقع في الوقت المحدد. حاولي مجددًا.',
          'Location timed out. Please try again.');
    } catch (_) {
      _locationMessage('تعذّر تحديد الموقع. تحققي من GPS والأذونات.',
          'Could not get your location. Check GPS and permissions.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Shows a localized location error.
  void _locationMessage(String arabic, String english) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AuthStore.arabic.value ? arabic : english)),
    );
  }

  /// Builds the page with localized labels.
  @override
/// Builds the page with localized labels.
@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
final list = palms;
final farmName = _farmName;

return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
title: Text(
farmName == 'Farm Map'
? (isArabic ? 'خريطة المزرعة' : 'Farm Map')
: farmName,
),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: selectedPalm?.point ??
                        (list.isEmpty ? (_farmCenter ?? RasdMap.farmCenter) : list.first.point),
                    initialZoom: 17,
                    initialCameraFit: selectedPalm == null && list.length > 1
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(
                                list.map((p) => p.point).toList()),
                            padding: const EdgeInsets.all(70),
                            maxZoom: 18,
                          )
                        : null,
                    minZoom: 3,
                    maxZoom: 19,
                    // Tap on an empty place closes the palm card.
                    onTap: (_, __) => setState(() => selectedPalm = null),
                  ),
                  children: [
                    RasdMap.tiles(satellite: _satellite),
                    MarkerLayer(
                      markers: list.map((palm) {
                        final selected = selectedPalm?.id == palm.id;
                        return Marker(
                          point: palm.point,
                          width: 60,
                          height: 66,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => setState(() => selectedPalm = palm),
                            child: _PalmMarker(
                              color: statusColor(palm.displayStatus),
                              selected: selected,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition!,
                            width: 34,
                            height: 34,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    RasdMap.attribution(satellite: _satellite),
                  ],
                ),

                // Map buttons.
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      MapRoundButton(
                        icon: _satellite
                            ? Icons.map_outlined
                            : Icons.satellite_alt,
tooltip: _satellite
? (isArabic ? 'خريطة الشوارع' : 'Street map')
: (isArabic ? 'القمر الصناعي' : 'Satellite'),
                        onTap: () => setState(() => _satellite = !_satellite),
                      ),
                      const SizedBox(height: 8),
                      MapRoundButton(
                        icon: Icons.add,
tooltip: isArabic ? 'تكبير' : 'Zoom in',
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MapRoundButton(
                        icon: Icons.remove,
tooltip: isArabic ? 'تصغير' : 'Zoom out',
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MapRoundButton(
                        icon: _locating ? Icons.hourglass_top : Icons.my_location,
                        tooltip: isArabic ? 'موقعي الحالي' : 'My location',
                        onTap: _showCurrentLocation,
                      ),
                      const SizedBox(height: 8),
                      MapRoundButton(
                        icon: Icons.center_focus_strong,
tooltip: isArabic ? 'عرض المزرعة كاملة' : 'Show whole farm',
                        onTap: () => _showWholeFarm(list),
                      ),
                    ],
                  ),
                ),

                // Selected palm information.
                if (selectedPalm != null)
                  Positioned(
                    left: 14,
                    right: 70,
                    top: 12,
                    child: _PalmInfoCard(
palm: selectedPalm!,
color: statusColor(selectedPalm!.displayStatus),
isArabic: isArabic,
onClose: () => setState(() => selectedPalm = null),
onViewDetails: () => openPalmDetails(selectedPalm!),
),
                  ),

                // Status legend.
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 28,
                  child: _StatusLegend(getColor: statusColor,isArabic: isArabic,),
                ),
              ],
            ),
          ),
        ),
      ),
);
},
);
  }

/// _FarmMapPageState
}

/// A palm shown on the map.
class MapPalm {
  final String id;
  final String status;
  final LatLng point;
  final String deviceId;
  final String? displayStatusOverride;

  String get displayStatus => displayStatusOverride ?? status;

  MapPalm copyWith({String? displayStatus}) => MapPalm(
    id: id, status: status, deviceId: deviceId, point: point,
    displayStatusOverride: displayStatus,
  );

  const MapPalm({
    required this.id,
    required this.status,
    required this.point,
    required this.deviceId,
    this.displayStatusOverride,
  });
}

// Palm-shaped map marker.
class _PalmMarker extends StatelessWidget {
  final Color color;
  final bool selected;

  const _PalmMarker({
    required this.color,
    required this.selected,
  });

  /// Builds the page with localized labels.
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.location_on,
          size: selected ? 62 : 54,
          color: Colors.white,
        ),
        Icon(
          Icons.location_on,
          size: selected ? 56 : 48,
          color: color,
        ),
        Positioned(
          top: selected ? 10 : 12,
          child: const PalmIcon(color: Colors.white,
            size: 22,
          ),
        ),
      ],
    );
  }
}

// Information popup shown after tapping a marker.
class _PalmInfoCard extends StatelessWidget {
  final MapPalm palm;
  final Color color;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;
final bool isArabic;

  const _PalmInfoCard({
    required this.palm,
    required this.color,
    required this.onClose,
    required this.onViewDetails,
    required this.isArabic,
  });

  /// Builds the page with localized labels.
  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: PalmIcon(color: color, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      palm.id,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
Text(
isArabic
? _translateMapStatus(palm.displayStatus)
: palm.displayStatus,
style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
tooltip: isArabic ? 'إغلاق' : 'Close',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.arrow_forward_rounded),
label: Text(isArabic ? 'عرض تفاصيل النخلة' : 'View Palm Details'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Translates map status labels without changing stored status values.
String _translateMapStatus(String status) {
switch (status) {
case 'Healthy':
return 'سليمة';
case 'Suspected':
return 'مشتبه بالإصابة';
case 'Monitoring':
return 'تحت المراقبة';
case 'Offline':
return 'غير متصل';
default:
return status;
}
}

// Legend for the palm statuses.
class _StatusLegend extends StatelessWidget {
  final Color Function(String) getColor;
final bool isArabic;

  const _StatusLegend({
    required this.getColor,
required this.isArabic,
  });

  /// Builds the page with localized labels.
  @override
  Widget build(BuildContext context) {
    const statuses = [
      'Healthy',
      'Suspected',
      'Monitoring',
      'Offline',
    ];

    return GlassBox(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: statuses.map((status) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: getColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
Text(
isArabic ? _translateMapStatus(status) : status,
style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
