// FlutterFire platform interfaces provide the signed-out test doubles.
// ignore_for_file: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasd_app/auth/login_page.dart';
import 'package:rasd_app/auth/welcome_page.dart';
import 'package:rasd_app/data/auth_store.dart';
import 'package:rasd_app/main.dart';

class _SignedOutAuth extends FirebaseAuthPlatform {
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  UserPlatform? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _SignedOutAuth();
    AuthStore.arabic.value = false;
  });

  testWidgets('Signed-out launch shows Welcome and opens Login', (
    tester,
  ) async {
    await tester.pumpWidget(const RasdApp());
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
