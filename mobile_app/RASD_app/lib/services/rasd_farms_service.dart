// Farm creation and farm photo upload (Firebase Storage + Cloud Functions).
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';

import '../data/auth_store.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// A farm record as read from the database.
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

  /// Converts one database entry into a farm record.
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

/// Farm creation and photo upload.
class RasdFarmsService {
  static final _database = FirebaseDatabase.instance;
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Watches the farms owned by the signed-in account.
  static Stream<List<FarmRecord>> watchMyFarms() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError((AuthStore.arabic.value ? 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.' : 'Your session has ended. Please log in again.'));
    return _database.ref('farms').orderByChild('ownerId').equalTo(uid).onValue.map((event) {
      final value = event.snapshot.value;
      if (value == null) return <FarmRecord>[];
      final data = Map<String, dynamic>.from(value as Map);
      return data.entries.map((e) => FarmRecord.fromEntry(e.key, e.value)).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  /// Creates a farm through the Cloud Function and returns its id.
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


  /// Uploads the farm photo to Firebase Storage and returns its URL.
  static Future<String> uploadFarmImage({
    required String farmId,
    required String imagePath,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      throw StateError((AuthStore.arabic.value ? 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.' : 'Your session has ended. Please log in again.'));
    }

    final file = File(imagePath);

    if (!await file.exists()) {
      throw StateError((AuthStore.arabic.value ? 'لم يتم العثور على الصورة. اختر الصورة مرة أخرى.' : 'The photo could not be found. Choose it again.'));
    }

    if (await file.length() >= 5 * 1024 * 1024) {
      throw StateError((AuthStore.arabic.value ? 'يجب أن يكون حجم الصورة أقل من 5 ميجابايت.' : 'The photo must be smaller than 5 MB.'));
    }

    final extension = imagePath.toLowerCase().split('.').last;

    if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      throw StateError((AuthStore.arabic.value ? 'اختر صورة بصيغة JPG أو PNG أو WebP.' : 'Choose a JPG, PNG or WebP photo.'));
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

  /// Saves the photo URL on the farm (empty text removes the photo).
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


  /// Deletes a replaced farm photo only when the Storage path is valid.
  static Future<void> deletePreviousFarmImage({
    required String farmId,
    required String previousImageUrl,
    required String newImageUrl,
  }) async {
    if (previousImageUrl.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError((AuthStore.arabic.value ? 'انتهت جلسة تسجيل الدخول.' : 'Your session has ended.'));
    }

    // Extract the old file path from its Firebase Storage URL.
    final uri = Uri.parse(previousImageUrl);
    final segments = uri.pathSegments;
    final objectIndex = segments.indexOf('o');

    if (objectIndex == -1 || objectIndex + 1 >= segments.length) {
      throw StateError((AuthStore.arabic.value ? 'رابط صورة المزرعة السابقة غير صالح.' : 'Invalid previous farm image URL.'));
    }

    final oldPath = segments[objectIndex + 1];
    final validPrefix = 'farmImages/$uid/$farmId.';

    // Never delete an unrelated Storage file.
    if (!oldPath.startsWith(validPrefix) ||
        !['jpg', 'jpeg', 'png', 'webp']
            .contains(oldPath.substring(validPrefix.length))) {
      throw StateError((AuthStore.arabic.value ? 'مسار صورة المزرعة غير متوقع.' : 'Unexpected farm image path.'));
    }

    final oldReference = FirebaseStorage.instance.ref().child(oldPath);

    // If the new image has the same path, the upload
    // has already replaced the old file.
    if (newImageUrl.isNotEmpty) {
      final newSegments = Uri.parse(newImageUrl).pathSegments;
      final newIndex = newSegments.indexOf('o');

      if (newIndex == -1 || newIndex + 1 >= newSegments.length) {
        throw StateError((AuthStore.arabic.value ? 'رابط صورة المزرعة الجديدة غير صالح.' : 'Invalid new farm image URL.'));
      }

      if (oldPath == newSegments[newIndex + 1]) return;
    }

    try {
      await oldReference.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

}
