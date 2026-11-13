// Monitoring history of a palm and the details page of a single monitoring record.
import 'package:flutter/material.dart';
import '../theme/glass_widgets.dart';
import '../theme/app_colors.dart';
import 'package:firebase_database/firebase_database.dart';
import '../data/auth_store.dart';
/// Shows the monitoring history of a palm.
class MonitoringHistoryPage extends StatelessWidget {
  final String farmId;
  final String palmId;
  final bool showAppBar;

  const MonitoringHistoryPage({
    super.key,
    required this.farmId,
    required this.palmId,
    this.showAppBar = true,
  });


  /// Reads monitoring and treatment events from the unified history.
  List<Map<String, String>> _recordsFromData(Object? data) {
    if (data is! Map) return [];

    final records = <Map<String, String>>[];

    for (final entry in data.entries) {
      if (entry.value is! Map) continue;

      final value = Map<Object?, Object?>.from(entry.value as Map);

      final rawTimestamp = value['timestamp'];

      final number = rawTimestamp is num
          ? rawTimestamp.toInt()
          : int.tryParse(rawTimestamp?.toString() ?? '');

      if (number == null) continue;

      final dateTime = DateTime.fromMillisecondsSinceEpoch(
        number < 100000000000 ? number * 1000 : number,
      ).toLocal();

      final status = (value['healthStatus'] ?? '').toString();

      final normalizedStatus = status
          .trim()
          .replaceAll(RegExp(r'[\s_]'), '')
          .toLowerCase();

      final eventType =
      (value['eventType'] ?? 'Monitoring').toString().trim();

      final isTreatment = eventType.toLowerCase() == 'treatment';

      final result = switch (normalizedStatus) {
        'suspected' => 'Possible Pest Detected',
        'undermonitoring' || 'monitoring' => 'Under Monitoring',
        'healthy' => 'Healthy',
        _ => 'Unknown',
      };

      final details = value['treatmentDetails'];

      final treatmentDetails = details is Map
          ? Map<Object?, Object?>.from(details)
          : <Object?, Object?>{};

      records.add({
        'date':
        '${dateTime.day}/${dateTime.month}/${dateTime.year}',
        'time':
        '${dateTime.hour.toString().padLeft(2, '0')}:'
            '${dateTime.minute.toString().padLeft(2, '0')}',
        'result': result,
        'eventType': isTreatment ? 'Treatment' : 'Monitoring',
        'treatmentDate':
        (treatmentDetails['treatmentDate'] ?? '').toString(),
        'treatmentMethod':
        (treatmentDetails['treatmentMethod'] ?? '').toString(),
        'notes':
        (treatmentDetails['notes'] ?? '').toString(),
        'timestamp': number.toString(),
      });
    }

    records.sort(
          (a, b) => int.parse(b['timestamp']!)
          .compareTo(int.parse(a['timestamp']!)),
    );

    return records;
  }


