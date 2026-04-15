import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'login_screen.dart';
import '../services/location_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLocationSharing = false;
  bool _isLoading = true;

  // Editable controllers
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _pastRecordsController = TextEditingController();
  final _nomineeController = TextEditingController();
  final _addressController = TextEditingController();
  String? _bloodGroup;

  bool _isEditing = false;
  bool _isSaving = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkServiceStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _allergiesController.dispose();
    _pastRecordsController.dispose();
    _nomineeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    if (mounted) setState(() => _isLocationSharing = isRunning);
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _userData = data;
        _phoneController.text = data['phone'] ?? '';
        _ageController.text = data['age'] ?? '';
        _weightController.text = data['weight'] ?? '';
        _allergiesController.text = data['allergies'] ?? '';
        _pastRecordsController.text = data['pastRecords'] ?? '';
        _nomineeController.text = data['nomineeDetails'] ?? '';
        _addressController.text = data['permanentAddress'] ?? '';
        _bloodGroup = data['bloodGroup'];
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'phone': _phoneController.text,
        'age': _ageController.text,
        'weight': _weightController.text,
        'allergies': _allergiesController.text,
        'pastRecords': _pastRecordsController.text,
        'nomineeDetails': _nomineeController.text,
        'permanentAddress': _addressController.text,
        'bloodGroup': _bloodGroup,
      });

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      }
    }
  }

  Future<void> _toggleLocationSharing(bool value) async {
    final service = FlutterBackgroundService();

    if (value) {
      await initializeService();
      service.startService();
    } else {
      service.invoke("stopService");
    }

    // Wait a moment for service to start/stop
    await Future.delayed(const Duration(milliseconds: 800));
    final isRunning = await service.isRunning();
    if (mounted) setState(() => _isLocationSharing = isRunning);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.8,
            colors: [Color(0xFF1A1A22), Color(0xFF0A0A0C)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ─── App Bar ───
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      floating: true,
                      elevation: 0,
                      toolbarHeight: 60,
                      title: const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      actions: [
                        if (!_isEditing)
                          TextButton.icon(
                            icon: const Icon(Icons.edit_outlined,
                                color: Color(0xFFE11D48), size: 18),
                            label: const Text(
                              'Edit',
                              style: TextStyle(
                                  color: Color(0xFFE11D48),
                                  fontWeight: FontWeight.w600),
                            ),
                            onPressed: () =>
                                setState(() => _isEditing = true),
                          )
                        else
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  _loadUserData();
                                  setState(() => _isEditing = false);
                                },
                                child: const Text('Cancel',
                                    style: TextStyle(color: Colors.white38)),
                              ),
                              _isSaving
                                  ? const Padding(
                                      padding: EdgeInsets.only(right: 16),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFE11D48),
                                        ),
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: _saveProfile,
                                      child: const Text(
                                        'Save',
                                        style: TextStyle(
                                          color: Color(0xFFE11D48),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                      ],
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Profile Header ──
                          _buildProfileHeader(user),
                          const SizedBox(height: 28),

                          // ── Location Sharing Toggle ──
                          _buildLocationToggle(),
                          const SizedBox(height: 24),

                          // ── Editable Fields ──
                          _buildSectionTitle('Personal Information'),
                          const SizedBox(height: 14),
                          _buildEditableField(
                            icon: Icons.phone_outlined,
                            label: 'Phone Number',
                            controller: _phoneController,
                            keyboard: TextInputType.phone,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEditableField(
                                  icon: Icons.cake_outlined,
                                  label: 'Age',
                                  controller: _ageController,
                                  keyboard: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEditableField(
                                  icon: Icons.monitor_weight_outlined,
                                  label: 'Weight',
                                  controller: _weightController,
                                  keyboard: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          _buildBloodGroupField(),
                          _buildEditableField(
                            icon: Icons.warning_amber_rounded,
                            label: 'Allergies',
                            controller: _allergiesController,
                          ),
                          _buildEditableField(
                            icon: Icons.medical_services_outlined,
                            label: 'Past Medical Records',
                            controller: _pastRecordsController,
                          ),
                          _buildEditableField(
                            icon: Icons.contact_emergency,
                            label: 'Emergency Nominee',
                            controller: _nomineeController,
                          ),
                          _buildEditableField(
                            icon: Icons.home_outlined,
                            label: 'Permanent Address',
                            controller: _addressController,
                          ),

                          const SizedBox(height: 32),

                          // ── Logout ──
                          _buildLogoutButton(),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE11D48).withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF1E1E24),
              backgroundImage: user?.photoURL != null
                  ? CachedNetworkImageProvider(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person, color: Colors.white38, size: 40)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.displayName ?? 'User',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 14,
            ),
          ),
          if (_bloodGroup != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE11D48).withOpacity(0.25),
                ),
              ),
              child: Text(
                'Blood Type: $_bloodGroup',
                style: const TextStyle(
                  color: Color(0xFFE11D48),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationToggle() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _isLocationSharing
            ? LinearGradient(
                colors: [
                  const Color(0xFFE11D48).withOpacity(0.1),
                  const Color(0xFF1E1E24).withOpacity(0.6),
                ],
              )
            : null,
        color: _isLocationSharing ? null : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isLocationSharing
              ? const Color(0xFFE11D48).withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isLocationSharing
                  ? const Color(0xFFE11D48).withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isLocationSharing
                  ? Icons.satellite_alt_rounded
                  : Icons.location_off_outlined,
              color: _isLocationSharing
                  ? const Color(0xFFE11D48)
                  : Colors.white38,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location Sharing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isLocationSharing
                      ? 'Your location is visible to hospitals'
                      : 'You are invisible to emergency scans',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isLocationSharing,
            onChanged: _toggleLocationSharing,
            activeColor: const Color(0xFFE11D48),
            activeTrackColor: const Color(0xFFE11D48).withOpacity(0.3),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            inactiveThumbColor: Colors.white38,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isEditing
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: TextFormField(
              controller: controller,
              readOnly: !_isEditing,
              keyboardType: keyboard,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isEditing
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.bloodtype, color: Colors.white24, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: _isEditing
                ? DropdownButtonFormField<String>(
                    value: _bloodGroup,
                    dropdownColor: const Color(0xFF1E1E24),
                    icon: const Icon(Icons.arrow_drop_down,
                        color: Color(0xFFE11D48)),
                    items: _bloodGroups
                        .map((bg) => DropdownMenuItem(
                              value: bg,
                              child: Text(bg,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _bloodGroup = val),
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      labelStyle:
                          TextStyle(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Blood Group',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _bloodGroup ?? 'N/A',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextButton.icon(
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 20),
        label: const Text(
          'Sign Out',
          style: TextStyle(
            color: Color(0xFFE11D48),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () async {
          FlutterBackgroundService().invoke("stopService");
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        },
      ),
    );
  }
}
