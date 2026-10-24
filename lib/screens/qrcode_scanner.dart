import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import '../services/time_service.dart';

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  bool _isScanned = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _authenticateStudent();
  }

  // Improvement 4: Biometric Verification
  Future<void> _authenticateStudent() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) return;

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to mark your attendance',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!didAuthenticate && mounted) {
        Navigator.pop(context); // Close scanner if auth fails
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
    }
  }

  Future<void> _processQR(String rawData) async {
    if (_isScanned) return;
    setState(() => _isScanned = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Improvement 2: Dynamic QR Parsing
      // Format: session_ID_TIMESTAMP_TIMEBLOCK
      final parts = rawData.split('_');
      if (parts.length < 4) throw Exception("Invalid QR format");
      
      final sessionId = "${parts[0]}_${parts[1]}_${parts[2]}";
      final scannedTimeBlock = int.tryParse(parts[3]) ?? 0;
      
      // Use synchronized network time to prevent cheating
      final currentTimeBlock = (TimeService.now.millisecondsSinceEpoch / 60000).floor();

      // Allow 1 block of drift (1 minute)
      if ((currentTimeBlock - scannedTimeBlock).abs() > 1) {
        throw Exception("QR code expired. Please scan the latest one.");
      }

      // 1. Fetch Session details
      DocumentSnapshot sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists) {
        throw Exception("Session no longer exists");
      }

      var sessionData = sessionDoc.data() as Map<String, dynamic>;
      
      // Improvement 5: Session Expiry/Active check
      if (!(sessionData['isActive'] ?? false)) {
        throw Exception("This session has been closed by the lecturer.");
      }

      // Improvement 1: Geofencing
      double lecturerLat = sessionData['latitude'];
      double lecturerLong = sessionData['longitude'];

      Position studentPos = await Geolocator.getCurrentPosition();
      double distanceInMeters = Geolocator.distanceBetween(
        studentPos.latitude,
        studentPos.longitude,
        lecturerLat,
        lecturerLong,
      );

      // Block if student is more than 100 meters away
      if (distanceInMeters > 100) {
        throw Exception("You are too far from the classroom (${distanceInMeters.toStringAsFixed(0)}m).");
      }

      String courseName = sessionData['courseName'] ?? "Unknown Course";
      Timestamp? createdAt = sessionData['createdAt'] as Timestamp?;

      // Fetch Student details for the record
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      var userData = userDoc.data() as Map<String, dynamic>? ?? {};

      // Determine status
      String status = "Present";
      if (createdAt != null) {
        DateTime sessionStartTime = createdAt.toDate();
        DateTime scanTime = DateTime.now();
        if (scanTime.difference(sessionStartTime).inMinutes > 15) {
          status = "Late";
        }
      }

      // 2. Register attendance (Use deterministic ID to prevent duplicates)
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc("${sessionId}_${user.uid}")
          .set({
        'sessionId': sessionId,
        'courseName': courseName,
        'studentUid': user.uid,
        'studentEmail': user.email,
        'studentName': "${userData['name'] ?? ''} ${userData['surname'] ?? ''}".trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': status,
        'distanceFromLecturer': distanceInMeters,
      }, SetOptions(merge: true)); // merge: true allows updating if they scan again without creating new docs

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Attendance Marked Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isScanned = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Attendance")),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  _processQR(code);
                }
              }
            },
          ),
          // Scanner Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Align QR Code within the frame",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isScanned)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
