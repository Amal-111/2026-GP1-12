import 'package:flutter/foundation.dart';

import 'mock_data.dart';

/// Login information for one person. For a farmer the name, phone and farm
/// live in [FarmerData] (MockData.farmers) so the farm owner's pages see the
/// same data; for a farm owner they are kept here.
class Account {
  final String id; // FarmerData id for a farmer, e.g. FR001
  final UserRole role;
  String email;
  String password;
  String ownerName;
  String ownerPhone;

  Account({
    required this.id,
    required this.role,
    required this.email,
    required this.password,
    this.ownerName = '',
    this.ownerPhone = '',
  });
}

enum RequestStatus { pending, approved, declined }

/// A farmer asking to join a farm (Farm Assignment Request screen).
class FarmRequest {
  final String id;
  final String farmerId;
  final String farmId;
  final DateTime createdAt;
  RequestStatus status;

  FarmRequest({
    required this.id,
    required this.farmerId,
    required this.farmId,
    required this.createdAt,
    this.status = RequestStatus.pending,
  });
}

/// Sign up, log in, profile and farm requests (mock data, no server yet).
class AuthStore {
  static const String demoPassword = 'Rasd@1234';

  static final List<Account> accounts = [
    Account(
      id: 'OW001',
      role: UserRole.farmOwner,
      email: 'sara@rasd.com',
      password: demoPassword,
      ownerName: 'Sara',
      ownerPhone: '0551234567',
    ),
    Account(id: 'FR001', role: UserRole.farmer, email: 'ahmed@rasd.com', password: demoPassword),
    Account(id: 'FR002', role: UserRole.farmer, email: 'salem@rasd.com', password: demoPassword),
    Account(id: 'FR003', role: UserRole.farmer, email: 'noura@rasd.com', password: demoPassword),
    Account(id: 'FR004', role: UserRole.farmer, email: 'omar@rasd.com', password: demoPassword),
  ];

  static final List<FarmRequest> requests = [];

  // Profile settings that are only UI for now.
  static final ValueNotifier<bool> arabic = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> notificationsOn = ValueNotifier<bool>(true);

  static Account? _current;
  static String? _firebaseFarmId;

  static void setFirebaseAccount(Account account, {String? farmId}) {
    _current = account;
    _firebaseFarmId = farmId;
    MockData.currentUser = RasdUser(account.ownerName, account.role, farmId: farmId);
    MockData.notifyChange();
  }


  /// The logged-in account. If nobody logged in (for example a teammate
  /// starts the app on another page) it falls back to MockData.currentUser.
  static Account get currentAccount {
    if (_current != null) return _current!;
    final wantedRole = MockData.currentUser.role;
    return accounts.firstWhere((a) => a.role == wantedRole);
  }

  static bool get isLoggedIn => _current != null;

  // ---------------- profile values ----------------

  static FarmerData? get _farmerData {
    final account = currentAccount;
    if (account.role != UserRole.farmer) return null;
    for (final f in MockData.farmers) {
      if (f.id == account.id) return f;
    }
    return null;
  }

  static UserRole get role => currentAccount.role;
  static String get email => currentAccount.email;
  static String get name => _firebaseFarmId != null || currentAccount.id.length > 20 ? currentAccount.ownerName : (_farmerData?.name ?? currentAccount.ownerName);
  static String get phone => currentAccount.id.length > 20 ? currentAccount.ownerPhone : (_farmerData?.phoneNumber ?? currentAccount.ownerPhone);
  static String? get farmId => _firebaseFarmId ?? _farmerData?.farmId;

  static String? get farmName {
    final id = farmId;
    if (id == null) return null;
    for (final farm in MockData.farms) {
      if (farm.id == id) return farm.name;
    }
    return null;
  }

  /// Tells the rest of the app who is logged in (Home reads this).
  static void applyCurrentUser() {
    MockData.currentUser = RasdUser(name, role, farmId: farmId);
    MockData.notifyChange();
  }

  // ---------------- sign up / log in ----------------

