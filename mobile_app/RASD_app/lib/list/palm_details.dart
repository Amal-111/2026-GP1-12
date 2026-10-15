import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'monitoring_history.dart';
import 'treatment_record.dart';

class PalmDetailsPage extends StatelessWidget {
final String palmId;
final String status;
final String updated;
final double temperature;
final double humidity;
final String deviceId;

final VoidCallback? onViewHistory;
final VoidCallback? onManageTreatment;

const PalmDetailsPage({
super.key,
this.palmId = '0024',
this.status = 'Suspected',
this.updated = '10 min ago',
this.temperature = 28.5,
this.humidity = 55.0,
this.deviceId = 'DEV-0024',
this.onViewHistory,
this.onManageTreatment,
});

Color _statusColor() {
switch (status) {
case 'Healthy':
return AppColors.healthy;
case 'Suspected':
return AppColors.suspected;
case 'Monitoring':
return AppColors.monitoring;
case 'Treated':
return AppColors.treated;
default:
return AppColors.textSecondary;
}
}

IconData _statusIcon() {
switch (status) {
case 'Healthy':
return Icons.check_circle_rounded;
case 'Suspected':
return Icons.warning_rounded;
case 'Monitoring':
return Icons.access_time_rounded;
case 'Treated':
return Icons.medical_services_rounded;
default:
return Icons.info_outline_rounded;
}
}

@override
Widget build(BuildContext context) {
final statusColor = _statusColor();
final isSuspected = status == 'Suspected';

return Scaffold(
appBar: AppBar(
title: const Text('Palm Details'),
centerTitle: true,
),
body: SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// Palm image and identification
Card(
margin: EdgeInsets.zero,
child: Padding(
padding: const EdgeInsets.all(16),
child: Row(
children: [
Container(
width: 100,
height: 112,
decoration: BoxDecoration(
color: AppColors.beige,
borderRadius: BorderRadius.circular(14),
),
child: const Icon(
Icons.park_rounded,
size: 64,
color: AppColors.primary,
),
),
const SizedBox(width: 16),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Palm #$palmId',
style: Theme.of(context)
    .textTheme
    .titleLarge,
),
const SizedBox(height: 8),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 6,
),
decoration: BoxDecoration(
color: statusColor.withValues(alpha: 0.12),
borderRadius: BorderRadius.circular(8),
),
child: Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
_statusIcon(),
size: 17,
color: statusColor,
),
const SizedBox(width: 6),
Text(
status,
style: TextStyle(
fontFamily: 'Cairo',
fontSize: 13,
fontWeight: FontWeight.w600,
color: statusColor,
),
),
],
),
),
const SizedBox(height: 8),

],
),
),
],
),
),
),

// Suspected infestation alert
if (isSuspected) ...[
const SizedBox(height: 16),
Container(
width: double.infinity,
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
color: AppColors.suspected.withValues(alpha: 0.08),
borderRadius: BorderRadius.circular(14),
border: Border.all(
color: AppColors.suspected.withValues(alpha: 0.35),
),
),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Icon(
Icons.warning_amber_rounded,
color: AppColors.suspected,
size: 26,
),
const SizedBox(width: 10),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'Potential Infestation Detected',
style: TextStyle(
fontFamily: 'Cairo',
fontSize: 15,
fontWeight: FontWeight.w700,
color: AppColors.suspected,
),
),
const SizedBox(height: 4),
Text(
'Possible signs of Red Palm Weevil activity '
'have been detected. Further inspection may '
'be required.',
style: Theme.of(context)
    .textTheme
    .bodySmall
    ?.copyWith(height: 1.5),
),
],
),
),
],
),
),
],

const SizedBox(height: 24),

