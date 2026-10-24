import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/button.dart';
import '../services/notification_service.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  bool _isLoading = false;
  List<String> _enrolledModules = [];
  List<String> _availableModules = [];
  
  String? _studentNumber;
  String? _gender;
  String? _faculty;
  String? _school;
  String? _course;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (user == null) return;
    setState(() => _isLoading = true);

    try {
      // 1. Load Student Profile
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (studentDoc.exists) {
        Map<String, dynamic> data = studentDoc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? "";
          _surnameController.text = data['surname'] ?? "";
          _studentNumber = data['studentNumber'] ?? "N/A";
          _gender = data['gender'] ?? "N/A";
          _faculty = data['faculty'] ?? "N/A";
          _school = data['school'] ?? "N/A";
          _course = data['course'] ?? "N/A";
          _enrolledModules = List<String>.from(data['enrolledModules'] ?? []);
        });
      }

      // 2. Load ALL Available Modules from central list
      QuerySnapshot moduleQuery = await FirebaseFirestore.instance
          .collection('modules_list')
          .get();

      Set<String> allModules = {};
      for (var doc in moduleQuery.docs) {
        var data = doc.data() as Map<String, dynamic>;
        var moduleName = data['moduleName'];
        if (moduleName != null) {
          allModules.add(moduleName.toString());
        }
      }

      setState(() {
        _availableModules = allModules.toList();
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
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
        'enrolledModules': _enrolledModules,
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

  void _toggleEnrollment(String module) {
    setState(() {
      if (_enrolledModules.contains(module)) {
        _enrolledModules.remove(module);
        NotificationService.unsubscribeFromModule(module);
      } else {
        _enrolledModules.add(module);
        NotificationService.subscribeToModule(module);
      }
    });
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
      appBar: AppBar(title: const Text("My Profile")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.primary),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  const Text(
                    "Personal Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                          initialValue: _gender == "N/A" ? null : _gender,
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
                  _buildReadOnlyField("Student Number", _studentNumber ?? "N/A", Icons.badge_outlined),
                  const SizedBox(height: 15),
                  _buildReadOnlyField("Email Address", user?.email ?? "N/A", Icons.email_outlined),
                  
                  const SizedBox(height: 30),
                  
                  const Text(
                    "Academic Information",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildReadOnlyField("Faculty", _faculty ?? "N/A", Icons.account_balance_outlined),
                  const SizedBox(height: 10),
                  _buildReadOnlyField("School", _school ?? "N/A", Icons.school_outlined),
                  const SizedBox(height: 10),
                  _buildReadOnlyField("Course", _course ?? "N/A", Icons.book_outlined),
                  
                  const SizedBox(height: 30),
                  
                  const Text(
                    "My Enrollments",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Select modules to appear on your dashboard",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  
                  _availableModules.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text("No modules available in the system yet."),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _availableModules.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final module = _availableModules[index];
                              final isEnrolled = _enrolledModules.contains(module);
                              return CheckboxListTile(
                                activeColor: Theme.of(context).colorScheme.primary,
                                title: Text(module, style: const TextStyle(fontSize: 15)),
                                value: isEnrolled,
                                onChanged: (bool? value) => _toggleEnrollment(module),
                                controlAffinity: ListTileControlAffinity.trailing,
                              );
                            },
                          ),
                        ),
                  
                  const SizedBox(height: 40),
                  CustomButton(
                    text: "Save Profile Changes",
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
