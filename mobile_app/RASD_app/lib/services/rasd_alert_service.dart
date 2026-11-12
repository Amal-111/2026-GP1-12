// Reads alerts from Firebase Realtime Database.

import 'package:firebase_database/firebase_database.dart';

import '../data/auth_store.dart';

/// One alert from the database.
class RasdAlert {
  final String id;
  final String farmId;
  final String palmId;
  final String type;
  final DateTime? createdAt;
  final bool isRead;

  const RasdAlert({
    required this.id,
    required this.farmId,
    required this.palmId,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  bool get isOffline => type == 'SensorOffline';

  bool get isSuspected =>
      type == 'PossiblePestDetected';

  /// Returns a localized title based on the stored alert type.
  String get title {
    final isArabic = AuthStore.arabic.value;
    if (isOffline) return isArabic ? 'المستشعر غير متصل' : 'Sensor Offline';
    if (isSuspected) return isArabic ? 'اشتباه بوجود إصابة' : 'Potential Infestation';
    if (type == 'UnderMonitoring') {
      return isArabic ? 'النخلة تحت المراقبة' : 'Palm Under Monitoring';
    }
    return isArabic ? 'تنبيه المزرعة' : 'Farm Alert';
  }

  /// Returns a localized explanation without changing Firebase data.
  String get message {
    final isArabic = AuthStore.arabic.value;
    if (isOffline) {
      return isArabic
          ? 'المستشعر غير متصل. يرجى التحقق من اتصاله.'
          : 'The monitoring sensor is offline. Please check its connection.';
    }
    if (isSuspected) {
      return isArabic
          ? 'تم رصد نشاط محتمل لسوسة النخيل الحمراء.'
          : 'Possible Red Palm Weevil activity has been detected.';
    }
    if (type == 'UnderMonitoring') {
      return isArabic
          ? 'النخلة تحت المراقبة. يرجى متابعة حالتها.'
          : 'The palm is under monitoring. Please continue checking its condition.';
    }
    return isArabic
        ? 'تم تسجيل تنبيه جديد.'
        : 'A new alert has been recorded.';
  }

  /// Creates an alert using its original Firebase fields and identifiers.
  factory RasdAlert.fromMap(
      String id,
      String farmId,
      Map<dynamic, dynamic> data,
      ) {
    final rawTimestamp = data['timestamp'];

    DateTime? createdAt;

    if (rawTimestamp is num) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        rawTimestamp.toInt(),
      );
    }

    return RasdAlert(
      id: id,
      farmId: farmId,
      palmId: (data['palmId'] ?? '').toString(),
      type: (data['alertType'] ?? '').toString(),
      createdAt: createdAt,
      isRead: data['isRead'] == true,
    );
  }
}

/// Reads alerts.
class RasdAlertService {
  static final FirebaseDatabase _db =
      FirebaseDatabase.instance;

  /// Streams and sorts the selected farm's alerts by timestamp.
  static Stream<List<RasdAlert>> watchAlerts(
      String farmId,
      ) {
    return _db.ref('alerts/$farmId').onValue.map((event) {
      final value = event.snapshot.value;

      if (value is! Map) {
        return <RasdAlert>[];
      }

      final alerts = <RasdAlert>[];

      for (final entry in value.entries) {
        if (entry.value is! Map) continue;

        alerts.add(
          RasdAlert.fromMap(
            entry.key.toString(),
            farmId,
            entry.value as Map,
          ),
        );
      }

      alerts.sort((a, b) {
        final aTime =
            a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime =
            b.createdAt?.millisecondsSinceEpoch ?? 0;

        return bTime.compareTo(aTime);
      });

      return alerts;
    });
  }
}
