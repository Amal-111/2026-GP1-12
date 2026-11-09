// Firebase Authentication helpers: sign up, log in, profile, change password and log out.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../data/auth_store.dart';
import '../data/mock_data.dart';
import 'rasd_errors.dart';

/// Firebase-backed identity. Legacy AuthStore remains only as a temporary
/// adapter for pages that still read MockData.
class RasdAuthService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFunctions functions =
  FirebaseFunctions.instanceFor(region: 'us-central1');
  static final FirebaseDatabase database = FirebaseDatabase.instance;

  /// Creates the Firebase account and sends the verification email.
  static Future<void> signUp({required String name, required String email,
    required String phone, required String password, required UserRole role}) async {
    final result = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await result.user!.updateDisplayName(name.trim());
    await result.user!.sendEmailVerification();
    // Registration is completed on the next login after email verification.
    // No role/profile is written directly from the client.
  }

  /// Saves the user profile after the email is verified.
  static Future<void> completeRegistration({required String name,
    required String phone, required UserRole role}) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Log in first, then try again.');
    await user.reload();
    if (!(auth.currentUser?.emailVerified ?? false)) {
      throw StateError('Your email is not verified yet. Open the verification link we sent you, then tap Continue.');
    }
    await functions.httpsCallable('registerProfile').call({
      'fullName': name.trim(), 'phoneNumber': phone.trim(),
      'role': role == UserRole.farmOwner ? 'FarmOwner' : 'Farmer',
      'preferredLanguage': 'en',
    });
    await loadProfile();
  }

  /// True when the signed-in user already has a saved profile.
  static Future<bool> hasProfile() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return false;
    final snapshot = await database.ref('users/$uid').get();
    return snapshot.exists;
  }

  /// Signs in with email and password.
  static Future<void> logIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    await auth.currentUser!.reload();
    if (!(auth.currentUser?.emailVerified ?? false)) {
      await auth.signOut();
      throw StateError('Open the verification email we sent you, then log in again.');
    }
    if (!await hasProfile()) {
      throw StateError('Your email is verified, but your profile is not complete. Close the app, open it again and finish signing up.');
    }
    await loadProfile();
  }

  /// Loads the saved profile into the app.
  static Future<void> loadProfile() async {
    final user = auth.currentUser;
    if (user == null) return;
    final snapshot = await database.ref('users/${user.uid}').get();
    if (snapshot.value is! Map) throw StateError('We could not find your profile. Log out and log in again.');
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final role = data['role'] == 'Farmer' ? UserRole.farmer : UserRole.farmOwner;
    final account = Account(id: user.uid, role: role,
      email: user.email ?? '', password: '',
      ownerName: (data['fullName'] ?? '').toString(),
      ownerPhone: (data['phoneNumber'] ?? '').toString());
    AuthStore.setFirebaseAccount(account, farmId: data['farmId']?.toString());
    AuthStore.notificationsOn.value = data['notificationsEnabled'] != false;
    AuthStore.arabic.value = data['preferredLanguage'] == 'ar';
  }

  /// Updates name and phone.
  static Future<void> updateProfile({required String name, required String phone}) async {
    await functions.httpsCallable('updateProfile').call({'fullName': name.trim(), 'phoneNumber': phone.trim()});
    await loadProfile();
  }

  /// Re-authenticates with the old password, then sets the new one.
  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final user = auth.currentUser!;
    final credential = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Signs the user out and clears local data.
  static Future<void> logOut() async {
    await auth.signOut();
    AuthStore.logOut();
  }

  /// Message to show for an error. Kept here so older screens still work;
  /// the wording itself lives in [RasdErrors].
  static String message(Object error) => RasdErrors.message(error);

  /// Name of the farm this farmer is assigned to.
  static Future<String> getMyAssignedFarmName() async {
    final result = await functions
        .httpsCallable('getMyAssignedFarm')
        .call();

    final data = Map<String, dynamic>.from(result.data as Map);
    final name = data['farmName']?.toString().trim();

    if (name == null || name.isEmpty) {
      return 'No farm assigned';
    }

    return name;
  }

}
