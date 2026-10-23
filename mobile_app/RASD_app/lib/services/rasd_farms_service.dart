import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FarmRecord {
  final String id;
  final String name;
  final String description;
  final String image;
  final double latitude;
  final double longitude;
  final int totalPalms;

  const FarmRecord({required this.id, required this.name, required this.description,
    required this.image, required this.latitude, required this.longitude,
    required this.totalPalms});

  factory FarmRecord.fromEntry(String id, Object? value) {
    final d = Map<String, dynamic>.from(value as Map);
    return FarmRecord(
      id: id,
      name: (d['farmName'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      image: (d['farmImage'] ?? '').toString(),
      latitude: (d['latitude'] as num).toDouble(),
      longitude: (d['longitude'] as num).toDouble(),
      totalPalms: (d['totalPalms'] as num).toInt(),
    );
  }
}

class RasdFarmsService {
  static final _database = FirebaseDatabase.instance;
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  static Stream<List<FarmRecord>> watchMyFarms() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in first.');
    return _database.ref('farms').orderByChild('ownerId').equalTo(uid).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return <FarmRecord>[];
      final data = Map<String, dynamic>.from(value as Map);
      return data.entries.map((e) => FarmRecord.fromEntry(e.key, e.value)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  static Future<String> createFarm({required String name, required String description,
    required int totalPalms, required double latitude, required double longitude}) async {
    final result = await _functions.httpsCallable('createFarm').call(<String, dynamic>{
      'farmName': name,
      'description': description,
      'totalPalms': totalPalms,
      'latitude': latitude,
      'longitude': longitude,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['farmId'].toString();
  }


  static Future<String> uploadFarmImage({
    required String farmId,
    required String imagePath,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError('Please sign in first.');
    }

    final file = File(imagePath);

    if (!await file.exists()) {
      throw StateError('Selected image was not found.');
    }

    if (await file.length() >= 5 * 1024 * 1024) {
      throw StateError('Farm image must be smaller than 5 MB.');
    }

    final extension = imagePath.toLowerCase().split('.').last;

    if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      throw StateError('Please select a JPG, PNG or WebP image.');
    }

    final contentType = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
        ? 'image/webp'
        : 'image/jpeg';

    final reference = FirebaseStorage.instance
        .ref()
        .child('farmImages/$uid/$farmId.$extension');

    await reference.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );

    return reference.getDownloadURL();
  }

  static Future<void> updateFarmImage({
    required String farmId,
    required String imageUrl,
  }) async {
    await _functions.httpsCallable('updateFarm').call({
      'farmId': farmId,
      'changes': {
        'farmImage': imageUrl,
      },
    });
  }

}
