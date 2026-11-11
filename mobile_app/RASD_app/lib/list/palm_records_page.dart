
import 'package:flutter/material.dart';
import '../data/auth_store.dart';
import '../theme/app_colors.dart';
import 'monitoring_history.dart';
import 'treatment_record.dart';

/// Combines monitoring history and treatment records.
class PalmRecordsPage extends StatelessWidget {
  final String farmId;
  final String palmId;
  final int initialIndex;
  final VoidCallback? onMarkedTreated;

  const PalmRecordsPage({
    super.key,
    required this.farmId,
    required this.palmId,
    this.initialIndex = 0,
    this.onMarkedTreated,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthStore.arabic,
      builder: (context, isArabic, child) {
        return Directionality(
          textDirection:
          isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: DefaultTabController(
            length: 2,
            initialIndex: initialIndex,
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  isArabic ? 'سجلات النخلة' : 'Palm Records',
                ),
                centerTitle: true,
                bottom: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor:
                  AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(
                      text: isArabic
                          ? 'سجل المراقبة'
                          : 'Monitoring History',
                    ),
                    Tab(
                      text: isArabic
                          ? 'العلاج'
                          : 'Treatment',
                    ),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  MonitoringHistoryPage(
                    farmId: farmId,
                    palmId: palmId,
                    showAppBar: false,
                  ),
                  TreatmentRecordPage(
                    farmId: farmId,
                    palmId: palmId,
                    onMarkedTreated: onMarkedTreated,
                    showAppBar: false,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
