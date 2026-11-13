// Palm details screen: live sensor data, status and treatment history for one palm.

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/palm_icon.dart';
import '../theme/app_colors.dart';
import 'palm_records_page.dart';
import '../data/auth_store.dart';
/// Palm details page.
class PalmDetailsPage extends StatefulWidget {
  final String farmId;
  final String palmId;


  // Kept for compatibility with existing navigation calls.
  final String status;
  final String updated;
  final double? temperature;
  final double? humidity;
  final String deviceId;

  final VoidCallback? onViewHistory;
  final VoidCallback? onManageTreatment;

  const PalmDetailsPage({
    super.key,
    required this.farmId,
    required this.palmId,
    this.status = '',
    this.updated = '',
    this.temperature,
    this.humidity,
    this.deviceId = '',
    this.onViewHistory,
    this.onManageTreatment,


  });

  @override
  State<PalmDetailsPage> createState() =>
      _PalmDetailsPageState();
}

class _PalmDetailsPageState extends State<PalmDetailsPage> {
  late DatabaseReference _palmRef;
  late Stream<DatabaseEvent> _palmStream;

  /// Starts listening to this palm in Realtime Database.
  @override
  void initState() {
    super.initState();
    _configurePalmStream();
  }

  /// Re-subscribes when the widget receives new parameters.
  @override
  void didUpdateWidget(covariant PalmDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.farmId != widget.farmId ||
        oldWidget.palmId != widget.palmId) {
      _configurePalmStream();
    }
  }

  /// Subscribes to live updates for this palm.
  void _configurePalmStream() {
    _palmRef = FirebaseDatabase.instance.ref(
      'palms/${widget.farmId}/${widget.palmId}',
    );
    _palmStream = _palmRef.onValue;
  }

  /// Turns a raw status value into a readable label.
  String _statusLabel(Object? raw) {
    final value = (raw ?? '').toString().toLowerCase();

    switch (value) {
      case 'healthy':
        return 'Healthy';
      case 'suspected':
        return 'Suspected';
      case 'undermonitoring':
      case 'monitoring':
        return 'Under Monitoring';
      default:
        return 'Unknown';
    }
  }

  /// Maps a palm status to its colour.
  Color _statusColor(String status) {
    switch (status) {
      case 'Healthy':
        return AppColors.healthy;
      case 'Suspected':
        return AppColors.suspected;
      case 'Under Monitoring':
        return AppColors.monitoring;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Maps a palm status to its icon.
  IconData _statusIcon(String status) {
    switch (status) {
      case 'Healthy':
        return Icons.check_circle_rounded;
      case 'Suspected':
        return Icons.warning_rounded;
      case 'Under Monitoring':
        return Icons.access_time_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  /// Formats a database timestamp for display.
  String _formatTimestamp(Object? value) {
    if (value == null) {
      return AuthStore.arabic.value
          ? 'لا توجد قراءة حتى الآن'
          : 'No reading yet';
    }

    DateTime? date;

    if (value is num) {
      final timestamp = value.toInt();
      date = DateTime.fromMillisecondsSinceEpoch(
        timestamp < 100000000000
            ? timestamp * 1000
            : timestamp,
      );
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return AuthStore.arabic.value
          ? 'لا توجد قراءة حتى الآن'
          : 'No reading yet';
    }

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  /// Formats a sensor value with its unit (or a dash when missing).
  String _measurement(Object? value, String unit) {
    if (value is! num) {
      return AuthStore.arabic.value
          ? 'لا توجد قراءة حتى الآن'
          : 'No reading yet';
    }
    return '${value.toStringAsFixed(1)}$unit';
  }

  /// Full-screen loading indicator.
  Widget _loadingPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AuthStore.arabic.value
              ? 'تفاصيل النخلة'
              : 'Palm Details',
        ),
        centerTitle: true,
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Full-screen message page.
  Widget _messagePage(String message) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AuthStore.arabic.value
              ? 'تفاصيل النخلة'
              : 'Palm Details',
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {

return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
return StreamBuilder<DatabaseEvent>(
      stream: _palmStream,
      builder: (context, palmSnapshot) {
        if (palmSnapshot.hasError) {
return _messagePage(
isArabic
? 'تعذر تحميل تفاصيل النخلة.'
: 'Unable to load palm details.',
);
        }

        if (!palmSnapshot.hasData) {
          return _loadingPage();
        }

        final rawPalm = palmSnapshot.data!.snapshot.value;

        if (rawPalm is! Map) {
return _messagePage(
isArabic ? 'لم يتم العثور على النخلة.' : 'Palm not found.',
);
        }

        final palm = Map<String, dynamic>.from(rawPalm);

        final status = _statusLabel(
          palm['healthStatus'],
        );

        final deviceId =
        (palm['deviceId'] ?? '').toString();

        if (deviceId.isEmpty) {
          return _buildDetails(
            palm: palm,
            status: status,
            deviceId: '',
            device: const {},
          );
        }

        return StreamBuilder<DatabaseEvent>(
          key: ValueKey(deviceId),
          stream: FirebaseDatabase.instance
              .ref('monitoringDevices/$deviceId')
              .onValue,
          builder: (context, deviceSnapshot) {
            if (deviceSnapshot.hasError) {
return _messagePage(
isArabic
? 'تعذر تحميل بيانات المستشعر.'
: 'Unable to load sensor data.',
);
            }

            if (!deviceSnapshot.hasData) {
              return _loadingPage();
            }

            final rawDevice =
                deviceSnapshot.data!.snapshot.value;

            final device = rawDevice is Map
                ? Map<String, dynamic>.from(rawDevice)
                : <String, dynamic>{};

            return _buildDetails(
              palm: palm,
              status: status,
              deviceId: deviceId,
              device: device,
            );
          },
        );
      },
);
},
);
}

  /// Translates a palm type without changing the stored value.
  String _displayPalmType(String type, bool isArabic) {
    if (!isArabic) return type;
    switch (type) {
      case 'Sukkari': return 'سكري';
      case 'Khalas': return 'خلاص';
      case 'Ajwa': return 'عجوة';
      case 'Barhi': return 'برحي';
      default: return type;
    }
  }

  /// Builds the main palm details content.
  Widget _buildDetails({
    required Map<String, dynamic> palm,
    required String status,
    required String deviceId,
    required Map<String, dynamic> device,
  }) {
    final statusColor = _statusColor(status);
    final isSuspected = status == 'Suspected';
    final isArabic = AuthStore.arabic.value;

    final displayStatus = isArabic
        ? (status == 'Healthy'
        ? 'سليمة'
        : status == 'Suspected'
        ? 'مشتبه بالإصابة'
        : status == 'Under Monitoring'
        ? 'تحت المراقبة'
        : 'غير معروف')
        : status;

    final temperatureText = _measurement(
      device['temperature'],
      ' °C',
    );

    final humidityText = _measurement(
      device['humidity'],
      '%',
    );

    final lastUpdateText = _formatTimestamp(
      device['lastSeen'],
    );

    final connectionStatus =
    (device['connectionStatus'] ?? 'Unknown').toString();

    final displayConnectionStatus = isArabic
        ? (connectionStatus == 'Online'
        ? 'متصل'
        : connectionStatus == 'Offline'
        ? 'غير متصل'
        : 'غير معروف')
        : connectionStatus;

    final isOnline = connectionStatus == 'Online';

    final connectionColor = isOnline
        ? AppColors.healthy
        : AppColors.textSecondary;

    final rawPalmType =
    (palm['palmType'] ?? (isArabic ? 'غير متاح' : 'Not available')).toString();
    final palmType = _displayPalmType(rawPalmType, isArabic);

    final palmAge = palm['age'] is num
        ? (isArabic ? '${palm['age']} سنة' : '${palm['age']} years')
        : (isArabic ? 'غير متاح' : 'Not available');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'تفاصيل النخلة' : 'Palm Details',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20, 12, 20, 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Palm identification card
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
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        child: const PalmIcon(
                          size: 64,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'النخلة ${widget.palmId}' : 'Palm #${widget.palmId}',
                              style: Theme.of(context)
                                  .textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _statusIcon(status),
                                    size: 17,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      displayStatus,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 13,
                                        fontWeight:
                                        FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
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

              // Suspected infestation warning
              if (isSuspected) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.suspected
                        .withValues(alpha: 0.08),
                    borderRadius:
                    BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.suspected
                          .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.suspected,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'اشتباه بوجود إصابة'
                                  : 'Potential Infestation Detected',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.suspected,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArabic
                                  ? 'تم رصد علامات محتملة لنشاط سوسة النخيل الحمراء. '
                                  'قد يتطلب الأمر إجراء فحص إضافي.'
                                  : 'Possible signs of Red Palm Weevil activity have been detected. '
                                  'Further inspection may be required.',
                              style: Theme.of(context)
                                  .textTheme.bodySmall
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Palm information
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'معلومات النخلة' : 'Palm Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.park_outlined,
                        title: isArabic ? 'نوع النخلة' : 'Palm Type',
                        value: palmType,
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        title: isArabic ? 'عمر النخلة' : 'Palm Age',
                        value: palmAge,
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        title: isArabic ? 'الموقع' : 'Location',
                        value:
                        palm['latitude'] is num &&
                            palm['longitude'] is num
                            ? '${palm['latitude']}, '
                            '${palm['longitude']}'
                            : (isArabic ? 'غير متاح' : 'Not available'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Live data and device information
              DefaultTabController(
                length: 2,
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor:
                        AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        labelStyle: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                         tabs: [
                           Tab(text: isArabic ? 'البيانات المباشرة' : 'Live Data'),
                           Tab(text: isArabic ? 'معلومات الجهاز' : 'Device Info'),
                         ],
                      ),
                      SizedBox(
                        height: 255,
                        child: TabBarView(
                          children: [
                            // Live Data tab
                            Padding(
                              padding:
                              const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _LiveDataRow(
                                    icon: Icons
                                        .thermostat_rounded,
                                    title: isArabic ? 'درجة الحرارة' : 'Temperature',
                                    value: temperatureText,
                                  ),
                                  const Divider(height: 20),
                                  _LiveDataRow(
                                    icon: Icons
                                        .water_drop_rounded,
                                    title: isArabic ? 'الرطوبة' : 'Humidity',
                                    value: humidityText,
                                  ),
                                  const Divider(height: 20),
                                  _LiveDataRow(
                                    icon: Icons
                                        .access_time_rounded,
                                    title: isArabic ? 'آخر تحديث' : 'Last Update',
                                    value: lastUpdateText,
                                  ),
                                  const Divider(height: 20),
                                  _LiveDataRow(
                                    icon: Icons.sensors_rounded,
                                    title: isArabic ? 'حالة المستشعر' : 'Sensor Status',
                                    value: displayConnectionStatus,
                                    valueColor:
                                    connectionColor,
                                    valueIcon: Icons.circle,
                                  ),
                                ],
                              ),
                            ),

                            // Device Info tab
                            Padding(
                              padding:
                              const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  _LiveDataRow(
                                    icon: Icons.tag_rounded,
                                    title: isArabic ? 'معرّف المستشعر' : 'Sensor ID',
                                    value: deviceId.isEmpty
                                        ? (isArabic ? 'غير متصل' : 'Not connected')
                                        : deviceId,
                                  ),
                                  const Divider(height: 20),
                                  _LiveDataRow(
                                    icon: Icons.sensors_rounded,
                                    title: isArabic ? 'مستشعر الاهتزاز' : 'Vibration Sensor',
                                    value: isArabic ? 'مستشعر كهرضغطي' : 'Piezoelectric',
                                  ),
                                  const Divider(height: 20),
                                  _LiveDataRow(
                                    icon: Icons.thermostat_rounded,
                                    title: isArabic ? 'المستشعر البيئي' : 'Environmental Sensor',
                                    value: 'DHT22',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isArabic
                                        ? 'يقيس درجة الحرارة والرطوبة'
                                        : 'Measures temperature and humidity',
                                    style: Theme.of(context)
                                        .textTheme.bodySmall,
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

              // Palm Records
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PalmRecordsPage(
                          farmId: widget.farmId,
                          palmId: widget.palmId,
                          initialIndex: 0,
                          onMarkedTreated: widget.onManageTreatment,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.folder_outlined),
                  label: Text(
                    isArabic ? 'سجلات النخلة' : 'Palm Records',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row showing one live sensor value.
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
            style: Theme.of(context)
                .textTheme.bodyMedium
                ?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
            MainAxisAlignment.end,
            children: [
              if (valueIcon != null) ...[
                Icon(
                  valueIcon,
                  size: 9,
                  color: valueColor ??
                      AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context)
                      .textTheme.bodyMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Row showing a label and a value.
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
        appIcon(
          icon,
          color: AppColors.primary,
          size: 23,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme.bodyMedium
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
                .textTheme.bodyLarge
                ?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
