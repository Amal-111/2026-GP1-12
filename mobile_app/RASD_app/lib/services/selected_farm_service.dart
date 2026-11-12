// Remembers which farm the user is currently working on.

import 'package:flutter/foundation.dart';

import '../data/auth_store.dart';

/// Holds the currently selected farm.
class SelectedFarmService {
  SelectedFarmService._();

  static final ValueNotifier<String?> selectedFarmId =
  ValueNotifier<String?>(null);

  /// Returns the selected farm ID or reports a missing selection.
  static String get farmId {
    final id = selectedFarmId.value;

    if (id == null || id.isEmpty) {
      throw StateError((AuthStore.arabic.value ? 'اختر مزرعة أولًا.' : 'Choose a farm first.'));
    }

    return id;
  }

  /// Remembers the selected farm.
  static void selectFarm(String farmId) {
    if (farmId.trim().isEmpty) {
      throw ArgumentError((AuthStore.arabic.value ? 'معرّف المزرعة غير صالح.' : 'Invalid farm ID.'));
    }

    selectedFarmId.value = farmId;
  }

  /// Forgets the selected farm.
  static void clearSelection() {
    selectedFarmId.value = null;
  }
}
