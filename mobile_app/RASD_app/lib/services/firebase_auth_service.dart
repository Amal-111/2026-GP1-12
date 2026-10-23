import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../data/auth_store.dart';
import '../data/mock_data.dart';

/// Firebase-backed identity. Legacy AuthStore remains only as a temporary
/// adapter for pages that still read MockData.
class RasdAuthService {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFunctions functions =
  FirebaseFunctions.instanceFor(region: 'us-central1');
  static final FirebaseDatabase database = FirebaseDatabase.instance;

  static Future<void> signUp({required String name, required String email,
    required String phone, required String password, required UserRole role}) async {
    final result = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await result.user!.updateDisplayName(name.trim());
    await result.user!.sendEmailVerification();
    // Registration is completed on the next login after email verification.
    // No role/profile is written directly from the client.
  }

  static Future<void> completeRegistration({required String name,
    required String phone, required UserRole role}) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Please log in first.');
    await user.reload();
    if (!(auth.currentUser?.emailVerified ?? false)) {
      throw StateError('Please verify your email before continuing.');
    }
    await functions.httpsCallable('registerProfile').call({
      'fullName': name.trim(), 'phoneNumber': phone.trim(),
      'role': role == UserRole.farmOwner ? 'FarmOwner' : 'Farmer',
      'preferredLanguage': 'en',
    });
    await loadProfile();
  }

  static Future<bool> hasProfile() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return false;
    final snapshot = await database.ref('users/$uid').get();
    return snapshot.exists;
  }

  static Future<void> logIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    await auth.currentUser!.reload();
    if (!(auth.currentUser?.emailVerified ?? false)) {
      await auth.signOut();
      throw StateError('Please verify your email, then log in again.');
    }
    if (!await hasProfile()) {
      throw StateError('Your email is verified, but your profile is not registered. Restart the app to complete your profile.');
    }
    await loadProfile();
  }

  static Future<void> loadProfile() async {
    final user = auth.currentUser;
    if (user == null) return;
    final snapshot = await database.ref('users/${user.uid}').get();
    if (snapshot.value is! Map) throw StateError('User profile not found.');
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

  static Future<void> updateProfile({required String name, required String phone}) async {
    await functions.httpsCallable('updateProfile').call({'fullName': name.trim(), 'phoneNumber': phone.trim()});
    await loadProfile();
  }

  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final user = auth.currentUser!;
    final credential = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  static Future<void> logOut() async {
    await auth.signOut();
    AuthStore.logOut();
  }

  static String message(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use': return 'This email is already registered.';
        case 'invalid-email': return 'Invalid email address.';
        case 'weak-password': return 'Please choose a stronger password.';
        case 'invalid-credential': case 'wrong-password': case 'user-not-found':
          return 'Incorrect email or password.';
        case 'network-request-failed': return 'Network connection failed.';
      }
      return error.message ?? error.code;
    }
    if (error is FirebaseFunctionsException) return error.message ?? error.code;
    return error.toString().replaceFirst('Bad state: ', '');
  }


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
