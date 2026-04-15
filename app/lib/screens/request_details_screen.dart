import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const RequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  StreamSubscription? _statusSub;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _listenForCancellation();
  }

  void _listenForCancellation() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _statusSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((docSnap) {
      if (docSnap.exists) {
        final status = docSnap.data()?['status'];
        if (status == 'cancelled') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This emergency request was fulfilled by someone else!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _handleDecision(String statusValue) async {
    setState(() => _isProcessing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('requests')
            .doc(widget.requestId)
            .update({'status': statusValue});
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE11D48), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isHighlight ? const Color(0xFFE11D48) : Colors.white,
                fontSize: 14,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.requestData;
    final patientName = d['patientName'] ?? 'Unknown Patient';
    final patientAge = d['patientAge']?.toString() ?? 'N/A';
    final bloodType = d['bloodType'] ?? 'Unknown Blood';
    final conditions = d['conditions'] ?? 'None specified';
    final contactNominee = d['contactNominee'] ?? 'Not provided';

    final hospitalName = d['hospitalName'] ?? 'Emergency Facility';
    final hospitalAddress = d['hospitalAddress'] ?? 'Location verified on map';
    final distanceKM = d['distanceKM'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Emergency Request Details', style: TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emergency_share_rounded, size: 48, color: Color(0xFFE11D48)),
                      const SizedBox(height: 12),
                      const Text('TARGET BLOOD MATCH', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text(bloodType, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // Patient Details Card
                _buildSectionHeader('Patient Data', Icons.person_outline),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Patient Name', patientName),
                      _buildDetailRow('Age', patientAge),
                      _buildDetailRow('Target Blood', bloodType, isHighlight: true),
                      _buildDetailRow('Conditions', conditions),
                      _buildDetailRow('Contact Nominee', contactNominee),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Hospital Details Card
                _buildSectionHeader('Facility Details', Icons.local_hospital_outlined),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Hospital Name', hospitalName),
                      _buildDetailRow('Distance', '$distanceKM km away', isHighlight: true),
                      _buildDetailRow('Address', hospitalAddress),
                    ],
                  ),
                ),
                
                const SizedBox(height: 100), // padding for bottom bar
              ],
            ),
          ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF121214),
          border: const Border(top: BorderSide(color: Color(0xFF1E1E24))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isProcessing ? null : () => _handleDecision('rejected'),
                  child: const Text('DECLINE', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: const Color(0xFFE11D48).withOpacity(0.5),
                  ),
                  onPressed: _isProcessing ? null : () => _handleDecision('acknowledged'),
                  child: const Text('ACCEPT & HELP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
