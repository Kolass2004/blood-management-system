import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/registration_screen.dart';
import 'services/location_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  if (await Permission.location.isGranted) {
    await initializeService();
    // we also need to actually start it since autoStart is false
    final service = FlutterBackgroundService();
    service.startService();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blood Donors App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: _getLandingPage(),
    );
  }

  Widget _getLandingPage() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          }
          // User is authenticated — check Firestore registration
          return _RegistrationGate(user: user);
        }
        return const Scaffold(
          backgroundColor: Color(0xFF0A0A0C),
          body: Center(child: CircularProgressIndicator(color: Color(0xFFE11D48))),
        );
      },
    );
  }
}

/// Checks if the user has completed Firestore registration.
/// Routes to RegistrationScreen if not, otherwise MainShell.
/// Also persists UID to SharedPreferences for the background service.
class _RegistrationGate extends StatefulWidget {
  final User user;
  const _RegistrationGate({required this.user});

  @override
  State<_RegistrationGate> createState() => _RegistrationGateState();
}

class _RegistrationGateState extends State<_RegistrationGate> {
  @override
  void initState() {
    super.initState();
    // Save UID for background service
    saveUidForBackgroundService(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0C),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFE11D48))),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0C),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFE11D48), size: 48),
                  const SizedBox(height: 16),
                  const Text('Failed to connect', style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        final doc = snapshot.data;
        if (doc == null || !doc.exists || doc.data() == null) {
          return const RegistrationScreen();
        }

        final data = doc.data() as Map<String, dynamic>;
        if (data['bloodGroup'] == null) {
          return const RegistrationScreen();
        }

        // Registration is complete — show the app
        return const MainShell();
      },
    );
  }
}

