// FlutterFire and launcher platform interfaces are used only as test doubles.
// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_database_platform_interface/firebase_database_platform_interface.dart';
import 'package:firebase_database_platform_interface/src/method_channel/method_channel_database_event.dart';
import 'package:firebase_database_platform_interface/src/method_channel/method_channel_database_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:rasd_app/data/auth_store.dart';
import 'package:rasd_app/list/palm_details.dart';
import 'package:rasd_app/data/mock_data.dart';
import 'package:rasd_app/manage_farms/farm_settings_page.dart';
import 'package:rasd_app/manage_palms/add_palm_page.dart';
import 'package:rasd_app/manage_palms/connect_sensor_page.dart';
import 'package:rasd_app/manage_palms/farm_location_picker.dart';
import 'package:rasd_app/map/palm_map.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _TestLocation extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.whileInUse;
  int requests = 0;
  int reads = 0;
  Object? error;
  Completer<Position>? pending;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    expect(locationSettings?.timeLimit, const Duration(seconds: 15));
    if (error case final failure?) throw failure;
    return pending?.future ?? _position();
  }

  static Position _position() => Position(
    latitude: 24.72,
    longitude: 46.68,
    timestamp: DateTime(2026),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

typedef _Coordinates = ({double latitude, double longitude});

Future<List<_Coordinates>> _pumpPicker(WidgetTester tester) async {
  const initial = (latitude: 24.71, longitude: 46.67);
  var selected = initial;
  final changes = <_Coordinates>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return FarmLocationPicker(
              latitude: selected.latitude,
              longitude: selected.longitude,
              showCurrentLocation: true,
              onPicked: (value) {
                changes.add(value);
                setState(() => selected = value);
              },
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changes;
}

class _TestDatabase extends DatabasePlatform {
  static const palm = {
    'latitude': 24.72,
    'longitude': 46.68,
    'healthStatus': 'Healthy',
  };
  static const values = {
    'farms/test-farm': {'latitude': 24.72, 'longitude': 46.68},
    'farms/test-farm/palms': {'first': palm, 'second': palm, 'missing': {}},
    'farms/test-farm/palms/second': palm,
  };

  @override
  DatabasePlatform delegateFor({
    required FirebaseApp app,
    String? databaseURL,
  }) => this;

  @override
  DatabaseReferencePlatform ref([String? path]) => _TestRef(this, path ?? '');
}

class _TestRef extends MethodChannelDatabaseReference {
  _TestRef(DatabasePlatform db, this._path)
    : super(database: db, pathComponents: _path.split('/'));
  final String _path;

  @override
  Stream<DatabaseEventPlatform> onValue(QueryModifiers modifiers) =>
      Stream.value(
        MethodChannelDatabaseEvent(this, {
          'snapshot': {
            'key': key,
            'value': _TestDatabase.values[_path],
            'priority': null,
            'childKeys': <String>[],
          },
        }),
      );
}

class _TestLauncher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;

  String? url;
  LaunchOptions? options;

  @override
  Future<bool> launchUrl(String value, LaunchOptions launchOptions) async {
    url = value;
    options = launchOptions;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestLocation location;
  setUp(() {
    AuthStore.arabic.value = false;
    location = _TestLocation();
    GeolocatorPlatform.instance = location;
  });

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    DatabasePlatform.instance = _TestDatabase();
  });

  testWidgets(
    'requests permission, moves the camera and pin, and allows manual adjustment',
    (tester) async {
      location.permission = LocationPermission.denied;
      final changes = await _pumpPicker(tester);
      expect(changes, isEmpty);
      await tester.tap(find.byTooltip('My Current Location'));
      await tester.pumpAndSettle();
      const current = (latitude: 24.72, longitude: 46.68);
      expect(location.requests, 1);
      expect(changes, [current]);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.mapController!.camera.center, const LatLng(24.72, 46.68));
      final pickedMarkers = tester.widget<MarkerLayer>(
        find.byType(MarkerLayer),
      );
      expect(pickedMarkers.markers.last.point, const LatLng(24.72, 46.68));
      map.options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        const LatLng(24.725, 46.685),
      );
      await tester.pumpAndSettle();
      expect(changes.last, (latitude: 24.725, longitude: 46.685));
    },
  );

  testWidgets('a manual tap wins over an in-flight GPS request', (
    tester,
  ) async {
    location.pending = Completer<Position>();
    final changes = await _pumpPicker(tester);
    await tester.tap(find.byTooltip('My Current Location'));
    await tester.pump();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(24.715, 46.675),
    );
    location.pending!.complete(_TestLocation._position());
    await tester.pumpAndSettle();
    expect(changes, [(latitude: 24.715, longitude: 46.675)]);
    expect(location.requests, 0);
  });

  final failures = <(String, void Function(_TestLocation), String, int)>[
    (
      'GPS disabled',
      (l) => l.enabled = false,
      'Turn on location services and try again.',
      0,
    ),
    (
      'denied',
      (l) => l.permission = l.requested = LocationPermission.denied,
      'Location permission was denied.',
      0,
    ),
    (
      'permanently denied',
      (l) => l.permission = LocationPermission.deniedForever,
      'Enable location permission in the app settings.',
      0,
    ),
    (
      'timeout',
      (l) => l.error = TimeoutException('timeout'),
      'Location timed out. Please try again.',
      1,
    ),
    (
      'unavailable',
      (l) => l.error = StateError('unavailable'),
      'Your current location is unavailable. Please try again.',
      1,
    ),
  ];

  for (final (name, configure, message, reads) in failures) {
    testWidgets('$name preserves the initial farm pin', (tester) async {
      configure(location);
      final changes = await _pumpPicker(tester);
      await tester.tap(find.byTooltip('My Current Location'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(changes, isEmpty);
      final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markers.markers.last.point, const LatLng(24.71, 46.67));
      expect(location.reads, reads);
    });
  }

  testWidgets('location picker renders only the selected pin', (tester) async {
    _Coordinates? pin;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return FarmLocationPicker(
            onPicked: (point) => setState(() => pin = point),
            latitude: pin?.latitude,
            longitude: pin?.longitude,
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers, isEmpty);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(24.72, 46.68),
    );
    await tester.pumpAndSettle();
    final markers = tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
    expect(markers, hasLength(1));
    expect(markers.single.point, LatLng(pin!.latitude, pin!.longitude));
  });

  testWidgets('farm settings restores its supplied farm photo', (tester) async {
    final farm = RasdFarm('firebase-id', 'Firebase Farm',
        location: '24, 46', imagePath: 'https://example.test/farm.png',
        latitude: 24, longitude: 46, palmCount: 4, farmerCount: 0);
    await tester.pumpWidget(MaterialApp(home: FarmSettingsPage(farm: farm)));
    await tester.pumpAndSettle();

    expect(find.text('Change'), findsOneWidget);
    final remove = find.text('Remove');
    expect(remove, findsOneWidget);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Add farm photo'), findsOneWidget);
  });

  testWidgets('editing keeps the saved location until the picker is confirmed', (
    tester,
  ) async {
    final saved = MockData.selectedFarm;
    final savedLocation = saved.location;
    final previous =
        '${saved.latitude!.toStringAsFixed(6)}, ${saved.longitude!.toStringAsFixed(6)}';
    await tester.pumpWidget(MaterialApp(home: FarmSettingsPage(farm: saved)));
    await tester.pumpAndSettle();
    final locationRow = find.byIcon(Icons.location_on_outlined);
    await tester.ensureVisible(locationRow);
    expect(find.text(previous), findsOneWidget);

    await tester.tap(locationRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My Current Location'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(previous), findsOneWidget);

    await tester.tap(locationRow);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My Current Location'));
    await tester.pumpAndSettle();
    final confirm = find.text('Use This Location');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('24.720000, 46.680000'), findsOneWidget);
    expect(MockData.selectedFarm.location, savedLocation);
  });

  testWidgets('Add Palm uses GPS and forwards the manually adjusted location', (
    tester,
  ) async {
    location.permission = LocationPermission.denied;
    await tester.pumpWidget(const MaterialApp(home: AddPalmPage()));
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    tester.testTextInput.hide();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sukkari').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final gps = find.byTooltip('My Current Location');
    await tester.ensureVisible(gps);
    await tester.tap(gps);
    await tester.pumpAndSettle();
    expect(location.requests, 1);
    expect(find.text('24.72'), findsOneWidget);
    expect(find.text('46.68'), findsOneWidget);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center, const LatLng(24.72, 46.68));

    map.options.onTap!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(24.725, 46.685),
    );
    await tester.pumpAndSettle();

    location.enabled = false;
    await tester.tap(gps);
    await tester.pumpAndSettle();
    expect(
      find.text('Turn on location services and try again.'),
      findsOneWidget,
    );
    expect(find.text('24.725'), findsOneWidget);
    expect(find.text('46.685'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(gps)).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next: Connect Sensor'));
    await tester.pumpAndSettle();
    final sensor = tester.widget<ConnectSensorPage>(
      find.byType(ConnectSensorPage),
    );
    expect(sensor.latitude, 24.725);
    expect(sensor.longitude, 46.685);
  });

  test(
    'directions reject missing, non-finite and out-of-range destinations',
    () {
      for (final destination in [
        null,
        const LatLng(double.nan, 10),
        const LatLng(91, 10),
        const LatLng(10, double.infinity),
        const LatLng(10, -181),
      ]) {
        expect(
          MapPalm(
            id: 'sample',
            status: 'Healthy',
            point: const LatLng(1, 1),
            deviceId: '',
            destination: destination,
          ).directionsUrl,
          isNull,
        );
      }
    },
  );

  testWidgets(
    'palm card opens details and uses raw coordinates for external directions',
    (tester) async {
      final launcher = _TestLauncher();
      UrlLauncherPlatform.instance = launcher;
      await tester.pumpWidget(
        const MaterialApp(home: FarmMapPage(farmId: 'test-farm')),
      );
      await tester.pumpAndSettle();
      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers, hasLength(2));
      expect(markers.last.point, isNot(const LatLng(24.72, 46.68)));
      // Select the overlapping palm directly so the upper pin cannot intercept it.
      (markers.last.child as GestureDetector).onTap!();
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      expect(find.text('Directions'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Show whole farm'), findsOneWidget);
      await tester.tap(find.text('Directions'));
      await tester.pumpAndSettle();
      final url = Uri.parse(launcher.url!);
      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/dir/');
      expect(url.queryParameters, {
        'api': '1',
        'destination': '24.72,46.68',
        'dir_action': 'navigate',
      });
      expect(launcher.options?.mode, PreferredLaunchMode.externalApplication);
      expect(
        find.text('Could not open Google Maps directions.'),
        findsOneWidget,
      );
      await tester.tap(find.text('View Palm Details'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PalmDetailsPage>(find.byType(PalmDetailsPage)).palmId,
        'second',
      );
    },
  );
}
