import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/textfield.dart';
import '../widgets/button.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;
  String _lastEmailValue = "";

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    String text = _emailController.text;
    if (text.length == 9 && _lastEmailValue.length == 8 && RegExp(r'^\d{9}$').hasMatch(text)) {
      _emailController.value = TextEditingValue(
        text: "$text@ump.ac.za",
        selection: TextSelection.collapsed(offset: "$text@ump.ac.za".length),
      );
    }
    _lastEmailValue = _emailController.text;
  }

  Future<String?> _getDeviceId() async {
    var deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      var webInfo = await deviceInfo.webBrowserInfo;
      return "${webInfo.vendor}_${webInfo.userAgent}"; // Browser "fingerprint"
    }
    
    if (Platform.isIOS) {
      var iosDeviceInfo = await deviceInfo.iosInfo;
      return iosDeviceInfo.identifierForVendor;
    } else if (Platform.isAndroid) {
      var androidDeviceInfo = await deviceInfo.androidInfo;
      return androidDeviceInfo.id;
    }
    return null;
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _statusMessage = null;
    });

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = "Please fill in all fields";
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user != null) {
        await user.reload();
        if (!user.emailVerified) {
          await user.sendEmailVerification();
          await FirebaseAuth.instance.signOut();
          setState(() {
            _statusMessage = "Email not verified. A new verification link has been sent. Please check your inbox.";
            _isSuccess = false;
          });
          return;
        }
      }

      String uid = user!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (mounted) {
        if (userDoc.exists) {
          var userData = userDoc.data() as Map<String, dynamic>;
          String role = userData['role'] ?? "Student";
          
          if (role == "Student") {
            String? currentDeviceId = await _getDeviceId();
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            
            if (userData.containsKey('deviceId') && userData['deviceId'] != null && userData['deviceId'] != "") {
              if (userData['deviceId'] != currentDeviceId) {
                // Device mismatch
                await FirebaseAuth.instance.signOut();
                setState(() {
                  _statusMessage = "Device mismatch! This account is bound to another device. Please contact your Admin.";
                  _isSuccess = false;
                });
                return;
              }
            } else {
              // First login or device not bound yet, bind it now
              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                'deviceId': currentDeviceId,
                'lastLogin': FieldValue.serverTimestamp(),
              });
            }
            if (!mounted) return;
            // Ensure student is subscribed to their module notifications
            if (userData.containsKey('enrolledModules')) {
              NotificationService.subscribeToAll(List<String>.from(userData['enrolledModules']));
            }
            Navigator.pushReplacementNamed(context, '/student');
          } else if (role == "Lecturer") {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/lecturer');
          } else if (role == "Admin") {
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, '/admin');
          }
        } else {
          setState(() {
            _statusMessage = "User data not found in Firestore.";
            _isSuccess = false;
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = e.message ?? "Login Failed";
          _isSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error: $e";
          _isSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _statusMessage = "Enter email above to reset password";
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _statusMessage = "Reset link sent! Check your email.";
        _isSuccess = true;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _statusMessage = e.message;
        _isSuccess = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top Background Gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // App Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "EduGuard",
                    style: TextStyle(
                      fontSize: 36, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                      letterSpacing: 1.2
                    ),
                  ),
                  const Text(
                    "Smart Attendance System",
                    style: TextStyle(
                      fontSize: 14, 
                      color: Colors.white70,
                      fontWeight: FontWeight.w300
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // Login Card
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Welcome Back",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 30),
                        CustomTextField(
                          label: "School Email",
                          controller: _emailController,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          label: "Password",
                          isPassword: true,
                          controller: _passwordController,
                          prefixIcon: Icons.lock_outline,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _resetPassword,
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : CustomButton(
                                text: "LOGIN",
                                onPressed: _login,
                              ),
                        
                        // Status Message
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 15),
                          Text(
                            _statusMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isSuccess ? Colors.green : Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                              children: [
                                const TextSpan(text: "Don't have an account? "),
                                TextSpan(
                                  text: "Register",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "UMP Student Attendance",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
