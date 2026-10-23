import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'auth/welcome_page.dart';
import 'auth/sign_up_page.dart';
import 'data/auth_store.dart';
import 'data/mock_data.dart';
import 'services/firebase_auth_service.dart';
import 'manage_farms/my_farms_page.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const useEmulators = true;

  if (useEmulators) {
    final host = defaultTargetPlatform == TargetPlatform.android &&
        !kIsWeb
        ? '10.0.2.2'
        : 'localhost';

    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);

    FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).useFunctionsEmulator(host, 5001);

    FirebaseStorage.instance.useStorageEmulator(
      '10.0.2.2',
      9199,
    );
  }

  runApp(const RasdApp());
}

class RasdApp extends StatelessWidget {
  const RasdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RASD',
      theme: AppTheme.lightTheme,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<int> _ready = _restore();

  Future<int> _restore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    await user.reload();
    if (!(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) return 1;
    if (!await RasdAuthService.hasProfile()) return 1;
    await RasdAuthService.loadProfile();
    return 2;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(body: Center(child: Text('Unable to load account: ${snapshot.error}')));
      }
      if (snapshot.data == 0) return const WelcomePage();
      if (snapshot.data == 1) return const SignUpPage();
      return AuthStore.role == UserRole.farmOwner
          ? const MyFarmsPage() : const HomeScreen();
    },
  );
}
