import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../theme/palm_icon.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../list/palm_details.dart';
import '../services/selected_farm_service.dart';
import 'map_tiles.dart';

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
  bool _satellite = true;

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  StreamSubscription<DatabaseEvent>? _palmsSubscription;
  StreamSubscription<DatabaseEvent>? _farmSubscription;
  StreamSubscription<DatabaseEvent>? _devicesSubscription;
  List<MapPalm> _palms = [];
  Map<String, dynamic> _devices = {};
  String _farmName = 'Farm Map';
  LatLng? _farmCenter;
  bool _loadedPalms = false;

  String get activeFarmId => widget.farmId ?? SelectedFarmService.farmId;

  @override
  void initState() {
    super.initState();
    _watchFarm();
  }

  @override
  void didUpdateWidget(covariant FarmMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmId != widget.farmId) {
      _watchFarm();
    }
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) return {};
    return Map<String, dynamic>.from(value);
  }

  double? _coordinate(Object? value) {
    final result = value is num ? value.toDouble() : double.tryParse('$value');
    return result?.isFinite == true ? result : null;
  }

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

  @override
  void dispose() {
    _palmsSubscription?.cancel();
    _farmSubscription?.cancel();
    _devicesSubscription?.cancel();
    super.dispose();
  }

  List<MapPalm> get palms => _palms;

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

  @override
  Widget build(BuildContext context) {
    final list = palms;
    final farmName = _farmName;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(farmName),
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
                        tooltip: _satellite ? 'Street map' : 'Satellite',
                        onTap: () => setState(() => _satellite = !_satellite),
                      ),
                      const SizedBox(height: 8),
                      MapRoundButton(
                        icon: Icons.add,
                        tooltip: 'Zoom in',
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MapRoundButton(
                        icon: Icons.remove,
                        tooltip: 'Zoom out',
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MapRoundButton(
                        icon: Icons.center_focus_strong,
                        tooltip: 'Show whole farm',
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
                      onClose: () => setState(() => selectedPalm = null),
                      onViewDetails: () => openPalmDetails(selectedPalm!),
                    ),
                  ),

                // Status legend.
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 28,
                  child: _StatusLegend(getColor: statusColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

  const _PalmInfoCard({
    required this.palm,
    required this.color,
    required this.onClose,
    required this.onViewDetails,
  });

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
                      palm.displayStatus,
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
                tooltip: 'Close',
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
                label: const Text('View Palm Details'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Legend for the palm statuses.
class _StatusLegend extends StatelessWidget {
  final Color Function(String) getColor;

  const _StatusLegend({
    required this.getColor,
  });

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
                    status,
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
