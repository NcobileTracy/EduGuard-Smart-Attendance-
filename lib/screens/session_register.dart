import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import '../utils/pdf_helper.dart';

class SessionRegisterScreen extends StatefulWidget {
  final String moduleName;
  final String? sessionId;

  const SessionRegisterScreen({super.key, required this.moduleName, this.sessionId});

  @override
  State<SessionRegisterScreen> createState() => _SessionRegisterScreenState();
}

class _SessionRegisterScreenState extends State<SessionRegisterScreen> {
  String? _activeSessionId;
  DateTime? _sessionDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _activeSessionId = widget.sessionId;
    _initialize();
  }

  Future<void> _initialize() async {
    if (_activeSessionId == null) {
      // Find the latest session for this module
      final sessionSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .where('courseName', isEqualTo: widget.moduleName)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (sessionSnap.docs.isNotEmpty) {
        _activeSessionId = sessionSnap.docs.first.id;
        var data = sessionSnap.docs.first.data() as Map<String, dynamic>;
        _sessionDate = (data['createdAt'] as Timestamp?)?.toDate();
      }
    } else {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc(_activeSessionId)
          .get();
      if (sessionDoc.exists) {
        var data = sessionDoc.data() as Map<String, dynamic>;
        _sessionDate = (data['createdAt'] as Timestamp?)?.toDate();
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportRegistryToCSV(List<QueryDocumentSnapshot> students, Map<String, String> attendanceMap) async {
    try {
      List<List<dynamic>> rows = [];
      // Header
      rows.add([
        "Student Number",
        "Full Name",
        "Email",
        "Status",
        "Session Date",
        "Module"
      ]);

      String formattedSessionDate = _sessionDate != null 
          ? DateFormat('yyyy-MM-dd HH:mm').format(_sessionDate!) 
          : "N/A";

      for (var student in students) {
        var studentData = student.data() as Map<String, dynamic>;
        String status = attendanceMap[student.id] ?? '?';
        rows.add([
          studentData['studentNumber'] ?? "N/A",
          "${studentData['name'] ?? ''} ${studentData['surname'] ?? ''}",
          studentData['email'] ?? "N/A",
          status == '?' ? "Absent" : status,
          formattedSessionDate,
          widget.moduleName
        ]);
      }

      String csvData = csv.encode(rows);
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/register_${widget.moduleName}_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Session Register for ${widget.moduleName}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export Error: $e")),
      );
    }
  }

  Future<void> _exportRegistryToPDF(List<QueryDocumentSnapshot> students, Map<String, String> attendanceMap) async {
    try {
      List<List<String>> data = [];
      for (var student in students) {
        var studentData = student.data() as Map<String, dynamic>;
        String status = attendanceMap[student.id] ?? '?';
        data.add([
          studentData['studentNumber'] ?? "N/A",
          "${studentData['name'] ?? ''} ${studentData['surname'] ?? ''}",
          status == '?' ? "Absent" : status,
        ]);
      }

      await PdfHelper.generateAttendanceReport(
        title: "Session Register",
        subtitle: "Module: ${widget.moduleName} | Date: ${_sessionDate != null ? DateFormat('yyyy-MM-dd').format(_sessionDate!) : 'N/A'}",
        headers: ["Student No", "Name", "Status"],
        data: data,
      );
    } catch (e) {
      debugPrint("Registry PDF Error: $e");
    }
  }

  Future<void> _markManually(String studentUid, String currentStatus) async {
    try {
      String newStatus = currentStatus == 'Present' ? 'Late' : (currentStatus == 'Late' ? '?' : 'Present');
      
      if (newStatus == '?') {
        // Remove attendance record
        final snap = await FirebaseFirestore.instance
            .collection('attendance')
            .where('sessionId', isEqualTo: _activeSessionId)
            .where('studentUid', isEqualTo: studentUid)
            .get();
        for (var doc in snap.docs) {
          await doc.reference.delete();
        }
      } else {
        // Update or add attendance record
        final snap = await FirebaseFirestore.instance
            .collection('attendance')
            .where('sessionId', isEqualTo: _activeSessionId)
            .where('studentUid', isEqualTo: studentUid)
            .get();

        if (snap.docs.isNotEmpty) {
          await snap.docs.first.reference.update({'status': newStatus});
        } else {
          // Get student details for the record
          final studentDoc = await FirebaseFirestore.instance.collection('users').doc(studentUid).get();
          var studentData = studentDoc.data() as Map<String, dynamic>? ?? {};
          await FirebaseFirestore.instance.collection('attendance').add({
            'sessionId': _activeSessionId,
            'courseName': widget.moduleName,
            'studentUid': studentUid,
            'studentEmail': studentData['email'] ?? "N/A",
            'studentName': studentData['name'] ?? "N/A",
            'timestamp': FieldValue.serverTimestamp(),
            'status': newStatus,
            'isManual': true,
          });
        }
      }
    } catch (e) {
      debugPrint("Manual Mark Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Register: ${widget.moduleName}")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeSessionId == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Register: ${widget.moduleName}")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_busy, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text("No sessions found for this module."),
              const SizedBox(height: 10),
              const Text("Generate a QR code to start a session."),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Go Back"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Register: ${widget.moduleName}", style: const TextStyle(fontSize: 16)),
            if (_sessionDate != null)
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(_sessionDate!),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'Student')
                .where('enrolledModules', arrayContains: widget.moduleName)
                .snapshots(),
            builder: (context, studentSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('sessionId', isEqualTo: _activeSessionId)
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  if (!studentSnapshot.hasData || !attendanceSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  
                  final attendanceMap = {
                    for (var doc in attendanceSnapshot.data!.docs)
                      (doc.data() as Map<String, dynamic>)['studentUid'] as String: 
                      (doc.data() as Map<String, dynamic>)['status'] as String
                  };

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf),
                        tooltip: "Export PDF",
                        onPressed: () => _exportRegistryToPDF(
                          studentSnapshot.data!.docs, 
                          attendanceMap
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        tooltip: "Export Register",
                        onPressed: () => _exportRegistryToCSV(
                          studentSnapshot.data!.docs, 
                          attendanceMap
                        ),
                      ),
                    ],
                  );
                }
              );
            }
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Get all students enrolled in this module
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Student')
            .where('enrolledModules', arrayContains: widget.moduleName)
            .snapshots(),
        builder: (context, studentSnapshot) {
          if (!studentSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final students = studentSnapshot.data!.docs;

          if (students.isEmpty) {
            return const Center(child: Text("No students enrolled in this module."));
          }

          return StreamBuilder<QuerySnapshot>(
            // Get attendance for this session
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('sessionId', isEqualTo: _activeSessionId)
                .snapshots(),
            builder: (context, attendanceSnapshot) {
              if (!attendanceSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              final attendanceMap = {
                for (var doc in attendanceSnapshot.data!.docs)
                  doc.get('studentUid'): doc.get('status') ?? 'Present'
              };

              // Sort students: Present first, then Late, then Absent
              final sortedStudents = List.from(students);
              sortedStudents.sort((a, b) {
                String statusA = attendanceMap[a.id] ?? 'Absent';
                String statusB = attendanceMap[b.id] ?? 'Absent';
                
                int rank(String s) {
                  if (s == 'Present') return 0;
                  if (s == 'Late') return 1;
                  return 2;
                }
                
                int cmp = rank(statusA).compareTo(rank(statusB));
                if (cmp != 0) return cmp;
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                return (dataA['name'] ?? '').compareTo(dataB['name'] ?? '');
              });

              int presentCount = attendanceMap.values.where((s) => s == 'Present').length;
              int lateCount = attendanceMap.values.where((s) => s == 'Late').length;
              int absentCount = students.length - attendanceMap.length;

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem("Present", presentCount, Colors.green),
                        _buildSummaryItem("Late", lateCount, Colors.orange),
                        _buildSummaryItem("Absent (?)", absentCount, Colors.red),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: sortedStudents.length,
                      itemBuilder: (context, index) {
                        var student = sortedStudents[index];
                        var studentData = student.data() as Map<String, dynamic>;
                        String status = attendanceMap[student.id] ?? '?';
                        Color statusColor = status == 'Present' 
                            ? Colors.green 
                            : (status == 'Late' ? Colors.orange : Colors.red);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withValues(alpha: 0.1),
                            child: Text(
                              (studentData['name']?[0] ?? '?').toUpperCase(),
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text("${studentData['name'] ?? ''} ${studentData['surname'] ?? ''}"),
                          subtitle: Text(studentData['studentNumber'] ?? studentData['email'] ?? "No Details"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _markManually(student.id, status),
                                tooltip: "Change Status",
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
