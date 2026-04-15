import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  StreamSubscription? _urgentRequestSub;
  final Set<String> _shownOverlays = {};

  final List<Widget> _pages = const [
    HomeScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForUrgentRequests();
  }

  @override
  void dispose() {
    _urgentRequestSub?.cancel();
    super.dispose();
  }

  /// Listen for new urgent requests and show a full-screen overlay
  void _listenForUrgentRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _urgentRequestSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        if (!_shownOverlays.contains(doc.id)) {
          _shownOverlays.add(doc.id);
          final data = doc.data();
          // Small delay to ensure context is ready
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showUrgentOverlay(doc.id, data);
            }
          });
        }
      }
    });
  }

  void _showUrgentOverlay(String requestId, Map<String, dynamic> data) {
    final message = data['message'] ?? 'A nearby hospital urgently needs your blood type!';
    final bloodType = data['bloodType'] ?? '';

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, anim, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: child,
        );
      },
      pageBuilder: (context, anim, anim2) {
        return _UrgentOverlayContent(
          message: message,
          bloodType: bloodType,
          onAcknowledge: () {
            FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('requests')
                .doc(requestId)
                .update({'status': 'acknowledged'});
            Navigator.of(context).pop();
          },
          onDismiss: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF1E1E24), width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: const Color(0xFFE11D48).withOpacity(0.15),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE11D48),
                );
              }
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white38,
              );
            }),
          ),
          child: NavigationBar(
            height: 70,
            backgroundColor: const Color(0xFF0A0A0C),
            surfaceTintColor: Colors.transparent,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: Colors.white38),
                selectedIcon: Icon(Icons.home_rounded, color: Color(0xFFE11D48)),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: Colors.white38),
                selectedIcon: Icon(Icons.person, color: Color(0xFFE11D48)),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen dramatic overlay for urgent blood requests
class _UrgentOverlayContent extends StatefulWidget {
  final String message;
  final String bloodType;
  final VoidCallback onAcknowledge;
  final VoidCallback onDismiss;

  const _UrgentOverlayContent({
    required this.message,
    required this.bloodType,
    required this.onAcknowledge,
    required this.onDismiss,
  });

  @override
  State<_UrgentOverlayContent> createState() => _UrgentOverlayContentState();
}

class _UrgentOverlayContentState extends State<_UrgentOverlayContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing blood drop icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 120 + (_pulseController.value * 20),
                    height: 120 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE11D48).withOpacity(0.15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48)
                              .withOpacity(0.3 + _pulseController.value * 0.2),
                          blurRadius: 40 + (_pulseController.value * 20),
                          spreadRadius: 10 + (_pulseController.value * 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bloodtype_rounded,
                        size: 60,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // URGENT title
              const Text(
                '🚨 EMERGENCY ALERT',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE11D48),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),

              // Blood type badge
              if (widget.bloodType.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFE11D48).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '${widget.bloodType} NEEDED',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Message
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: widget.onDismiss,
                        child: const Text(
                          'DISMISS',
                          style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFFE11D48).withOpacity(0.5),
                        ),
                        onPressed: widget.onAcknowledge,
                        child: const Text(
                          'I CAN HELP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
