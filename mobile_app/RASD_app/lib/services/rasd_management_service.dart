import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../data/mock_data.dart';
import 'selected_farm_service.dart';

/// Firebase access for management screens. All writes go through callable functions.
class RasdManagementService {
  static final _db = FirebaseDatabase.instance;
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  static String get farmId => SelectedFarmService.farmId;

  static Future<void> _call(String name, Map<String, dynamic> data) async {

    debugPrint('Rasd Function: $name');
    debugPrint('Rasd Payload: $data');

      await _functions.httpsCallable(name).call(data);

  }

  static Stream<RasdFarm?> watchFarm(String id) =>
      _db.ref('farms/$id').onValue.map((event) {
        if (!event.snapshot.exists) return null;
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final latitude = (data['latitude'] as num).toDouble();
        final longitude = (data['longitude'] as num).toDouble();
        return RasdFarm(id, (data['farmName'] ?? '').toString(),
          location: '$latitude, $longitude', imagePath: (data['farmImage'] ?? '').toString(),
          description: (data['description'] ?? '').toString(),
          latitude: latitude, longitude: longitude,
          palmCount: (data['totalPalms'] as num).toInt(), farmerCount: 0);
      });

  static Future<void> updateFarm({required String name, required String description,
    required double latitude, required double longitude}) => _call('updateFarm', {
      'farmId': farmId,
      'changes': {'farmName': name, 'description': description,
        'latitude': latitude, 'longitude': longitude},
    });

  static Future<void> deleteFarm() => _call('deleteFarm', {'farmId': farmId});

