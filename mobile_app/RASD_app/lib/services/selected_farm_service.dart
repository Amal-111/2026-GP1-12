// Remembers which farm the user is currently working on.

import 'package:flutter/foundation.dart';

/// Holds the currently selected farm.
class SelectedFarmService {
  SelectedFarmService._();

  static final ValueNotifier<String?> selectedFarmId =
  ValueNotifier<String?>(null);

  static String get farmId {
    final id = selectedFarmId.value;

    if (id == null || id.isEmpty) {
      throw StateError('Choose a farm first.');
    }

    return id;
  }

  /// Remembers the selected farm.
  static void selectFarm(String farmId) {
    if (farmId.trim().isEmpty) {
      throw ArgumentError('Invalid farm ID.');
    }

    selectedFarmId.value = farmId;
  }

  /// Forgets the selected farm.
  static void clearSelection() {
    selectedFarmId.value = null;
  }
}
