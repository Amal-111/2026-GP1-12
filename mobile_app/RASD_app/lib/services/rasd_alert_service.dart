
import 'package:firebase_database/firebase_database.dart';

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

  String get title {
    if (isOffline) return 'Sensor Offline';
    if (isSuspected) return 'Potential Infestation';
    return 'Farm Alert';
  }

  String get message {
    if (isOffline) {
      return 'The monitoring sensor is offline. '
          'Please check its connection.';
    }

    if (isSuspected) {
      return 'Possible Red Palm Weevil activity '
          'has been detected.';
    }

    return 'A new alert has been recorded.';
  }

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

class RasdAlertService {
  static final FirebaseDatabase _db =
      FirebaseDatabase.instance;

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
