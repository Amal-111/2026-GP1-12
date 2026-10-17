import 'package:flutter/material.dart';
import '../theme/palm_icon.dart';
import '../theme/glass_widgets.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import 'alerts.dart';
import '../list/palm_details.dart';
import '../map/palm_map.dart';

class AlertDetailsScreen extends StatefulWidget {
  final AlertData alert;

  const AlertDetailsScreen({super.key, required this.alert});

  @override
  State<AlertDetailsScreen> createState() => _AlertDetailsScreenState();
}

class _AlertDetailsScreenState extends State<AlertDetailsScreen> {
  @override
  void initState() {
    super.initState();
    MockData.markRead(widget.alert);
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final palm = MockData.palmById(alert.palmId);
    final color = alertTypeColor(alert.type);

    String recommendation = 'Please inspect this palm tree and look for signs of infestation.';
    if (alert.type == AlertType.monitoring) {
      recommendation = 'Continue monitoring this palm and follow the treatment schedule.';
    } else if (alert.type == AlertType.deviceOffline) {
      recommendation = 'Check the device power and connection, then verify data transmission.';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alert summary
            GlassBox(
              child: Row(
                children: [
                  Icon(alertTypeIcon(alert.type), color: color, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                        Text(alert.palmId),
                        Text(
                          '${alert.createdAt.day}/${alert.createdAt.month}/${alert.createdAt.year}'
                              '  •  '
                              '${alert.createdAt.hour.toString().padLeft(2, '0')}:'
                              '${alert.createdAt.minute.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Palm image and location
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/palm_background.jpg',
                        width: 100,
                        height: 135,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100,
                            height: 135,
                            color: const Color(0xFFE1EFE4),
                            child: const PalmIcon(color: AppColors.primary, size: 50),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Find this palm on the farm map',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('View on Map'),
                            onPressed: palm == null ? null : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FarmMapPage(
                                    farmId: palm.farmId,
                                    highlightedPalmId: palm.id,
                                  ),
                                ),
                              );
                            },
                          ),
                          TextButton.icon(
                            icon: const PalmIcon(),
                            label: const Text('Palm Details'),
                            onPressed: palm == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => PalmDetailsPage(palmId: palm.id)),
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Recommended action box
            GlassBox(
              tint: const Color(0xFFFFF6E4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, color: AppColors.monitoring, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recommended Action', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(recommendation),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alert Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 5),
                  Text(alert.message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
