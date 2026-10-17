import 'package:flutter/material.dart';
import '../theme/palm_icon.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../list/palm_details.dart';
import '../data/mock_data.dart';
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

  @override
  void initState() {
    super.initState();
    MockData.changes.addListener(_refresh);
    if (widget.highlightedPalmId != null) {
      for (final palm in palms) {
        if (palm.id == widget.highlightedPalmId) {
          selectedPalm = palm;
          break;
        }
      }
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        if (selectedPalm != null) {
          final matches = palms.where((p) => p.id == selectedPalm!.id);
          selectedPalm = matches.isEmpty ? null : matches.first;
        }
      });
    }
  }

  @override
  void dispose() {
    MockData.changes.removeListener(_refresh);
    super.dispose();
  }

  String get activeFarmId => MockData.currentUser.role == UserRole.farmer
      ? (MockData.currentUser.farmId ?? '')
      : (widget.farmId ?? MockData.selectedFarmId);

  /// Palms of the farm with their real location from MockData.
  List<MapPalm> get palms {
    final data = MockData.palmsForFarm(activeFarmId);
    final used = <String, int>{};
    final result = <MapPalm>[];

    for (final palm in data) {
      final point = RasdMap.parse(palm.location);
      if (point == null) continue;

      // Two palms with the exact same location: move the second one a
      // little so both markers can be tapped.
      final key = palm.location.trim();
      final repeat = used[key] ?? 0;
      used[key] = repeat + 1;

      result.add(MapPalm(
        id: palm.id,
        status: !palm.deviceOnline
            ? 'Offline'
            : palm.status == PalmStatus.underMonitoring
                ? 'Monitoring'
                : palmStatusLabel(palm.status),
        point: LatLng(
          point.latitude + repeat * 0.00004,
          point.longitude + repeat * 0.00004,
        ),
      ));
    }
    return result;
  }

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
        builder: (_) => PalmDetailsPage(palmId: palm.id),
      ),
    );
  }

  /// Moves the map so all palms of the farm can be seen.
  void _showWholeFarm(List<MapPalm> list) {
    if (list.isEmpty) {
      _mapController.move(RasdMap.farmCenter, 17);
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
    final farmName = MockData.farms.any((f) => f.id == activeFarmId)
        ? MockData.farms.firstWhere((f) => f.id == activeFarmId).name
        : 'Farm Map';

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
                        (list.isEmpty ? RasdMap.farmCenter : list.first.point),
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
                              color: statusColor(palm.status),
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
                      color: statusColor(selectedPalm!.status),
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

  const MapPalm({
    required this.id,
    required this.status,
    required this.point,
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
                      palm.status,
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
