import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'notifications_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _userData;
  String _locationName = 'Locating...';
  bool _isLoadingLocation = true;
  int _pendingNotifications = 0;
  late AnimationController _pulseController;
  double? _lastResolvedLat;
  double? _lastResolvedLng;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _listenUserData();
    _listenNotifications();
    _fetchAndWriteLocationNow();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _listenNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _pendingNotifications = snapshot.docs.length);
      }
    });
  }

  /// Listen to Firestore in real-time so location updates from the
  /// background service are reflected immediately on the home screen.
  void _listenUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() => _userData = data);
        _resolveLocation(data);
      }
    });
  }

  /// Immediately fetch GPS and write to Firestore so the user doesn't
  /// have to wait for the background service's 30-second interval.
  Future<void> _fetchAndWriteLocationNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'location': {
          'lat': position.latitude,
          'lng': position.longitude,
        },
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Immediate location fetch failed: $e');
    }
  }

  Future<void> _resolveLocation(Map<String, dynamic>? data) async {
    if (data == null || data['location'] == null) {
      if (mounted) {
        setState(() {
          _locationName = 'Location not available';
          _isLoadingLocation = false;
        });
      }
      return;
    }

    try {
      final lat = (data['location']['lat'] as num).toDouble();
      final lng = (data['location']['lng'] as num).toDouble();

      // Don't re-resolve if coordinates haven't changed significantly
      if (_lastResolvedLat != null &&
          (lat - _lastResolvedLat!).abs() < 0.001 &&
          (lng - _lastResolvedLng!).abs() < 0.001) {
        return;
      }

      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [p.subLocality, p.locality, p.administrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .toList();
        _lastResolvedLat = lat;
        _lastResolvedLng = lng;
        setState(() {
          _locationName = parts.isNotEmpty ? parts.join(', ') : 'Unknown area';
          _isLoadingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationName = 'Could not resolve location';
          _isLoadingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName ?? 'Donor').split(' ').first;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.8,
            colors: [Color(0xFF1A1A22), Color(0xFF0A0A0C)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── App Bar ───
              SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                elevation: 0,
                toolbarHeight: 70,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      firstName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Notification bell
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: Colors.white70, size: 26),
                          onPressed: () => showNotificationsSheet(context),
                        ),
                        if (_pendingNotifications > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE11D48).withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '$_pendingNotifications',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Profile picture
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF1E1E24),
                      backgroundImage: user?.photoURL != null
                          ? CachedNetworkImageProvider(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? const Icon(Icons.person, color: Colors.white38)
                          : null,
                    ),
                  ),
                ],
              ),

              // ─── Content ───
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Location Card ──
                    _buildLocationCard(),
                    const SizedBox(height: 20),

                    // ── Quick Stats Row ──
                    _buildQuickStats(),
                    const SizedBox(height: 24),

                    // ── User Details Card ──
                    _buildUserDetailsCard(),
                    const SizedBox(height: 24),

                    // ── Donation History ──
                    _buildDonationHistorySection(),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFE11D48).withOpacity(0.12 + _pulseController.value * 0.04),
                const Color(0xFF1E1E24).withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE11D48).withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: Color(0xFFE11D48), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Location',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingLocation
                        ? Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: const Color(0xFFE11D48).withOpacity(0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Resolving coordinates...',
                                style: TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            ],
                          )
                        : Text(
                            _locationName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    final bloodGroup = _userData?['bloodGroup'] ?? '--';
    final phone = _userData?['phone'] ?? '--';

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.bloodtype_rounded,
            label: 'Blood Type',
            value: bloodGroup,
            color: const Color(0xFFE11D48),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildStatCard(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: phone,
            color: const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailsCard() {
    if (_userData == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE11D48)),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          _detailRow(Icons.person_outline, 'Name', user?.displayName ?? 'N/A'),
          _detailRow(Icons.email_outlined, 'Email', user?.email ?? 'N/A'),
          _detailRow(Icons.warning_amber_rounded, 'Allergies',
              _userData?['allergies']?.isNotEmpty == true ? _userData!['allergies'] : 'None'),
          _detailRow(Icons.medical_services_outlined, 'Medical Records',
              _userData?['pastRecords']?.isNotEmpty == true ? _userData!['pastRecords'] : 'None'),
          _detailRow(Icons.contact_emergency, 'Emergency Nominee',
              _userData?['nomineeDetails'] ?? 'N/A'),
          _detailRow(Icons.home_outlined, 'Address',
              _userData?['permanentAddress'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white38, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationHistorySection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Donation History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Life Saver',
                    style: TextStyle(
                      color: Color(0xFFE11D48),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('donations')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Color(0xFFE11D48)),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.volunteer_activism_outlined,
                          size: 48, color: Colors.white.withOpacity(0.08)),
                      const SizedBox(height: 12),
                      const Text(
                        'No donations yet',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your donation records will appear here',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }

            final donations = snapshot.data!.docs;
            return Column(
              children: donations.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final bloodType = data['bloodType'] ?? 'N/A';
                final notes = data['notes'] ?? '';
                final timestamp = data['date'];
                String dateStr = 'Unknown date';
                if (timestamp != null) {
                  final date = timestamp is Timestamp
                      ? timestamp.toDate()
                      : DateTime.fromMillisecondsSinceEpoch(
                          timestamp is int ? timestamp : 0);
                  dateStr = DateFormat('MMM d, yyyy').format(date);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFE11D48).withOpacity(0.2),
                              const Color(0xFFE11D48).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            bloodType,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blood Donation — $bloodType',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notes.isNotEmpty ? notes : 'Donated successfully',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
