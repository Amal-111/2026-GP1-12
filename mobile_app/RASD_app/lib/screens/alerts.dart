import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import 'alert_details.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool showCurrent = true;

  @override
  void initState() {
    super.initState();
    MockData.changes.addListener(_refresh);
  }

  void _refresh() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    MockData.changes.removeListener(_refresh);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final farmId = MockData.currentUser.role == UserRole.farmer
        ? MockData.currentUser.farmId
        : MockData.selectedFarmId;
    final alerts = MockData.alerts.where((a) =>
        a.farmId == farmId && a.isCurrent == showCurrent).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Alerts', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),

          // Current and history tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: _tabButton('Current', true)),
                  Expanded(child: _tabButton('History', false)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),


          // Alerts list
          Expanded(
            child: alerts.isEmpty
                ? Center(child: Text(showCurrent ? 'No current alerts.' : 'No alert history.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      final color = alertTypeColor(alert.type);
                      final palm = MockData.palmById(alert.palmId);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(alertTypeIcon(alert.type), color: color, size: 32),
                          ),
                          title: Text(
                            alert.palmId,
                            style: TextStyle(fontWeight: alert.isRead ? FontWeight.w500 : FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(alert.title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                              Text(timeAgo(alert.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AlertDetailsScreen(alert: alert)),
                            );
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String title, bool isCurrentTab) {
    bool selected = showCurrent == isCurrentTab;

    return InkWell(
      onTap: () {
        setState(() {
          showCurrent = isCurrentTab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

Color alertTypeColor(AlertType type) {
  if (type == AlertType.suspected) return AppColors.suspected;
  if (type == AlertType.monitoring) return AppColors.monitoring;
  return AppColors.offline;
}

IconData alertTypeIcon(AlertType type) {
  if (type == AlertType.suspected) return Icons.warning_rounded;
  if (type == AlertType.monitoring) return Icons.access_time_filled;
  return Icons.wifi_off;
}
