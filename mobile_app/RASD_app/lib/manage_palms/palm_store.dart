import 'package:flutter/foundation.dart';
import '../data/mock_data.dart';

/// The Manage Palms pages use the team's shared data (MockData), so a palm
/// added, edited or deleted here also changes in Home, the palm list,
/// the map and the alerts.
typedef Palm = PalmData;

/// Extra helpers for the Manage Palms pages.
extension PalmInfo on PalmData {
  double get latitude => _part(location, 0);
  double get longitude => _part(location, 1);

  /// 'Healthy', 'Suspected' or 'Under Monitoring'.
  String get statusLabel => palmStatusLabel(status);

  static double _part(String text, int index) {
    final parts = text.split(',');
    if (parts.length != 2) return 0;
    return double.tryParse(parts[index].trim()) ?? 0;
  }
}

class PalmStore {
  PalmStore._();
  static final PalmStore instance = PalmStore._();

  /// Pages listen to this to refresh when the data changes.
  Listenable get changes => MockData.changes;

  /// The farm the user works on (null = not assigned to any farm).
  String? get activeFarmId {
    final user = MockData.currentUser;
    if (user.role == UserRole.farmer) return user.farmId;
    return MockData.selectedFarmId;
  }

  List<PalmData> get palms {
    final farmId = activeFarmId;
    if (farmId == null || farmId.isEmpty) return [];
    return MockData.palmsForFarm(farmId);
  }

  static const List<String> palmTypes = [
    'Sukkari',
    'Khalas',
    'Ajwa',
    'Barhi',
  ];

  static const List<String> statuses = [
    'Healthy',
    'Suspected',
    'Under Monitoring',
  ];

  static PalmStatus statusFromLabel(String label) => switch (label) {
        'Suspected' => PalmStatus.suspected,
        'Under Monitoring' => PalmStatus.underMonitoring,
        _ => PalmStatus.healthy,
      };

  /// Next palm ID given by the system (P008, P009...).
  String nextPalmId() => MockData.nextPalmId();

  bool idExists(String id, {PalmData? except}) {
    return MockData.palms.any((p) => p.id == id.trim() && p != except);
  }

  static bool isDigits(String value) => RegExp(r'^\d+$').hasMatch(value.trim());

  static String _pad(String number) =>
      (int.tryParse(number.trim()) ?? 0).toString().padLeft(3, '0');

  /// What the user typed -> full palm ID: "8" -> "P008".
  static String palmIdFromNumber(String number) => 'P${_pad(number)}';

  /// The number part of a palm ID: "P008" -> "008".
  static String numberFromPalmId(String id) =>
      id.replaceAll(RegExp(r'[^0-9]'), '');

  /// What the user typed -> full sensor ID: "8" -> "D008".
  static String deviceIdFromNumber(String number) => 'D${_pad(number)}';

  /// [number] is what the user typed. Returns an error message, or null
  /// if the sensor can be connected.
  String? checkDevice(String number) {
    if (number.trim().isEmpty) return 'Device ID is required.';
    if (!isDigits(number)) return 'Device ID must be a number.';
    final id = deviceIdFromNumber(number);
    if (!MockData.devices.contains(id)) {
      return 'Device not found. Please check the device ID.';
    }
    if (MockData.palms.any((p) => p.deviceId == id)) {
      return 'This device is already connected to another palm.';
    }
    return null;
  }

  void addPalm({
    required String id,
    required int age,
    required String type,
    required double latitude,
    required double longitude,
    required String deviceNumber,
    required double sensorLatitude,
    required double sensorLongitude,
  }) {
    final now = DateTime.now();
    MockData.addPalm(PalmData(
      id: id,
      farmId: activeFarmId ?? MockData.selectedFarmId,
      name: id,
      status: PalmStatus.healthy,
      // No readings yet: the sensor will send them.
      temperature: 0,
      humidity: 0,
      location: '$latitude, $longitude',
      sensorLocation: '$sensorLatitude, $sensorLongitude',
      updatedAt: now,
      deviceId: deviceIdFromNumber(deviceNumber),
      deviceOnline: true,
      lastSeen: now,
      age: age,
      type: type,
    ));
  }

  void updatePalm(
    PalmData palm, {
    required String id,
    required int age,
    required String type,
    required String status,
    required String notes,
  }) {
    MockData.updatePalm(
      palm,
      id: id.trim(),
      age: age,
      type: type,
      status: statusFromLabel(status),
      notes: notes.trim(),
    );
  }

  /// Deletes the palm with its alerts and treatment history.
  void deletePalm(PalmData palm) => MockData.deletePalm(palm);
}

/// Shared form checks, so every page shows the same messages.
class PalmValidators {
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  /// Palm ID number (the part after "P"): required, 3 digits, not 000.
  static String? palmId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'This field is required.';
    if (!RegExp(r'^\d+$').hasMatch(v)) return 'Palm ID must be a number.';
    if (!RegExp(r'^\d{3}$').hasMatch(v) || v == '000') {
      return 'Palm ID must be 3 digits (e.g. 008).';
    }
    return null;
  }

  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'Age must be a number.';
    }
    return null;
  }

  static String? latitude(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    final n = double.tryParse(value.trim());
    if (n == null) return 'Latitude must be a number.';
    if (n < -90 || n > 90) return 'Latitude must be between -90 and 90.';
    return null;
  }

  static String? longitude(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    final n = double.tryParse(value.trim());
    if (n == null) return 'Longitude must be a number.';
    if (n < -180 || n > 180) return 'Longitude must be between -180 and 180.';
    return null;
  }
}
