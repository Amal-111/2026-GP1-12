// List of alerts for the selected farm.

import 'package:flutter/material.dart';
import '../theme/glass_widgets.dart';
import '../services/rasd_alert_service.dart';
import '../theme/app_colors.dart';
import 'alert_details.dart';
import '../data/auth_store.dart';
/// Alerts page.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.farmId});

  final String farmId;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  /// Turns a date into text like "5 min ago".
  String _timeAgo(DateTime? date, bool isArabic) {
    if (date == null) {
      return isArabic ? 'التاريخ غير متاح' : 'Date unavailable';
    }

    final d = DateTime.now().difference(date.toLocal());

    if (d.isNegative || d.inMinutes < 1) {
      return isArabic ? 'الآن' : 'Just now';
    }

    if (d.inMinutes < 60) {
      return isArabic
          ? 'قبل ${d.inMinutes} دقيقة'
          : '${d.inMinutes} min ago';
    }

    if (d.inHours < 24) {
      return isArabic
          ? 'قبل ${d.inHours} ساعة'
          : '${d.inHours} hours ago';
    }

    return isArabic
        ? 'قبل ${d.inDays} يوم'
        : '${d.inDays} days ago';
  }

/// Builds the page with localized labels.
@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return SafeArea(
      child: Column(
        children: [
Padding(
padding: const EdgeInsets.all(16),
child: Align(
alignment: Alignment.centerLeft,
child: GlassLabel(
child: Text(
isArabic ? 'التنبيهات' : 'Alerts',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

          // Alerts list
          Expanded(
            child: StreamBuilder<List<RasdAlert>>(
              stream: RasdAlertService.watchAlerts(widget.farmId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
return Center(
child: GlassLabel(
child: Text(
isArabic
? 'تعذر تحميل التنبيهات.'
: 'Unable to load alerts.',
),
),
);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final alerts = snapshot.data!;
return alerts.isEmpty
? Center(
child: GlassLabel(
child: Text(
isArabic
? 'لا توجد تنبيهات حاليًا.'
: 'No current alerts.',
),
),
)
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final color = alertTypeColor(alert.type);

                    return GlassCard(
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
                          child: Icon(
                            alertTypeIcon(alert.type),
                            color: color,
                            size: 32,
                          ),
                        ),
                        title: Text(
                          alert.palmId,
                          style: TextStyle(
                            fontWeight: alert.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? localizedAlertTitle(alert.type, alert.title) : alert.title,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
_timeAgo(alert.createdAt, isArabic),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AlertDetailsScreen(alert: alert),
                            ),
                          );

                          if (mounted) setState(() {});
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
);
},
);
}
}

/// Returns the color assigned to an alert type.
Color alertTypeColor(String type) {
  if (type == 'PossiblePestDetected') {
    return AppColors.suspected;
  }
  if (type == 'UnderMonitoring') {
    return AppColors.monitoring;
  }
  return AppColors.offline;
}

/// Returns the icon assigned to an alert type.
IconData alertTypeIcon(String type) {
  if (type == 'PossiblePestDetected') {
    return Icons.warning_rounded;
  }
  if (type == 'UnderMonitoring') {
    return Icons.access_time_filled;
  }
  return Icons.wifi_off;
}

/// Translates known alert types without changing Firebase values.
String localizedAlertTitle(String type, String fallback) {
  switch (type) {
    case 'PossiblePestDetected':
      return 'اشتباه بإصابة';
    case 'UnderMonitoring':
      return 'تحت المراقبة';
    case 'SensorOffline':
      return 'المستشعر غير متصل';
    default:
      return fallback;
  }
}
