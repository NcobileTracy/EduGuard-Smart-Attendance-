import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../widgets/textfield.dart';
import '../widgets/button.dart';
import '../utils/university_data.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _studentNumberController = TextEditingController();
  final TextEditingController _emailPrefixController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  String _gender = "Male";
  String? _selectedFaculty;
  String? _selectedSchool;
  String? _selectedCourse;
  bool _isLoading = false;
  String _lastEmailValue = "";

  @override
  void initState() {
    super.initState();
    _emailPrefixController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    String text = _emailPrefixController.text;
    if (text.length == 9 && _lastEmailValue.length == 8 && RegExp(r'^\d{9}$').hasMatch(text)) {
      _emailPrefixController.value = TextEditingValue(
        text: "$text@ump.ac.za",
        selection: TextSelection.collapsed(offset: "$text@ump.ac.za".length),
      );
    }
    _lastEmailValue = _emailPrefixController.text;
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final surname = _surnameController.text.trim();
    final studentNumber = _studentNumberController.text.trim();
    final emailInput = _emailPrefixController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || surname.isEmpty || studentNumber.isEmpty || 
        emailInput.isEmpty || password.isEmpty || _selectedFaculty == null || 
        _selectedSchool == null || _selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields including Course")),
      );
      return;
    }

    if (studentNumber.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Student number must be exactly 9 digits")),
      );
      return;
    }

    final fullEmail = emailInput.contains('@') ? emailInput : "$emailInput@ump.ac.za";

    setState(() => _isLoading = true);

    try {
      // Improvement 3: Device Binding (Capture unique device ID)
      String? deviceId;
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      try {
        if (kIsWeb) {
          var webInfo = await deviceInfo.webBrowserInfo;
          deviceId = "${webInfo.vendor}_${webInfo.userAgent}";
        } else if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id; 
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor;
        }
      } catch (e) {
        debugPrint("Could not get device ID: $e");
      }

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: fullEmail, password: password);

      // Send Email Verification
      await userCredential.user!.sendEmailVerification();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': name,
        'surname': surname,
        'gender': _gender,
        'studentNumber': studentNumber,
        'email': fullEmail,
        'role': "Student",
        'uid': userCredential.user!.uid,
        'faculty': _selectedFaculty,
        'school': _selectedSchool,
        'course': _selectedCourse,
        'enrolledModules': [],
        'deviceId': deviceId, // Bind account to this device
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Verify Your Email"),
            content: Text("A verification email has been sent to $fullEmail. Please verify your email before logging in."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Registration Failed")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailPrefixController.removeListener(_onEmailChanged);
    _nameController.dispose();
    _surnameController.dispose();
    _studentNumberController.dispose();
    _emailPrefixController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> faculties = universityData.keys.toList();
    List<String> schools = _selectedFaculty != null ? universityData[_selectedFaculty]!.keys.toList() : [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Student Registration"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: const Center(
                child: Text(
                  "Create Your Account",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  CustomTextField(
                    label: "First Name", 
                    controller: _nameController,
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    label: "Surname", 
                    controller: _surnameController,
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _gender,
                          items: ["Male", "Female", "Other"]
                              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) setState(() => _gender = value);
                          },
                          decoration: const InputDecoration(
                            labelText: "Gender",
                            prefixIcon: Icon(Icons.wc, color: Color(0xFF1A237E)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: CustomTextField(
                          label: "Student No.", 
                          controller: _studentNumberController,
                          prefixIcon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          maxLength: 9,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFaculty,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Faculty",
                      prefixIcon: Icon(Icons.account_balance, color: Color(0xFF1A237E)),
                    ),
                    items: faculties.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() { 
                      _selectedFaculty = val; 
                      _selectedSchool = null; 
                      _selectedCourse = null;
                    }),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSchool,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "School",
                      prefixIcon: Icon(Icons.school, color: Color(0xFF1A237E)),
                    ),
                    items: schools.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() { 
                      _selectedSchool = val;
                      _selectedCourse = null;
                    }),
                  ),
                  const SizedBox(height: 15),
                  if (_selectedSchool != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('courses_list')
                          .where('school', isEqualTo: _selectedSchool).snapshots(),
                      builder: (context, snapshot) {
                        List<String> courses = [];
                        if (_selectedFaculty != null && _selectedSchool != null) {
                          courses.addAll(universityData[_selectedFaculty]![_selectedSchool]!);
                        }
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            courses.add(doc['courseName']);
                          }
                        }
                        courses = courses.toSet().toList();

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCourse,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: "Course",
                            prefixIcon: Icon(Icons.book, color: Color(0xFF1A237E)),
                          ),
                          items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (val) => setState(() => _selectedCourse = val),
                        );
                      },
                    ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    label: "Student Number / Email",
                    controller: _emailPrefixController,
                    prefixIcon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    label: "Password",
                    isPassword: true,
                    controller: _passwordController,
                    prefixIcon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : CustomButton(
                          text: "REGISTER AS STUDENT",
                          onPressed: _register,
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
