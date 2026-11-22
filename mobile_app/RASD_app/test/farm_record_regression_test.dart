import 'package:flutter_test/flutter_test.dart';
import 'package:rasd_app/services/rasd_farms_service.dart';

void main() {
  const capacity = 4;
  for (final count in [0, 1, 2, capacity]) {
    test('counts $count registered palms separately from capacity', () {
      final farm = FarmRecord.fromEntry('existing-id', {
        'farmName': 'Test Farm',
        'latitude': 24,
        'longitude': 46,
        'totalPalms': capacity,
        if (count > 0)
          'palms': {for (var i = 0; i < count; i++) 'P00$i': {'age': 10}},
      });
      expect(farm.registeredPalmCount, count);
      expect(farm.totalPalms, capacity);
      expect(farm.id, 'existing-id');
    });
  }
}
