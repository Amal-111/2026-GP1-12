// FlutterFire platform interfaces provide in-memory test doubles.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_database_platform_interface/firebase_database_platform_interface.dart';
import 'package:firebase_database_platform_interface/src/method_channel/method_channel_database_event.dart';
import 'package:firebase_database_platform_interface/src/method_channel/method_channel_database_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasd_app/data/auth_store.dart';
import 'package:rasd_app/list/monitoring_history.dart';
import 'package:rasd_app/list/palm_details.dart';
import 'package:rasd_app/screens/alert_details.dart';
import 'package:rasd_app/screens/alerts.dart';
import 'package:rasd_app/screens/home.dart';
import 'package:rasd_app/services/rasd_alert_service.dart';

class _FarmerAuth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;
  @override
  UserPlatform get currentUser => _Farmer(this);
}

class _MultiFactor extends MultiFactorPlatform {
  _MultiFactor(super.auth);
}

class _Farmer extends UserPlatform {
  _Farmer(FirebaseAuthPlatform auth)
    : super(
        auth,
        _MultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: 'qa-farmer',
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );
}

class _AlertDatabase extends DatabasePlatform {
  final values = <String, Object?>{};
  final events = StreamController<String>.broadcast();
  @override
  DatabasePlatform delegateFor({
    required FirebaseApp app,
    String? databaseURL,
  }) => this;
  @override
  DatabaseReferencePlatform ref([String? path]) => _AlertRef(this, path ?? '');

  void write(String path, Object? value) {
    values[path] = value;
    events.add(path);
  }
}

class _AlertRef extends MethodChannelDatabaseReference {
  _AlertRef(this.db, this._path)
    : super(database: db, pathComponents: _path.split('/'));
  final _AlertDatabase db;
  final String _path;
  DatabaseEventPlatform _event() => MethodChannelDatabaseEvent(this, {
    'snapshot': {
      'key': key,
      'value': db.values[_path],
      'priority': null,
      'childKeys': <String>[],
    },
  });
  @override
  Stream<DatabaseEventPlatform> onValue(QueryModifiers modifiers) async* {
    yield _event();
    yield* db.events.stream
        .where((changed) => changed == _path)
        .map((_) => _event());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = _AlertDatabase();
  const palms = 'farms/qa-farm/palms';
  const palm = '$palms/qa-palm';
  const alert = '$palm/alerts/-OriginalQaAlert';
  const old = {'alertType': 'UnderMonitoring', 'timestamp': 1700000000000};
  const fresh = {
    'alertType': 'PossiblePestDetected',
    'timestamp': 1720000000000,
    'palmId': 'wrong',
  };
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    DatabasePlatform.instance = db;
    FirebaseAuthPlatform.instance = _FarmerAuth();
    AuthStore.arabic.value = false;
  });
  tearDownAll(db.events.close);
  testWidgets(
    'Alerts orders embedded records and handles live update and deletion',
    (t) async {
      db.values[palms] = {
        'qa-palm': {
          'alerts': {'-Old': old, '-OriginalQaAlert': fresh},
        },
      };
      db.values[alert] = fresh;
      db.values[palm] = {'healthStatus': 'Healthy'};
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlertsScreen(farmId: 'qa-farm', farmName: 'QA Farm'),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.text('Potential Infestation')).dy,
        lessThan(t.getTopLeft(find.text('Palm Under Monitoring')).dy),
      );
      await t.tap(find.text('Potential Infestation'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDetailsScreen), findsOneWidget);
      expect(find.text('QA Farm'), findsOneWidget);
      expect(find.text('qa-palm'), findsOneWidget);
      expect(find.textContaining('/2024'), findsOneWidget);
      db.write(alert, {...fresh, 'alertType': 'SensorOffline'});
      await t.pumpAndSettle();
      expect(find.text('Sensor Offline'), findsOneWidget);
      await t.tap(find.text('Palm Details'));
      await t.pumpAndSettle();
      expect(
        t.widget<PalmDetailsPage>(find.byType(PalmDetailsPage)).palmId,
        'qa-palm',
      );
      db.write(palm, null);
      await t.pumpAndSettle();
      expect(find.text('Palm not found.'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      db.write(alert, null);
      await t.pumpAndSettle();
      expect(find.text('This alert is unavailable.'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      db.write(palms, null);
      await t.pumpAndSettle();
      expect(find.text('No current alerts.'), findsOneWidget);
    },
  );
  testWidgets('Home opens Recent Alerts using original Firebase keys', (
    t,
  ) async {
    db.values['users/qa-farmer'] = {'role': 'Farmer', 'farmId': 'qa-farm'};
    db.values['farms/qa-farm'] = {'farmName': 'QA Farm'};
    db.values[palms] = {
      'qa-palm': {
        'id': 'wrong-palm',
        'alerts': {
          '-OriginalQaAlert': {...fresh, 'id': 'wrong-alert'},
          '-Old': old,
        },
      },
    };
    db.values[alert] = fresh;
    await t.pumpWidget(const MaterialApp(home: HomeScreen()));
    await t.pumpAndSettle();
    final recent = find.text('Potential Infestation');
    await t.ensureVisible(recent);
    await t.pumpAndSettle();
    await t.tap(recent);
    await t.pumpAndSettle();
    expect(find.byType(AlertDetailsScreen), findsOneWidget);
    expect(find.text('QA Farm'), findsOneWidget);
    expect(find.text('qa-palm'), findsOneWidget);
  });
  testWidgets('Invalid alert path shows unavailable', (t) async {
    const bad = RasdAlert(
      id: 'bad/path',
      farmId: 'qa-farm',
      palmId: 'qa-palm',
      type: '',
      createdAt: null,
      isRead: false,
    );
    await t.pumpWidget(
      const MaterialApp(
        home: AlertDetailsScreen(alert: bad, farmName: 'QA Farm'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('This alert is unavailable.'), findsOneWidget);
  });
  testWidgets(
    'Embedded monitoring history orders treatment and monitoring events',
    (t) async {
      const history = '$palm/monitoringHistory';
      db.values[history] = {
        '-old': {
          'eventType': 'Monitoring',
          'healthStatus': 'Healthy',
          'timestamp': 1700000000000,
        },
        '-new': {
          'eventType': 'Treatment',
          'healthStatus': 'UnderMonitoring',
          'timestamp': 1720000000000,
          'treatmentDetails': {
            'treatmentMethod': 'QA treatment',
            'treatmentDate': '2024-07-03',
            'notes': 'QA notes',
          },
        },
      };
      await t.pumpWidget(
        const MaterialApp(
          home: MonitoringHistoryPage(farmId: 'qa-farm', palmId: 'qa-palm'),
        ),
      );
      await t.pumpAndSettle();
      final treatment = find.text('Treatment Recorded');
      expect(treatment, findsOneWidget);
      expect(
        t.getTopLeft(treatment).dy,
        lessThan(t.getTopLeft(find.text('Healthy')).dy),
      );
      await t.tap(treatment);
      await t.pumpAndSettle();
      expect(find.text('QA treatment'), findsOneWidget);
      expect(find.text('QA notes'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      db.write(history, null);
      await t.pumpAndSettle();
      expect(find.text('No monitoring events yet.'), findsOneWidget);
    },
  );
}
