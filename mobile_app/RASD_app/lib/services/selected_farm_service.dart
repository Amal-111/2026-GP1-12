
import 'package:flutter/foundation.dart';

class SelectedFarmService {
  SelectedFarmService._();

  static final ValueNotifier<String?> selectedFarmId =
  ValueNotifier<String?>(null);

  static String get farmId {
    final id = selectedFarmId.value;

    if (id == null || id.isEmpty) {
      throw StateError('Please select a farm first.');
    }

    return id;
  }

  static void selectFarm(String farmId) {
    if (farmId.trim().isEmpty) {
      throw ArgumentError('Invalid farm ID.');
    }

    selectedFarmId.value = farmId;
  }

  static void clearSelection() {
    selectedFarmId.value = null;
  }
}
