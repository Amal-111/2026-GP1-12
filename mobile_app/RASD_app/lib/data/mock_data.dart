// Data models (palms, farms, farmers, alerts) and in-memory sample data shared by older screens.
import 'package:flutter/foundation.dart';

/// Health status of a palm.
enum PalmStatus { healthy, suspected, underMonitoring }
/// Kinds of alerts.
enum AlertType { suspected, monitoring, deviceOffline }
/// The two kinds of users.
enum UserRole { farmer, farmOwner }

/// A signed-in user.
class RasdUser {
  final String name;
  final UserRole role;
  final String? farmId;
  const RasdUser(this.name, this.role, {this.farmId});
}

/// A farmer.
class FarmerData {
  final String id;
  String name;
  String email;
  String phoneNumber;
  String? farmId;

  FarmerData({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber = '',
    this.farmId,
  });
}

/// A farm.
class RasdFarm {
  final String id;
  String name;
  String location;
  String imagePath;
  String description;
  double? latitude;
  double? longitude;
  int palmCount;
  int farmerCount;

  RasdFarm(
      this.id,
      this.name, {
        required this.location,
        required this.imagePath,
        this.description = '',
        this.latitude,
        this.longitude,
        required this.palmCount,
        required this.farmerCount,
      });
}

/// A palm.
class PalmData {
  // id and name can change from the Edit Palm page.
  String id;
  final String farmId;
  String name;
  PalmStatus status;
  final double temperature;
  final double humidity;
  final String location;
  final DateTime updatedAt;
  final String deviceId;
  bool deviceOnline;
  DateTime lastSeen;

  // Added for the Manage Palms pages (add / edit palm).
  int? age;
  String? type;
  String notes;
  String sensorLocation;

  PalmData({required this.id, required this.farmId, required this.name, required this.status,
    required this.temperature, required this.humidity, required this.location,
    required this.updatedAt, required this.deviceId, required this.deviceOnline, required this.lastSeen,
    this.age, this.type, this.notes = '', String? sensorLocation})
      : sensorLocation = sensorLocation ?? location;
}

/// An alert.
class AlertData {
  final String id;
  final String farmId;
  String palmId; // changes if the palm ID is edited
  final AlertType type;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;
  bool isCurrent;
  AlertData({required this.id, required this.farmId, required this.palmId,
    required this.type, required this.title, required this.message, required this.createdAt,
    this.isRead = false, this.isCurrent = true});
}

/// A treatment record.
class TreatmentEntry {
  String palmId; // changes if the palm ID is edited
  final DateTime date;
  final String method;
  final String notes;
  final DateTime createdAt;
  TreatmentEntry({required this.palmId, required this.date, required this.method,
    required this.notes, required this.createdAt});
}

