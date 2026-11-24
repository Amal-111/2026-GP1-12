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

  static DateTime? parseTimestamp(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is! num || !value.isFinite) return null;
    final milliseconds = value >= 0 && value < 100000000000
        ? value * 1000
        : value;
    if (milliseconds.abs() > 8640000000000000) return null;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt());
  }

  /// Creates an alert using its original Firebase fields and identifiers.
  factory RasdAlert.fromMap(
      String id,
      String farmId,
      Map<dynamic, dynamic> data,
      ) {
    return RasdAlert(
      id: id,
      farmId: farmId,
      palmId: (data['palmId'] ?? '').toString(),
      type: (data['alertType'] ?? '').toString(),
      createdAt: parseTimestamp(data['timestamp']) ??
          parseTimestamp(data['createdAt']),
      isRead: data['isRead'] == true,
    );
  }
}

/// Reads alerts.
class RasdAlertService {
  static final _invalidKey = RegExp(r'[.#$\[\]/\x00-\x1f\x7f]');

  static Stream<DatabaseEvent>? watchAlert(RasdAlert alert) {
    final keys = [alert.farmId, alert.palmId, alert.id];
    if (keys.any((key) => key.trim().isEmpty || _invalidKey.hasMatch(key))) {
      return null;
    }
    return _db.ref('farms/${alert.farmId}/palms/${alert.palmId}/alerts/${alert.id}').onValue;
  }

  static final FirebaseDatabase _db =
      FirebaseDatabase.instance;

  /// Streams and sorts the selected farm's alerts by timestamp.
  static Stream<List<RasdAlert>> watchAlerts(
      String farmId,
      ) {
    // Alerts are embedded in each palm; there is no global alerts node.
    return _db.ref('farms/$farmId/palms').onValue.map((event) {
      final palms = event.snapshot.value;
      if (palms is! Map) return <RasdAlert>[];
      final alerts = <RasdAlert>[];
      for (final palmEntry in palms.entries) {
        if (palmEntry.value is! Map) continue;
        final palmId = palmEntry.key.toString();
        final palm = palmEntry.value as Map;
        final palmAlerts = palm['alerts'];
        if (palmAlerts is! Map) continue;
        for (final alertEntry in palmAlerts.entries) {
          if (alertEntry.value is! Map) continue;
          final alert = Map<dynamic, dynamic>.from(alertEntry.value as Map);
          // Preserve the original alert ID and the parent palm ID.
          alert['palmId'] = palmId;
          alerts.add(RasdAlert.fromMap(
              alertEntry.key.toString(), farmId, alert));
        }
      }
      alerts.sort((a, b) =>
          (b.createdAt?.millisecondsSinceEpoch ?? 0)
              .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0));
      return alerts;
    });
  }
}
