import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/button.dart';

class LecturerProfileScreen extends StatefulWidget {
  const LecturerProfileScreen({super.key});

  @override
  State<LecturerProfileScreen> createState() => _LecturerProfileScreenState();
}

class _LecturerProfileScreenState extends State<LecturerProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  bool _isLoading = false;
  List<String> _modules = [];
  
  String? _gender;
  String? _faculty;
  String? _school;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (user == null) return;
    setState(() => _isLoading = true);
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? "";
          _surnameController.text = data['surname'] ?? "";
          _gender = data['gender'];
          _faculty = data['faculty'];
          _school = data['school'];
          _modules = List<String>.from(data['modules'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': _nameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'gender': _gender,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating profile: $e")),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Lecturer Profile")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.work, size: 50, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 30),
                
                const Text("Personal Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "First Name",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _surnameController,
                  decoration: const InputDecoration(
                    labelText: "Surname",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: "Gender",
                          prefixIcon: Icon(Icons.wc),
                        ),
                        items: ["Male", "Female", "Other"]
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) => setState(() => _gender = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildReadOnlyField("Email Address", user?.email ?? "N/A", Icons.email_outlined),
                const SizedBox(height: 15),
                _buildReadOnlyField("Faculty", _faculty ?? "N/A", Icons.account_balance_outlined),
                const SizedBox(height: 15),
                _buildReadOnlyField("School", _school ?? "N/A", Icons.school_outlined),
                
                const SizedBox(height: 30),
                const Text("Assigned Modules", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("Modules assigned by university administration", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 15),
                
                if (_modules.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No modules assigned yet.", style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _modules.map((module) => Chip(
                      label: Text(module),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    )).toList(),
                  ),
                
                const SizedBox(height: 40),
                CustomButton(
                  text: "Save Personal Info",
                  onPressed: _updateProfile,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
