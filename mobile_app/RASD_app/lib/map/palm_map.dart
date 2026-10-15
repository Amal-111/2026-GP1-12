
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../list/palm_details.dart';

class FarmMapPage extends StatefulWidget {
  const FarmMapPage({super.key});

  @override
  State<FarmMapPage> createState() => _FarmMapPageState();
}

class _FarmMapPageState extends State<FarmMapPage> {
  DemoPalm? selectedPalm;

  final List<DemoPalm> palms = const [
    DemoPalm(id: 'P001', status: 'Healthy',    x: 0.08, y: 0.09),
    DemoPalm(id: 'P002', status: 'Healthy',    x: 0.56, y: 0.16),
    DemoPalm(id: 'P003', status: 'Monitoring', x: 0.82, y: 0.25),
    DemoPalm(id: 'P004', status: 'Suspected',  x: 0.15, y: 0.33),
    DemoPalm(id: 'P005', status: 'Healthy',    x: 0.57, y: 0.38),
    DemoPalm(id: 'P006', status: 'Monitoring', x: 0.82, y: 0.40),
    DemoPalm(id: 'P007', status: 'Treated',    x: 0.42, y: 0.50),
    DemoPalm(id: 'P008', status: 'Offline',    x: 0.08, y: 0.80),
    DemoPalm(id: 'P009', status: 'Healthy',    x: 0.75, y: 0.85),
  ];


  Color statusColor(String status) {
    switch (status) {
      case 'Healthy':
        return AppColors.healthy;
      case 'Suspected':
        return AppColors.suspected;
      case 'Monitoring':
        return AppColors.monitoring;
      case 'Treated':
        return AppColors.treated;
      case 'Offline':
        return AppColors.offline;
      default:
        return AppColors.textSecondary;
    }
  }

  void openPalmDetails(DemoPalm palm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PalmDetailsPage(
          palmId: palm.id,
          status: palm.status,
          updated: '10 min ago',
          temperature: 28.5,
          humidity: 55.0,
          deviceId: 'DEV-${palm.id}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Al Noor Farm'),
        actions: [
          IconButton(
            tooltip: 'Map layers',
            icon: const Icon(Icons.layers_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Map layers are for future implementation.',
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mapWidth = constraints.maxWidth;
                final mapHeight = constraints.maxHeight;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Static demo image of the palm farm.
                    Image.asset(
                      'assets/images/farm_map.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.beige,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(20),
                          child: const Text(
                            'Farm image not found.\n'
                                'Check assets/images/farm_map.jpg',
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),

                    // Interactive palm markers.
                    ...palms.map((palm) {
                      return Positioned(
                        left: mapWidth * palm.x - 25,
                        top: mapHeight * palm.y - 29,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedPalm = palm;
                            });
                          },
                          child: _PalmMarker(
                            color: statusColor(palm.status),
                            selected: selectedPalm?.id == palm.id,
                          ),
                        ),
                      );
                    }),

                    // Selected palm information.
                    if (selectedPalm != null)
                      Positioned(
                        left: 14,
                        right: 14,
                        top: mapHeight * 0.30,
                        child: _PalmInfoCard(
                          palm: selectedPalm!,
                          color: statusColor(selectedPalm!.status),
                          onClose: () {
                            setState(() {
                              selectedPalm = null;
                            });
                          },
                          onViewDetails: () {
                            openPalmDetails(selectedPalm!);
                          },
                        ),
                      ),

                    // Demo current-location button.
                    Positioned(
                      right: 16,
                      bottom: 94,
                      child: Material(
                        color: Colors.white,
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'My location',
                          iconSize: 30,
                          padding: const EdgeInsets.all(16),
                          icon: const Icon(
                            Icons.my_location_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Current location is not connected '
                                      'in the demo map.',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Status legend.
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 10,
                      child: _StatusLegend(
                        getColor: statusColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Demo palm information and marker positions.
class DemoPalm {
  final String id;
  final String status;
  final double x;
  final double y;

  const DemoPalm({
    required this.id,
    required this.status,
    required this.x,
    required this.y,
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
    return SizedBox(
      width: 52,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: selected ? 59 : 53,
            color: Colors.white,
          ),
          Icon(
            Icons.location_on,
            size: selected ? 53 : 47,
            color: color,
          ),
          const Positioned(
            top: 7,
            child: Icon(
              Icons.park_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
        ],
      ),
    );
  }
}

// Information popup shown after tapping a marker.
class _PalmInfoCard extends StatelessWidget {
  final DemoPalm palm;
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
    return Card(
      color: Colors.white,
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.park_rounded,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Palm #${palm.id}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    palm.status,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Text(
                  'Palm ID',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  palm.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Status',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  palm.status,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('View Palm Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Legend for the five palm statuses.
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
      'Treated',
      'Offline',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
