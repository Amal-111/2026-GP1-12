// FlutterFire interfaces are used here as platform test doubles.
// ignore_for_file: depend_on_referenced_packages
import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasd_app/data/auth_store.dart';
import 'package:rasd_app/manage_farms/assign_farmer_page.dart';
import 'package:rasd_app/services/selected_farm_service.dart';

class _Functions extends FirebaseFunctionsPlatform {
  _Functions() : super(null, 'us-central1');

  final calls = <(String, Object?)>[];

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
    fake.calls.add((name!, parameters));
    return switch (name) {
      'searchFarmers' => {
        'farmers': [
          {
            'farmerId': 'original-uid-first',
            'fullName': 'Same Name',
            'phoneNumber': '+966 500 111 111',
          },
          {
            'farmerId': 'original-uid-second',
            'fullName': 'Same Name',
            'phoneNumber': '+966 500 222 222',
          },
          {'farmerId': 'original-uid-no-phone', 'fullName': 'Same Name'},
        ],
      },
      'sendInvitation' => {'success': true},
      _ => throw StateError('Unexpected callable: $name'),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Functions functions;
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    functions = _Functions();
    FirebaseFunctionsPlatform.instance = functions;
    SelectedFarmService.selectFarm('qa-farm');
    AuthStore.arabic.value = false;
  });
  tearDownAll(SelectedFarmService.clearSelection);

  testWidgets(
    'Same-name farmers show distinct phones and send using the selected UID',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const AssignFarmerPage()),
                ),
                child: const Text('Open assignment'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open assignment'));
      await tester.pumpAndSettle();
      final input = find.byType(TextFormField);
      await tester.enterText(input, 'Same');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Same Name'), findsNWidgets(3));
      expect(find.text('+966 500 111 111'), findsOneWidget);
      expect(find.text('+966 500 222 222'), findsOneWidget);
      expect(find.textContaining('Account ID'), findsOneWidget);

      final second = find.text('+966 500 222 222');
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      final send = find.text('Send Invitation');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();

      expect(functions.calls.map((call) => call.$1), [
        'searchFarmers',
        'sendInvitation',
      ]);
      expect(functions.calls[0].$2, {'farmId': 'qa-farm', 'name': 'Same'});
      expect(functions.calls[1].$2, {
        'farmId': 'qa-farm',
        'farmerId': 'original-uid-second',
      });
    },
  );
}