  /// True when the monitoring result says a pest was detected.
  bool _isPestDetected(String result) {
    return result == 'Possible Pest Detected';
  }

/// Builds the page with localized labels.
@override
Widget build(BuildContext context) {
return ValueListenableBuilder<bool>(
valueListenable: AuthStore.arabic,
builder: (context, isArabic, child) {
  return Scaffold(
    appBar: showAppBar
        ? AppBar(
      title: Text(
        isArabic ? 'سجل المراقبة' : 'Monitoring History',
      ),
      centerTitle: true,
    )
        : null,
    body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                16,
              ),
      child: SizedBox(
        width: double.infinity,
              child: GlassLabel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
isArabic
? 'سجل المراقبة - $palmId'
: 'Monitoring History - $palmId',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
isArabic
? 'سجلات المراقبة السابقة'
: 'Previous monitoring records',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              ),
      ),
            ),

            Expanded(
              child: StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('monitoringHistory/$farmId/$palmId')
                    .onValue,
                builder: (context, snapshot) {
if (snapshot.hasError) {
return Center(
child: GlassLabel(
child: Text(
isArabic
? 'تعذر تحميل سجل المراقبة.'
: 'Unable to load monitoring history.',
),
),
);
}
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final records = _recordsFromData(snapshot.data!.snapshot.value);
return records.isEmpty
    ? Center(
  child: GlassLabel(
    child: Text(
      isArabic
          ? 'لا توجد سجلات مراقبة حتى الآن.'
          : 'No monitoring events yet.',
    ),
  ),
)
    : ListView.separated(
  padding: const EdgeInsets.fromLTRB(
    20,
    0,
    20,
    24,
  ),
  itemCount: records.length,
  separatorBuilder: (_, __) => const SizedBox(height: 10),
  itemBuilder: (context, index) {
    final record = records[index];
    final result = record['result']!;
    final isDetected = _isPestDetected(result);
    final isTreatment = record['eventType'] == 'Treatment';

    final resultColor = isTreatment
        ? AppColors.primary
        : (isDetected ? AppColors.suspected : AppColors.healthy);


    return GlassCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MonitoringRecordDetailsPage(
                palmId: palmId,
                date: record['date']!,
                time: record['time']!,
                result: result,
                eventType: record['eventType']!,
                treatmentDate: record['treatmentDate']!,
                treatmentMethod: record['treatmentMethod']!,
                notes: record['notes']!,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTreatment
                      ? Icons.medical_services_outlined
                      : (isDetected
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded),
                  color: resultColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record['date']} • ${record['time']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isTreatment
                          ? (isArabic ? 'تم تسجيل علاج' : 'Treatment Recorded')
                          : (isArabic
                          ? (result == 'Possible Pest Detected'
                          ? 'مشتبه بالإصابة'
                          : result == 'Under Monitoring'
                          ? 'تحت المراقبة'
                          : result == 'Healthy'
                          ? 'سليمة'
                          : 'غير معروف')
                          : result),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: resultColor,
                      ),
                    ),

                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  },
);
                },
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

/// Details of one monitoring record.

class MonitoringRecordDetailsPage extends StatelessWidget {
  final String palmId;
  final String date;
  final String time;
  final String result;
  final String eventType;
  final String treatmentDate;
  final String treatmentMethod;
  final String notes;

  const MonitoringRecordDetailsPage({
    super.key,
    required this.palmId,
    required this.date,
    required this.time,
    required this.result,
    this.eventType = 'Monitoring',
    this.treatmentDate = '',
    this.treatmentMethod = '',
    this.notes = '',
  });

  bool get _isPestDetected {
    return result == 'Possible Pest Detected';
  }

  /// Identifies treatment events in the unified history.
  bool get _isTreatment => eventType == 'Treatment';

  /// Displays the record result in the selected language.
  String _localizedResult(bool isArabic) {
    if (_isTreatment) {
      return isArabic
          ? 'تم تسجيل علاج'
          : 'Treatment Recorded';
    }

    if (!isArabic) return result;

    return switch (result) {
      'Possible Pest Detected' => 'مشتبه بالإصابة',
      'Under Monitoring' => 'تحت المراقبة',
      'Healthy' => 'سليمة',
      _ => 'غير معروف',
    };
  }

  /// Translates the saved treatment method for display only.
  String _localizedMethod(bool isArabic) {
    if (!isArabic) return treatmentMethod;

    return switch (treatmentMethod) {
      'Chemical Treatment' => 'علاج كيميائي',
      'Biological Treatment' => 'علاج بيولوجي',
      'Mechanical Treatment' => 'علاج ميكانيكي',
      'Other' => 'أخرى',
      _ => treatmentMethod,
    };
  }

  /// Builds the page with localized labels.
  @override
  Widget build(BuildContext context) {
    final resultColor = _isTreatment
        ? AppColors.primary
        : (_isPestDetected
        ? AppColors.suspected
        : AppColors.healthy);

    final isArabic = AuthStore.arabic.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'تفاصيل السجل' : 'Record Details',
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        palmId,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge,
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: resultColor.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isTreatment
                                ? Icons.medical_services_outlined
                                : (_isPestDetected
                                ? Icons.warning_rounded
                                : Icons.check_circle_rounded),
                            color: resultColor,
                            size: 42,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: Text(
                          _localizedResult(isArabic),                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: resultColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),


                      _RecordInfoRow(
                        icon: Icons.calendar_today_rounded,
                        title: isArabic ? 'التاريخ' : 'Date',
                        value: date,
                      ),

                      const SizedBox(height: 20),

                      _RecordInfoRow(
                        icon: Icons.access_time_rounded,
                        title: isArabic ? 'الوقت' : 'Time',
                        value: time,
                      ),

                      if (_isTreatment) ...[
                        const SizedBox(height: 20),

                        _RecordInfoRow(
                          icon: Icons.info_outline_rounded,
                          title: isArabic ? 'الحالة الصحية' : 'Health Status',
                          value: isArabic ? 'تحت المراقبة' : result,
                        ),

                        if (treatmentDate.isNotEmpty) ...[
                          const SizedBox(height: 20),

                          _RecordInfoRow(
                            icon: Icons.event_rounded,
                            title: isArabic ? 'تاريخ العلاج' : 'Treatment Date',
                            value: treatmentDate,
                          ),
                        ],

                        if (treatmentMethod.isNotEmpty) ...[
                          const SizedBox(height: 20),

                          _RecordInfoRow(
                            icon: Icons.medical_services_outlined,
                            title: isArabic ? 'طريقة العلاج' : 'Treatment Method',
                            value: _localizedMethod(isArabic),
                          ),
                        ],

                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 20),

                          _RecordInfoRow(
                            icon: Icons.notes_rounded,
                            title: isArabic ? 'الملاحظات' : 'Notes',
                            value: notes,
                          ),
                        ],
                      ],

                    ],
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

/// Row showing a label and a value.
class _RecordInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _RecordInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  /// Builds the page with localized labels.
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
                .bodyMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