  static Stream<List<PalmData>> watchPalms() =>
      _db.ref('palms/$farmId').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return <PalmData>[];
        final result = <PalmData>[];
        for (final entry in value.entries) {
          final d = Map<String, dynamic>.from(entry.value as Map);
          final lat = (d['latitude'] as num?)?.toDouble() ?? 0;
          final lng = (d['longitude'] as num?)?.toDouble() ?? 0;
          final status = switch (d['healthStatus']) {
            'Suspected' => PalmStatus.suspected,
            'UnderMonitoring' => PalmStatus.underMonitoring,
            _ => PalmStatus.healthy,
          };
          result.add(PalmData(id: entry.key.toString(), farmId: farmId,
            name: entry.key.toString(), status: status,
            temperature: 0, humidity: 0, location: '$lat, $lng',
            updatedAt: DateTime.now(), deviceId: (d['deviceId'] ?? '').toString(),
            deviceOnline: false, lastSeen: DateTime.now(),
            age: (d['age'] as num?)?.toInt(), type: d['palmType']?.toString(),
            notes: (d['notes'] ?? '').toString()));
        }
        result.sort((a, b) => a.id.compareTo(b.id));
        return result;
      });

  // Resolve the authenticated owner's real farm instead of the mock F001 ID.
  // When multiple farms exist, require the UI to select a real farm first.

  static Future<String> _farmIdForNewPalm() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('Please sign in before adding a palm.');
    }

    // Read the real user role and farm assignment from Firebase.
    final userSnapshot = await _db.ref('users/$uid').get();

    if (!userSnapshot.exists || userSnapshot.value is! Map) {
      throw StateError('User profile not found.');
    }

    final user = Map<String, dynamic>.from(
      userSnapshot.value as Map,
    );

    final role = user['role']?.toString();

    String resolvedFarmId;

    if (role == 'Farmer') {
      // Farmers can add palms only to their assigned farm.
      final assignedFarmId = user['farmId']?.toString();

      if (assignedFarmId == null || assignedFarmId.isEmpty) {
        throw StateError(
          'You are not assigned to a farm yet.',
        );
      }

      resolvedFarmId = assignedFarmId;
    } else if (role == 'FarmOwner') {
      // Owners add palms to the farm they selected.
      final selectedId =
          SelectedFarmService.selectedFarmId.value;

      final farmsSnapshot = await _db
          .ref('farms')
          .orderByChild('ownerId')
          .equalTo(uid)
          .get();

      if (!farmsSnapshot.exists ||
          farmsSnapshot.value is! Map) {
        throw StateError(
          'No farms found for this account.',
        );
      }

      final farmIds = (farmsSnapshot.value as Map)
          .keys
          .map((key) => key.toString())
          .toList();

      if (selectedId != null &&
          farmIds.contains(selectedId)) {
        resolvedFarmId = selectedId;
      } else if (farmIds.length == 1) {
        resolvedFarmId = farmIds.single;
      } else {
        throw StateError(
          'Please select a farm before adding a palm.',
        );
      }
    } else {
      throw StateError(
        'Your account is not authorized to add palms.',
      );
    }

    // Verify that the farm still exists and is active.
    final farmSnapshot = await _db
        .ref('farms/$resolvedFarmId')
        .get();

    if (!farmSnapshot.exists ||
        farmSnapshot.value is! Map) {
      throw StateError('Farm not found.');
    }

    final farm = Map<String, dynamic>.from(
      farmSnapshot.value as Map,
    );

    if (farm['deleting'] == true) {
      throw StateError(
        'This farm is currently being deleted.',
      );
    }

    return resolvedFarmId;
  }


  static Future<void> addPalm({required int age, required String type,
    required double latitude, required double longitude, required String deviceId}) async {
    final realFarmId = await _farmIdForNewPalm();
    debugPrint('RASD REAL FARM ID: $realFarmId');
    debugPrint('RASD DATABASE URL: ${FirebaseDatabase.instance.databaseURL}');
    await _call('addPalm', {
      'farmId': realFarmId, 'deviceId': deviceId,
      'palm': {'age': age, 'palmType': type, 'latitude': latitude, 'longitude': longitude},
    });
  }

  static Future<void> updatePalm(PalmData palm, {required int age,
    required String type}) => _call('updatePalm', {
      'farmId': farmId, 'palmId': palm.id,
    'changes': {
      'age': age,
      'palmType': type,
    },
    });

  static Future<void> deletePalm(PalmData palm) => _call('deletePalm', {
    'farmId': farmId, 'palmId': palm.id,
  });

  static Stream<List<FarmerData>> watchFarmers() =>
      _db.ref('users').orderByChild('farmId').equalTo(farmId).onValue.map((event) {
        if (event.snapshot.value is! Map) return <FarmerData>[];
        final result = <FarmerData>[];
        for (final entry in (event.snapshot.value as Map).entries) {
          final d = Map<String, dynamic>.from(entry.value as Map);
          if (d['role'] != 'Farmer') continue;
          result.add(FarmerData(id: entry.key.toString(),
            name: (d['fullName'] ?? '').toString(),
            email: (d['email'] ?? '').toString(),
            phoneNumber: (d['phoneNumber'] ?? '').toString(), farmId: farmId));
        }
        return result;
      });

  static Future<void> inviteFarmer(String email) => _call('sendInvitation', {
    'farmId': farmId, 'email': email.trim(),
  });

  static Future<void> removeFarmer(String farmerId) => _call('removeFarmer', {
    'farmId': farmId, 'farmerId': farmerId,
  });

  static Stream<List<Map<String, dynamic>>> watchInvitations() =>
      _db.ref('farmInvitations').orderByChild('farmId').equalTo(farmId).onValue.map((event) {
        if (event.snapshot.value is! Map) return <Map<String, dynamic>>[];
        return (event.snapshot.value as Map).entries.map((entry) {
          final d = Map<String, dynamic>.from(entry.value as Map);
          return <String, dynamic>{'id': entry.key.toString(), ...d};
        }).toList();
      });

  static Future<void> cancelInvitation(String id) =>
      _call('cancelInvitation', {'invitationId': id});

  static Stream<List<Map<String, dynamic>>> watchMyInvitations() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db.ref('farmInvitations').orderByChild('farmerId').equalTo(uid).onValue.map((event) {
      if (event.snapshot.value is! Map) return <Map<String, dynamic>>[];
      return (event.snapshot.value as Map).entries.map((entry) {
        final d = Map<String, dynamic>.from(entry.value as Map);
        return <String, dynamic>{'id': entry.key.toString(), ...d};
      }).toList();
    });
  }

  static Future<void> acceptInvitation(String id) =>
      _call('acceptInvitation', {'invitationId': id});
  static Future<void> rejectInvitation(String id) =>
      _call('rejectInvitation', {'invitationId': id});



  static Future<String> getFarmerEmail(String farmerId) async {
    final snapshot = await _db.ref('users/$farmerId').get();

    if (!snapshot.exists || snapshot.value is! Map) {
      return 'Unknown Farmer';
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return (data['email'] ?? 'Unknown Farmer').toString();
  }

  static Future<Map<String, String>> getInvitationFarmInfo(
      String farmId) async {
    final farmSnapshot = await _db.ref('farms/$farmId').get();

    if (!farmSnapshot.exists || farmSnapshot.value is! Map) {
      return {
        'farmName': 'Unknown Farm',
        'ownerName': 'Unknown Owner',
      };
    }

    final farm = Map<String, dynamic>.from(
      farmSnapshot.value as Map,
    );

    final ownerId = (farm['ownerId'] ?? '').toString();

    String ownerName = 'Unknown Owner';

    if (ownerId.isNotEmpty) {
      final ownerSnapshot = await _db.ref('users/$ownerId').get();

      if (ownerSnapshot.exists && ownerSnapshot.value is Map) {
        final owner = Map<String, dynamic>.from(
          ownerSnapshot.value as Map,
        );
        ownerName = (owner['fullName'] ?? 'Unknown Owner').toString();
      }
    }

    return {
      'farmName': (farm['farmName'] ?? 'Unknown Farm').toString(),
      'ownerName': ownerName,
    };
  }


  static Future<Map<String, String>> getInvitationDetails(
      String invitationId,
      ) async {
    final result = await _functions
        .httpsCallable('getInvitationDetails')
        .call({'invitationId': invitationId});

    final data = Map<String, dynamic>.from(result.data as Map);

    return {
      'farmName': (data['farmName'] ?? 'Unknown Farm').toString(),
      'ownerName': (data['ownerName'] ?? 'Unknown Owner').toString(),
      'farmerEmail': (data['farmerEmail'] ?? 'Unknown Farmer').toString(),
    };
  }


}

