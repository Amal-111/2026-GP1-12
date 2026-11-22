// FlutterFire interfaces are used as in-memory test doubles.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_database_platform_interface/firebase_database_platform_interface.dart';
import 'package:firebase_database_platform_interface/src/method_channel/method_channel_database_event.dart';
import 'package:firebase_database_platform_interface/src/method_channel/method_channel_database_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasd_app/data/auth_store.dart';
import 'package:rasd_app/manage_farms/invitations_page.dart';
import 'package:rasd_app/services/selected_farm_service.dart';

class _Auth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform get currentUser => _User(this);
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _User extends UserPlatform {
  _User(FirebaseAuthPlatform auth)
    : super(
        auth,
        _MultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'owner-uid',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _Database extends DatabasePlatform {
  final snapshots = StreamController<Object?>.broadcast();
  @override
  DatabasePlatform delegateFor({
    required FirebaseApp app,
    String? databaseURL,
  }) => this;
  @override
  DatabaseReferencePlatform ref([String? path]) {
    expect(path, 'users/owner-uid/sentFarmInvitations');
    return _Ref(this, path!);
  }
}

class _Ref extends MethodChannelDatabaseReference {
  _Ref(this.db, String path)
    : super(database: db, pathComponents: path.split('/'));
  final _Database db;
  @override
  Stream<DatabaseEventPlatform> onValue(QueryModifiers modifiers) =>
      db.snapshots.stream.map(
        (value) => MethodChannelDatabaseEvent(this, {
          'snapshot': {'key': key, 'value': value, 'childKeys': <String>[]},
        }),
      );
}

class _Functions extends FirebaseFunctionsPlatform {
  _Functions() : super(null, 'us-central1');
  final canceled = <String>[];
  @override
  FirebaseFunctionsPlatform delegateFor({
    FirebaseApp? app,
    required String region,
  }) => this;
  @override
  HttpsCallablePlatform httpsCallable(
    String? origin,
    String name,
    HttpsCallableOptions options,
  ) => _Callable(this, origin, name, options);
}

class _Callable extends HttpsCallablePlatform {
  _Callable(
    this.fake,
    String? origin,
    String name,
    HttpsCallableOptions options,
  ) : super(fake, origin, name, options, null);
  final _Functions fake;
  @override
  Future<Object?> call([dynamic parameters]) async {
    if (name == 'cancelInvitation') {
      fake.canceled.add(parameters['invitationId'] as String);
      return {'success': true};
    }
    expect(name, 'getInvitationDetails');
    return {'farmerName': 'Test Farmer', 'farmerEmail': 'farmer@example.test'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = _Database();
  final functions = _Functions();
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _Auth();
    DatabasePlatform.instance = db;
    FirebaseFunctionsPlatform.instance = functions;
    AuthStore.arabic.value = false;
    SelectedFarmService.selectFarm('farm-uid');
  });
  tearDownAll(() async {
    SelectedFarmService.clearSelection();
    await db.snapshots.close();
  });
  testWidgets('Owner invitation updates from Cancel to red disabled Rejected', (
    tester,
  ) async {
    const invitation = {
      'farmId': 'farm-uid',
      'farmerId': 'farmer-uid',
      'createdAt': 123,
    };
    await tester.pumpWidget(const MaterialApp(home: InvitationsPage()));
    db.snapshots.add({'old-invitation': invitation});
    await tester.pumpAndSettle();
    expect(find.text('Test Farmer'), findsOneWidget);
    expect(find.text('farmer@example.test'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

    db.snapshots.add({
      'old-invitation': {...invitation, 'status': 'rejected'},
    });
    await tester.pumpAndSettle();
    expect(find.text('Test Farmer'), findsOneWidget);
    expect(find.text('farmer@example.test'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    final rejected = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Rejected'),
    );
    expect(rejected.onPressed, isNull);
    expect(
      rejected.style!.foregroundColor!.resolve({WidgetState.disabled}),
      Colors.red,
    );

    db.snapshots.add({
      'old-invitation': {...invitation, 'status': 'rejected'},
      'new-invitation': invitation,
    });
    await tester.pumpAndSettle();
    expect(find.text('Test Farmer'), findsOneWidget);
    expect(find.text('Rejected'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

    db.snapshots.add({'new-invitation': invitation});
    await tester.pumpAndSettle();
    expect(find.text('Test Farmer'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel Invitation'));
    await tester.pumpAndSettle();
    expect(functions.canceled, ['new-invitation']);

    db.snapshots.add(null);
    await tester.pumpAndSettle();
    expect(find.text('No pending invitations'), findsOneWidget);
    expect(find.text('Rejected'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
  });
}
