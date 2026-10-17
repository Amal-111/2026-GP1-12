import 'package:flutter/material.dart';

/// One palm tree in the farm.
class Palm {
  String id;
  int age;
  String type;
  String status;
  String notes;
  double latitude;
  double longitude;
  String deviceId;
  double sensorLatitude;
  double sensorLongitude;
  String updated;

  Palm({
    required this.id,
    required this.age,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.deviceId,
    required this.sensorLatitude,
    required this.sensorLongitude,
    this.status = 'Healthy',
    this.notes = '',
    this.updated = 'Just now',
  });
}

/// Keeps the farm's palms in memory and shares them between pages.
///
/// TODO: when the team adds a database (e.g. Firebase), replace the
/// lists below with database calls. The pages do not need to change.
class PalmStore extends ChangeNotifier {
  PalmStore._();
  static final PalmStore instance = PalmStore._();

  final List<Palm> _palms = [
    Palm(id: '0001', age: 12, type: 'Sukkari', status: 'Healthy',
        latitude: 24.7136, longitude: 46.6753, deviceId: 'RASD-00001',
        sensorLatitude: 24.7136, sensorLongitude: 46.6753,
        updated: '5 min ago'),
    Palm(id: '0002', age: 8, type: 'Khalas', status: 'Suspected',
        latitude: 24.7140, longitude: 46.6760, deviceId: 'RASD-00002',
        sensorLatitude: 24.7140, sensorLongitude: 46.6760,
        updated: '10 min ago'),
    Palm(id: '0003', age: 15, type: 'Ajwa', status: 'Monitoring',
        latitude: 24.7145, longitude: 46.6748, deviceId: 'RASD-00003',
        sensorLatitude: 24.7145, sensorLongitude: 46.6748,
        updated: '1 hour ago'),
  ];

  /// Sensors that exist in the system (sample data).
  /// TODO: replace with the real devices from the database.
  final Set<String> _registeredDevices = {
    for (int i = 1; i <= 20; i++) 'RASD-${i.toString().padLeft(5, '0')}',
  };

  static const List<String> palmTypes = [
    'Sukkari',
    'Khalas',
    'Ajwa',
    'Barhi',
    'Segae',
    'Medjool',
    'Other',
  ];

  static const List<String> statuses = [
    'Healthy',
    'Suspected',
    'Monitoring',
    'Treated',
  ];

  List<Palm> get palms => List.unmodifiable(_palms);

  /// Next palm ID, given automatically by the system
  /// (biggest existing number + 1, so it never repeats).
  String nextPalmId() {
    int maxId = 0;
    for (final palm in _palms) {
      final n = int.tryParse(palm.id) ?? 0;
      if (n > maxId) maxId = n;
    }
    return (maxId + 1).toString().padLeft(4, '0');
  }

  bool idExists(String id, {Palm? except}) {
    return _palms.any((p) => p.id == id.trim() && p != except);
  }

  /// Returns an error message, or null if the device can be used.
  /// Turns the number the user typed into the full sensor ID:
  /// "5" -> "RASD-00005".
  static String deviceIdFromNumber(String number) {
    final n = int.tryParse(number.trim()) ?? 0;
    return 'RASD-${n.toString().padLeft(5, '0')}';
  }

  static bool isDigits(String value) => RegExp(r'^\d+$').hasMatch(value.trim());

  /// [number] is what the user typed.
  String? checkDevice(String number) {
    if (number.trim().isEmpty) return 'Device ID is required.';
    if (!isDigits(number)) return 'Device ID must be a number.';
    final id = deviceIdFromNumber(number);
    if (!_registeredDevices.contains(id)) {
      return 'Device not found. Please check the device ID.';
    }
    if (_palms.any((p) => p.deviceId == id)) {
      return 'This device is already connected to another palm.';
    }
    return null;
  }

  void addPalm(Palm palm) {
    palm.deviceId = palm.deviceId.trim().toUpperCase();
    _palms.add(palm);
    notifyListeners();
  }

  void updatePalm(Palm palm, {
    required String id,
    required int age,
    required String type,
    required String status,
    required String notes,
  }) {
    palm
      ..id = id.trim()
      ..age = age
      ..type = type
      ..status = status
      ..notes = notes.trim()
      ..updated = 'Just now';
    notifyListeners();
  }

  /// Deletes the palm and everything related to it.
  /// TODO: when there is a database, also delete its care history and
  /// health records here.
  void deletePalm(Palm palm) {
    _palms.remove(palm);
    notifyListeners();
  }
}

/// Shared form checks, so every page shows the same messages.
class PalmValidators {
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  /// Palm ID rules: required, exactly 4 digits, not 0000.
  static String? palmId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'This field is required.';
    if (!RegExp(r'^\d+$').hasMatch(v)) {
      return 'Palm ID must be a number.';
    }
    if (!RegExp(r'^\d{4}$').hasMatch(v) || v == '0000') {
      return 'Palm ID must be 4 digits (e.g. 0007).';
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
