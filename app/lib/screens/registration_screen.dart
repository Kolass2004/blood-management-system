import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _pastRecordsController = TextEditingController();
  final _nomineeController = TextEditingController();
  final _addressController = TextEditingController();
  String? _bloodGroup;
  
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  bool _isLoading = false;

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _bloodGroup != null) {
      setState(() => _isLoading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName,
          'email': user.email,
          'phone': _phoneController.text,
          'bloodGroup': _bloodGroup,
          'allergies': _allergiesController.text,
          'pastRecords': _pastRecordsController.text,
          'nomineeDetails': _nomineeController.text,
          'permanentAddress': _addressController.text,
          'createdAt': FieldValue.serverTimestamp(),
          'location': null,
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
      
      setState(() => _isLoading = false);
    } else if (_bloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a blood group')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        title: const Text('Node Initialization', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF1E1E24), Color(0xFF0A0A0C)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Complete your biometric footprint.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  _buildInputField('Phone Number', Icons.phone, _phoneController, isRequired: true, keyboard: TextInputType.phone),
                  const SizedBox(height: 16),
                  
                  // Custom Dropdown
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _bloodGroup,
                        dropdownColor: const Color(0xFF1E1E24),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE11D48)),
                        items: _bloodGroups.map((bg) => DropdownMenuItem(
                          value: bg, 
                          child: Text(bg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        )).toList(),
                        onChanged: (val) => setState(() => _bloodGroup = val),
                        decoration: const InputDecoration(
                          labelText: 'Blood Group Type *',
                          labelStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.bloodtype, color: Colors.white54),
                        ),
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInputField('Allergies (if any)', Icons.warning_amber, _allergiesController),
                  const SizedBox(height: 16),
                  
                  _buildInputField('Past Medical Records', Icons.medical_services_outlined, _pastRecordsController),
                  const SizedBox(height: 16),
                  
                  _buildInputField('Emergency Nominee Details', Icons.contact_emergency, _nomineeController, isRequired: true),
                  const SizedBox(height: 16),
                  
                  _buildInputField('Permanent Address', Icons.home_outlined, _addressController, isRequired: true),
                  const SizedBox(height: 40),
                  
                  _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48)))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFFE11D48).withOpacity(0.5),
                        ),
                        onPressed: _submitForm,
                        child: const Text('ACTIVATE GRID PROFILE', style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.2,
                          color: Colors.white
                        )),
                      )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, IconData icon, TextEditingController controller, {bool isRequired = false, TextInputType keyboard = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          labelStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: Icon(icon, color: Colors.white54),
        ),
        validator: (val) => isRequired && (val == null || val.isEmpty) ? 'Required' : null,
      ),
    );
  }
}