/// Sample data and helpers.
class MockData {
  static final List<TreatmentEntry> treatments = [];
  /// Treatments recorded for a palm.
  static List<TreatmentEntry> treatmentsForPalm(String palmId) =>
      treatments.where((entry) => entry.palmId == palmId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Monitoring events of a palm.
  static List<AlertData> monitoringEventsForPalm(String palmId) =>
      alerts.where((alert) => alert.palmId == palmId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Saves a treatment record for a palm.
  static void saveTreatment({required PalmData palm, required DateTime date,
    required String method, required String notes}) {
    treatments.add(TreatmentEntry(palmId: palm.id, date: date,
      method: method, notes: notes, createdAt: DateTime.now()));
    recordTreatment(palm);
    notifyChange();
  }

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  /// Tells listeners that the data changed.
  static void notifyChange() => changes.value++;

  /// Sample farmer account.
  static const farmer = RasdUser('Ahmed', UserRole.farmer, farmId: 'F001');
  /// Sample owner account.
  static const owner = RasdUser('Sara', UserRole.farmOwner);
  /// The user currently using the app.
  static RasdUser currentUser = farmer; // owner;
  static final List<FarmerData> farmers = [
    FarmerData(
      id: 'FR001',
      name: 'Ahmed Ali',
      email: 'ahmed@rasd.com',
      phoneNumber: '0501234567',
      farmId: 'F001',
    ),
    FarmerData(
      id: 'FR002',
      name: 'Salem Khalid',
      email: 'salem@rasd.com',
      phoneNumber: '',
      farmId: 'F001',
    ),
    FarmerData(
      id: 'FR003',
      name: 'Noura Fahad',
      email: 'noura@rasd.com',
      phoneNumber: '',
      farmId: 'F002',
    ),
    FarmerData(
      id: 'FR004',
      name: 'Omar Ibrahim',
      email: 'omar@rasd.com',
      phoneNumber: '',
      farmId: null,
    ),
  ];

  /// Farmers of a farm.
  static List<FarmerData> farmersForFarm([String? farmId]) =>
      farmers
          .where((farmer) => farmer.farmId == (farmId ?? selectedFarmId))
          .toList();

  /// Removes a farmer.
  static void deleteFarmer(FarmerData farmer) {
    farmers.remove(farmer);
    notifyChange();
  }

  /// Updates a farmer.
  static void updateFarmer(
      FarmerData farmer, {
        required String name,
        required String email,
        required String phoneNumber,
      }) {
    farmer
      ..name = name
      ..email = email
      ..phoneNumber = phoneNumber;

    notifyChange();
  }
  /// Assigns a farmer to a farm.
  static void assignFarmerToFarm(FarmerData farmer, String farmId) {
    farmer.farmId = farmId;
    notifyChange();
  }

  /// Updates a farm.
  static void updateFarm(
      RasdFarm farm, {
        required String name,
        required String description,
        required String location,
        required String imagePath,
        required double? latitude,
        required double? longitude,
      }) {
    farm
      ..name = name
      ..description = description
      ..location = location
      ..imagePath = imagePath
      ..latitude = latitude
      ..longitude = longitude;

    notifyChange();
  }

  /// Deletes a farm.
  static void deleteFarm(RasdFarm farm) {
    farms.remove(farm);

    palms.removeWhere((palm) => palm.farmId == farm.id);
    farmers.removeWhere((farmer) => farmer.farmId == farm.id);
    alerts.removeWhere((alert) => alert.farmId == farm.id);

    notifyChange();
  }

  static final List<RasdFarm> farms = [
    RasdFarm(
      'F001',
      'Al Nakheel Farm',
      location: '24.7136, 46.6753',
      imagePath: 'assets/images/farm_1.png',
      description: '',
      latitude: 24.7136,
      longitude: 46.6753,
      palmCount: 5,
      farmerCount: 2,
    ),
    RasdFarm(
      'F002',
      'Al Waha Farm',
      location: '24.7200, 46.6800',
      imagePath: 'assets/images/farm_2.png',
      description: '',
      latitude: 24.7200,
      longitude: 46.6800,
      palmCount: 2,
      farmerCount: 1,
    ),
  ];
  /// Id of the farm currently selected.
  static String selectedFarmId = 'F001';

  static RasdFarm get selectedFarm =>
      farms.firstWhere((f) => f.id == selectedFarmId);

  static DateTime get lastUpdated =>
      palmsForFarm().isEmpty ? DateTime.now() :
      palmsForFarm().map((p) => p.updatedAt).reduce((a, b) =>
      a.isAfter(b)
          ? a
          : b);

  /// Generates the next farm id.
  static String nextFarmId() {
    int maxNumber = 0;

    for (final farm in farms) {
      final number =
          int.tryParse(farm.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      if (number > maxNumber) {
        maxNumber = number;
      }
    }

    return 'F${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  /// Adds a farm.
  static void addFarm(RasdFarm farm) {
    farms.add(farm);
    notifyChange();
  }

  static final List<PalmData> palms = [
    PalmData(id: 'P001',
        age: 12,
        type: 'Sukkari',
        farmId: 'F001',
        name: 'P001',
        status: PalmStatus.suspected,
        temperature: 32,
        humidity: 45,
        location: '24.7136, 46.6753',
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        deviceId: 'D001',
        deviceOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 2))),
    PalmData(id: 'P002',
        age: 8,
        type: 'Khalas',
        farmId: 'F001',
        name: 'P002',
        status: PalmStatus.healthy,
        temperature: 31,
        humidity: 43,
        location: '24.7140, 46.6758',
        updatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
        deviceId: 'D002',
        deviceOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5))),
    PalmData(id: 'P003',
        age: 15,
        type: 'Ajwa',
        farmId: 'F001',
        name: 'P003',
        status: PalmStatus.suspected,
        temperature: 31,
        humidity: 48,
        location: '24.7136, 46.6753',
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        deviceId: 'D003',
        deviceOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 4))),
    PalmData(id: 'P004',
        age: 6,
        type: 'Barhi',
        farmId: 'F001',
        name: 'P004',
        status: PalmStatus.underMonitoring,
        temperature: 30,
        humidity: 44,
        location: '24.7138, 46.6760',
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
        deviceId: 'D004',
        deviceOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 6))),
    PalmData(id: 'P005',
        age: 10,
        type: 'Sukkari',
        farmId: 'F001',
        name: 'P005',
        status: PalmStatus.underMonitoring,
        temperature: 33,
        humidity: 42,
        location: '24.7142, 46.6763',
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        deviceId: 'D005',
        deviceOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 3))),
    PalmData(id: 'P006',
        age: 9,
        type: 'Segae',
        farmId: 'F002',
        name: 'P006',
        status: PalmStatus.healthy,
        temperature: 29,
        humidity: 50,
        location: '24.7200, 46.6800',
        updatedAt: DateTime.now().subtract(const Duration(minutes: 7)),
        deviceId: 'D006',
        deviceOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(days: 1))),
    PalmData(id: 'P007',
        age: 14,
        type: 'Khalas',
        farmId: 'F002',
        name: 'P007',
        status: PalmStatus.suspected,
        temperature: 32,
        humidity: 47,
        location: '24.7210, 46.6810',
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
        deviceId: 'D007',
        deviceOnline: true,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 4))),
  ];

  static final List<AlertData> alerts = [
    AlertData(id: 'A001',
        farmId: 'F001',
        palmId: 'P003',
        type: AlertType.suspected,
        title: 'Possible Pest Detected',
        message: 'Unusual activity was detected. Please inspect this palm tree.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    AlertData(id: 'A002',
        farmId: 'F001',
        palmId: 'P005',
        type: AlertType.monitoring,
        title: 'Under Monitoring',
        message: 'This palm is currently under monitoring.',
        createdAt: DateTime.now().subtract(const Duration(days: 1))),
    AlertData(id: 'A003',
        farmId: 'F001',
        palmId: 'P004',
        type: AlertType.deviceOffline,
        title: 'Sensor Offline',
        message: 'The monitoring device stopped reporting data.',
        createdAt: DateTime.now().subtract(const Duration(days: 2))),
    AlertData(id: 'A004',
        farmId: 'F001',
        palmId: 'P003',
        type: AlertType.suspected,
        title: 'Previous Detection',
        message: 'Earlier suspected activity was detected.',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        isRead: true,
        isCurrent: false),
    AlertData(id: 'A005',
        farmId: 'F002',
        palmId: 'P007',
        type: AlertType.suspected,
        title: 'Possible Pest Detected',
        message: 'Please inspect this palm.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5))),
  ];

  // ---------------------------------------------------------------
  // Manage Palms (add / edit / delete) - used by lib/manage_palms
  // ---------------------------------------------------------------

  /// Sensors that exist in the system (sample data).
  static final List<String> devices = [
    for (int i = 1; i <= 20; i++) 'D${i.toString().padLeft(3, '0')}',
  ];

  /// Next palm ID given by the system: biggest number + 1 (P008, P009...).
  static String nextPalmId() {
    int maxNumber = 0;
    for (final palm in palms) {
      final n = int.tryParse(palm.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > maxNumber) maxNumber = n;
    }
    return 'P${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  /// Adds a palm.
  static void addPalm(PalmData palm) {
    palms.add(palm);
    notifyChange();
  }

  /// Saves the edited information. If the ID changed, the palm's alerts
  /// and treatments move to the new ID too.
  static void updatePalm(PalmData palm, {required String id, required int age,
    required String type, required PalmStatus status, required String notes}) {
    final oldId = palm.id;
    if (oldId != id) {
      for (final alert in alerts) {
        if (alert.palmId == oldId) alert.palmId = id;
      }
      for (final entry in treatments) {
        if (entry.palmId == oldId) entry.palmId = id;
      }
    }
    palm
      ..id = id
      ..name = id
      ..age = age
      ..type = type
      ..status = status
      ..notes = notes;
    notifyChange();
  }

  /// Deletes the palm and everything related to it (alerts, treatments).
  static void deletePalm(PalmData palm) {
    palms.remove(palm);
    alerts.removeWhere((a) => a.palmId == palm.id);
    treatments.removeWhere((t) => t.palmId == palm.id);
    notifyChange();
  }

  /// Palms of a farm.
  static List<PalmData> palmsForFarm([String? farmId]) =>
      palms.where((p) => p.farmId == (farmId ?? selectedFarmId)).toList();

  /// Finds a palm by id.
  static PalmData? palmById(String id) {
    for (final p in palms) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Counts palms with a status.
  static int count(PalmStatus status) =>
      palmsForFarm()
          .where((p) => p.status == status)
          .length;

  /// Palms whose sensors are offline.
  static List<PalmData> offlinePalms() =>
      palmsForFarm().where((p) => !p.deviceOnline).toList();

  /// Alerts of the selected farm.
  static List<AlertData> alertsForFarm({bool? current}) {
    final result = alerts
        .where((a) =>
    a.farmId == selectedFarmId && (current == null || a.isCurrent == current))
        .toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Most recent alerts.
  static List<AlertData> recentAlerts() {
    return alertsForFarm(current: true).take(3).toList();
  }
  /// Marks an alert as read.
  static void markRead(AlertData alert) => alert.isRead = true;

  /// Records a treatment for a palm.
  static void recordTreatment(PalmData palm) {
    if (palm.status == PalmStatus.suspected) {
      palm.status = PalmStatus.underMonitoring;
      // Close active suspected alerts and create a monitoring alert.
      for (final alert in alerts) {
        if (alert.palmId == palm.id && alert.type == AlertType.suspected && alert.isCurrent) {
          alert.isCurrent = false;
        }
      }
      alerts.add(AlertData(
        id: 'MON_${palm.id}_${DateTime.now().microsecondsSinceEpoch}',
        farmId: palm.farmId,
        palmId: palm.id,
        type: AlertType.monitoring,
        title: 'Under Monitoring',
        message: 'Treatment recorded. This palm is now under monitoring.',
        createdAt: DateTime.now(),
      ));
      notifyChange();
    }
  }
}

String palmStatusLabel(PalmStatus status) => switch(status) {
  PalmStatus.healthy => 'Healthy', PalmStatus.suspected => 'Suspected',
 PalmStatus.underMonitoring => 'Under Monitoring',
};

String timeAgo(DateTime date) {
  final d = DateTime.now().difference(date);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hours ago';
  return '${d.inDays} days ago';
}