// Monitoring information

  DefaultTabController(
    length: 2,
    child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: 'Live Data'),
              Tab(text: 'Device Info'),
            ],
          ),
          SizedBox(
            height: 255,
            child: TabBarView(
              children: [
                // Live Data tab
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _LiveDataRow(
                        icon: Icons.thermostat_rounded,
                        title: 'Temperature',
                        value: '${temperature.toStringAsFixed(1)} °C',
                      ),
                      const Divider(height: 20),
                      _LiveDataRow(
                        icon: Icons.water_drop_rounded,
                        title: 'Humidity',
                        value: '${humidity.toStringAsFixed(1)}%',
                      ),
                      const Divider(height: 20),
                      _LiveDataRow(
                        icon: Icons.access_time_rounded,
                        title: 'Last Update',
                        value: updated,
                      ),
                      const Divider(height: 20),
                      _LiveDataRow(
                        icon: Icons.sensors_rounded,
                        title: 'Sensor Status',
                        value: 'Online',
                        valueColor: AppColors.healthy,
                        valueIcon: Icons.circle,
                      ),
                    ],
                  ),
                ),

                // Device Info tab
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LiveDataRow(
                        icon: Icons.tag_rounded,
                        title: 'Sensor ID',
                        value: deviceId,
                      ),
                      const Divider(height: 20),
                      _LiveDataRow(
                        icon: Icons.sensors_rounded,
                        title: 'Vibration Sensor',
                        value: 'Piezoelectric',
                      ),
                      const Divider(height: 20),
                      _LiveDataRow(
                        icon: Icons.thermostat_rounded,
                        title: 'Environmental Sensor',
                        value: 'DHT22',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Measures temperature and humidity',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),

const SizedBox(height: 28),

// View history button

  SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MonitoringHistoryPage(
              palmId: palmId,
            ),
          ),
        );
      },
      icon: const Icon(Icons.history_rounded),
      label: const Text('View History'),
    ),
  ),


// Manage treatment button

  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TreatmentRecordPage(
              palmId: palmId,
              onMarkedTreated: onManageTreatment,
            ),
          ),
        );
      },
      icon: const Icon(Icons.medical_services_outlined),
      label: const Text('Manage Treatment'),
    ),
  ),
],
),
),
),
);
}
}

class _MeasurementCard extends StatelessWidget {
final String title;
final String value;
final String unit;
final IconData icon;
final Color iconColor;

const _MeasurementCard({
required this.title,
required this.value,
required this.unit,
required this.icon,
required this.iconColor,
});

@override
Widget build(BuildContext context) {
return Card(
margin: EdgeInsets.zero,
child: Padding(
padding: const EdgeInsets.all(14),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(icon, color: iconColor, size: 28),
const SizedBox(height: 12),
Text(
title,
style: Theme.of(context)
    .textTheme
    .bodySmall,
),
const SizedBox(height: 6),
Row(
crossAxisAlignment: CrossAxisAlignment.baseline,
textBaseline: TextBaseline.alphabetic,
children: [
Flexible(
child: Text(
value,
style: Theme.of(context)
    .textTheme
    .headlineMedium
    ?.copyWith(fontSize: 25),
),
),
const SizedBox(width: 4),
Text(
unit,
style: Theme.of(context)
    .textTheme
    .bodyMedium
    ?.copyWith(
color: AppColors.textSecondary,
),
),
],
),
],
),
),
);
}
}

class _InfoRow extends StatelessWidget {
final IconData icon;
final String title;
final String value;

const _InfoRow({
required this.icon,
required this.title,
required this.value,
});

@override
Widget build(BuildContext context) {
return Row(
children: [
Icon(
icon,
color: AppColors.primary,
size: 23,
),
const SizedBox(width: 12),
Expanded(
child: Text(
title,
style: Theme.of(context)
    .textTheme
    .bodyMedium
    ?.copyWith(
color: AppColors.textSecondary,
),
),
),
Flexible(
child: Text(
value,
textAlign: TextAlign.end,
style: Theme.of(context)
    .textTheme
    .bodyLarge
    ?.copyWith(
fontWeight: FontWeight.w600,
),
),
),
],
);
}
}

class _SensorItem extends StatelessWidget {
final String name;
final String? subtitle;

const _SensorItem({
required this.name,
this.subtitle,
});

@override
Widget build(BuildContext context) {
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Padding(
padding: EdgeInsets.only(top: 5),
child: Icon(
Icons.circle,
size: 7,
color: AppColors.secondary,
),
),
const SizedBox(width: 8),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
name,
style: Theme.of(context)
    .textTheme
    .bodyMedium
    ?.copyWith(
fontWeight: FontWeight.w600,
),
),
if (subtitle != null) ...[
const SizedBox(height: 2),
Text(
subtitle!,
style: Theme.of(context)
    .textTheme
    .bodySmall,
),
],
],
),
),
],
);
}
}

class _LiveDataRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  final IconData? valueIcon;

  const _LiveDataRow({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
    this.valueIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (valueIcon != null) ...[
          Icon(
            valueIcon,
            size: 9,
            color: valueColor,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