  static bool _emailTaken(String email, {String? exceptId}) {
    final e = email.trim().toLowerCase();
    return accounts.any(
      (a) => a.email.toLowerCase() == e && a.id != exceptId,
    );
  }

  /// Returns an error message, or null when the account was created.
  static String? signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
  }) {
    if (_emailTaken(email)) return 'This email is already registered.';

    late final Account account;
    if (role == UserRole.farmer) {
      final farmerId = _nextId('FR', MockData.farmers.map((f) => f.id));
      MockData.farmers.add(FarmerData(
        id: farmerId,
        name: name.trim(),
        email: email.trim(),
        phoneNumber: phone.trim(),
        farmId: null,
      ));
      account = Account(
        id: farmerId,
        role: role,
        email: email.trim(),
        password: password,
      );
    } else {
      account = Account(
        id: _nextId('OW', accounts.where((a) => a.role == UserRole.farmOwner).map((a) => a.id)),
        role: role,
        email: email.trim(),
        password: password,
        ownerName: name.trim(),
        ownerPhone: phone.trim(),
      );
    }

    accounts.add(account);
    _current = account;
    applyCurrentUser();
    return null;
  }

  /// Returns an error message, or null when the login worked.
  static String? logIn(String email, String password) {
    final e = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.email.toLowerCase() == e) {
        if (account.password != password) return 'Incorrect password.';
        _current = account;
        applyCurrentUser();
        return null;
      }
    }
    return 'No account found with this email.';
  }

  static void logOut() {
    _current = null;
    _firebaseFarmId = null;
  }

  // ---------------- profile changes ----------------

  /// Returns an error message, or null when saved.
  static String? updateProfile({
    required String name,
    required String email,
    required String phone,
  }) {
    final account = currentAccount;
    if (_emailTaken(email, exceptId: account.id)) {
      return 'This email is already registered.';
    }

    account.email = email.trim();
    final farmer = _farmerData;
    if (farmer != null) {
      MockData.updateFarmer(
        farmer,
        name: name.trim(),
        email: email.trim(),
        phoneNumber: phone.trim(),
      );
    } else {
      account.ownerName = name.trim();
      account.ownerPhone = phone.trim();
    }
    applyCurrentUser();
    return null;
  }

  /// Returns an error message, or null when the password was changed.
  static String? changePassword(String currentPassword, String newPassword) {
    final account = currentAccount;
    if (account.password != currentPassword) {
      return 'The current password is incorrect.';
    }
    if (newPassword == currentPassword) {
      return 'The new password must be different.';
    }
    account.password = newPassword;
    return null;
  }

  // ---------------- farm requests ----------------

  static FarmRequest? get pendingRequest {
    final id = currentAccount.id;
    for (final r in requests) {
      if (r.farmerId == id && r.status == RequestStatus.pending) return r;
    }
    return null;
  }

  static void sendRequest(String farmId) {
    requests.add(FarmRequest(
      id: 'RQ${(requests.length + 1).toString().padLeft(3, '0')}',
      farmerId: currentAccount.id,
      farmId: farmId,
      createdAt: DateTime.now(),
    ));
    MockData.notifyChange();
  }

  static void cancelRequest(FarmRequest request) {
    requests.remove(request);
    MockData.notifyChange();
  }

  /// For the farm owner's side (Manage Farmers): approve a request.
  static void approveRequest(FarmRequest request) {
    request.status = RequestStatus.approved;
    for (final farmer in MockData.farmers) {
      if (farmer.id == request.farmerId) {
        MockData.assignFarmerToFarm(farmer, request.farmId);
      }
    }
    if (_current?.id == request.farmerId) applyCurrentUser();
  }

  /// For the farm owner's side (Manage Farmers): decline a request.
  static void declineRequest(FarmRequest request) {
    request.status = RequestStatus.declined;
    MockData.notifyChange();
  }

  static String _nextId(String prefix, Iterable<String> ids) {
    var max = 0;
    for (final id in ids) {
      final n = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > max) max = n;
    }
    return '$prefix${(max + 1).toString().padLeft(3, '0')}';
  }
}
