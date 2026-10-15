
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MonitoringHistoryPage extends StatelessWidget {
  final String palmId;

  const MonitoringHistoryPage({
    super.key,
    required this.palmId,
  });

  // Sample monitoring records for demonstration.

  static final List<Map<String, String>> _sampleRecords = [
    {
      'date': '15 Sep 2024',
      'time': '10:24 AM',
      'result': 'Possible Pest Detected',
    },
    {
      'date': '14 Sep 2024',
      'time': '08:00 AM',
      'result': 'No RPW Detected',
    },
    {
      'date': '13 Sep 2024',
      'time': '08:00 AM',
      'result': 'No RPW Detected',
    },
    {
      'date': '12 Sep 2024',
      'time': '08:00 AM',
      'result': 'No RPW Detected',
    },
    {
      'date': '11 Sep 2024',
      'time': '08:00 AM',
      'result': 'No RPW Detected',
    },
  ];

  bool _isPestDetected(String result) {
    return result == 'Possible Pest Detected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring History'),
        centerTitle: true,
      ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monitoring History - Palm #$palmId',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Previous monitoring records',
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

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  24,
                ),
                itemCount: _sampleRecords.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final record = _sampleRecords[index];
                  final result = record['result']!;
                  final isDetected = _isPestDetected(result);

                  final resultColor = isDetected
                      ? AppColors.suspected
                      : AppColors.healthy;

                  return Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MonitoringRecordDetailsPage(
                                  palmId: palmId,
                                  date: record['date']!,
                                  time: record['time']!,
                                  result: result,
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
                                color: resultColor.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isDetected
                                    ? Icons.warning_rounded
                                    : Icons.check_circle_rounded,
                                color: resultColor,
                                size: 25,
                              ),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${record['date']} • ${record['time']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    result,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonitoringRecordDetailsPage extends StatelessWidget {
  final String palmId;
  final String date;
  final String time;
  final String result;

  const MonitoringRecordDetailsPage({
    super.key,
    required this.palmId,
    required this.date,
    required this.time,
    required this.result,
  });

  bool get _isPestDetected {
    return result == 'Possible Pest Detected';
  }

  @override
  Widget build(BuildContext context) {
    final resultColor = _isPestDetected
        ? AppColors.suspected
        : AppColors.healthy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Record'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Palm #$palmId',
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
                            _isPestDetected
                                ? Icons.warning_rounded
                                : Icons.check_circle_rounded,
                            color: resultColor,
                            size: 42,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: Text(
                          result,
                          textAlign: TextAlign.center,
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
                        title: 'Date',
                        value: date,
                      ),

                      const SizedBox(height: 20),

                      _RecordInfoRow(
                        icon: Icons.access_time_rounded,
                        title: 'Time',
                        value: time,
                      ),
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

class _RecordInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _RecordInfoRow({
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
