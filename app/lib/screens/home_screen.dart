import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    setState(() {
      _isTracking = isRunning;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        title: const Text('Node Dashboard', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white54),
            onPressed: () async {
              FlutterBackgroundService().invoke("stopService");
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomCenter,
            radius: 1.5,
            colors: [Color(0xFF1E1E24), Color(0xFF0A0A0C)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Pulse Radar Fake Simulation
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isTracking ? const Color(0xFFE11D48).withOpacity(0.3) : Colors.white12,
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isTracking ? const Color(0xFFE11D48).withOpacity(0.5) : Colors.white24,
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isTracking ? const Color(0xFFE11D48).withOpacity(0.2) : Colors.transparent,
                      boxShadow: _isTracking ? [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ] : [],
                    ),
                    child: Icon(
                      _isTracking ? Icons.satellite_alt : Icons.location_off, 
                      size: 40, 
                      color: _isTracking ? const Color(0xFFE11D48) : Colors.white54
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              
              Text(
                _isTracking ? "GRID UPLINK ACTIVE" : "NETWORK DISCONNECTED",
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800,
                  color: _isTracking ? const Color(0xFFE11D48) : Colors.white54,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isTracking 
                  ? "Your location is securely transmitting to local hospitals."
                  : "You are invisible to emergency scans.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 60),
              
              Container(
                width: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isTracking ? [] : [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
                ),
                child: ElevatedButton.icon(
                  icon: Icon(_isTracking ? Icons.stop_circle : Icons.play_circle_fill, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTracking ? const Color(0xFF1E1E24) : const Color(0xFFE11D48),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _isTracking ? Colors.white12 : Colors.transparent,
                      )
                    ),
                  ),
                  onPressed: () async {
                    final service = FlutterBackgroundService();
                    var isRunning = await service.isRunning();
                    if (isRunning) {
                      service.invoke("stopService");
                    } else {
                      service.startService();
                    }
                    
                    Future.delayed(const Duration(seconds: 1), () {
                      _checkServiceStatus();
                    });
                  },
                  label: Text(
                    _isTracking ? 'DISENGAGE' : 'GO ONLINE', 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
