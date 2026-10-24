import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/notification_service.dart';
import '../services/time_service.dart';
import 'dart:math';
import 'dart:async';

class GenerateQRScreen extends StatefulWidget {
  final String? moduleName;
  const GenerateQRScreen({super.key, this.moduleName});

  @override
  State<GenerateQRScreen> createState() => _GenerateQRScreenState();
}

class _GenerateQRScreenState extends State<GenerateQRScreen> {
  String? _qrData;
  bool _isGenerating = false;
  String? _selectedModule;
  Timer? _refreshTimer;
  Timer? _expiryTimer;
  String? _currentSessionId;
  Duration _sessionDuration = const Duration(minutes: 60);
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _selectedModule = widget.moduleName;
  }

  @override
  void didUpdateWidget(covariant GenerateQRScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.moduleName != oldWidget.moduleName) {
      setState(() {
        _selectedModule = widget.moduleName;
        // Optionally clear current session/QR if module changes
        if (_currentSessionId != null) {
          _stopSession();
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _generateSession() async {
    if (_selectedModule == null) return;

    setState(() => _isGenerating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Capture Lecturer's location for Geofencing
      Position? position = await _determinePosition();
      if (position == null) {
        throw Exception("Location services are required to start a session.");
      }

      // Generate a unique session ID
      final sessionId = "session_${Random().nextInt(999999)}_${DateTime.now().millisecondsSinceEpoch}";
      _currentSessionId = sessionId;

      // Create a session in Firestore
      final expiryTime = DateTime.now().add(_sessionDuration);
      await FirebaseFirestore.instance
          .collection('sessions')
          .doc(sessionId)
          .set({
        'sessionId': sessionId,
        'courseName': _selectedModule,
        'lecturerUid': user.uid,
        'lecturerEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiryTime),
        'isActive': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      // Trigger push notification
      await NotificationService.sendSessionNotification(
        moduleName: _selectedModule!,
        sessionId: sessionId,
      );

      _startDynamicQRUpdates();
      _startExpiryTimer();

      setState(() {
        _isGenerating = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to generate session: $e")),
        );
      }
      setState(() => _isGenerating = false);
    }
  }

  void _startDynamicQRUpdates() {
    _refreshTimer?.cancel();
    _updateQRData();
    // Refresh QR every 60 seconds to prevent sharing photos
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _updateQRData();
    });
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _secondsRemaining = _sessionDuration.inSeconds;
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _stopSession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Session expired and closed automatically.")),
          );
        }
      }
    });
  }

  void _updateQRData() {
    if (_currentSessionId == null) return;
    
    // QR data = sessionId + current 1 minute window timestamp
    // This makes the QR code change visually every minute
    final timeBlock = (TimeService.now.millisecondsSinceEpoch / 60000).floor();
    setState(() {
      _qrData = "${_currentSessionId}_$timeBlock";
    });
  }

  Future<void> _stopSession() async {
    if (_currentSessionId == null) return;
    
    // Close the session in Firestore
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(_currentSessionId)
        .update({'isActive': false});

    // Improvement 4: Absent Data Persistence
    // Write explicit 'Absent' records for everyone who didn't scan
    try {
      final sessionDoc = await FirebaseFirestore.instance.collection('sessions').doc(_currentSessionId).get();
      var sessionData = sessionDoc.data() as Map<String, dynamic>;
      final moduleName = sessionData['courseName'];

      // 1. Get all students enrolled in this module
      final studentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .where('enrolledModules', arrayContains: moduleName)
          .get();

      // 2. Get everyone who already has an attendance record for this session
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('sessionId', isEqualTo: _currentSessionId)
          .get();
      
      final presentUids = attendanceSnap.docs.map((d) {
        var data = d.data() as Map<String, dynamic>;
        return data['studentUid'];
      }).toSet();

      // 3. For each student not present, add an 'Absent' record
      final batch = FirebaseFirestore.instance.batch();
      for (var student in studentsSnap.docs) {
        var studentData = student.data() as Map<String, dynamic>;
        if (!presentUids.contains(student.id)) {
          final docRef = FirebaseFirestore.instance.collection('attendance').doc();
          batch.set(docRef, {
            'sessionId': _currentSessionId,
            'courseName': moduleName,
            'studentUid': student.id,
            'studentEmail': studentData['email'],
            'studentName': studentData['name'],
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'Absent',
          });
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error writing absent records: $e");
    }
    
    _refreshTimer?.cancel();
    _expiryTimer?.cancel();
    setState(() {
      _qrData = null;
      _currentSessionId = null;
      _secondsRemaining = 0;
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("Session QR Generator")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.book, color: Theme.of(context).colorScheme.primary, size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      "Selected Module",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      _selectedModule ?? 'None Selected',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              if (_qrData == null) ...[
                if (_selectedModule == null)
                  const Text(
                    "Please select a module from the Home tab first.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  )
                else
                  Column(
                    children: [
                      const Text("Session Duration:"),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text("15m"),
                            selected: _sessionDuration.inMinutes == 15,
                            onSelected: (val) => setState(() => _sessionDuration = const Duration(minutes: 15)),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text("30m"),
                            selected: _sessionDuration.inMinutes == 30,
                            onSelected: (val) => setState(() => _sessionDuration = const Duration(minutes: 30)),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text("60m"),
                            selected: _sessionDuration.inMinutes == 60,
                            onSelected: (val) => setState(() => _sessionDuration = const Duration(minutes: 60)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _isGenerating 
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: _generateSession,
                              icon: const Icon(Icons.qr_code),
                              label: const Text("Start Session & Generate QR"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                            ),
                          ),
                    ],
                  ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Time Remaining: ${_formatTime(_secondsRemaining)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Scan this code to mark attendance:",
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Code expires every minute",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 220.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text("Session ID: ${_currentSessionId?.split('_')[1]}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _stopSession,
                    icon: const Icon(Icons.stop_circle, color: Colors.red),
                    label: const Text("Stop & Close Session", style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    ));
  }
}
