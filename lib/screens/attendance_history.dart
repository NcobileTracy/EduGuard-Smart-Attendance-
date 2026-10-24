import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  final String? moduleName; 
  final String? studentUid;

  const AttendanceHistoryScreen({super.key, this.moduleName, this.studentUid});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    // If studentUid is passed, we are viewing a specific student's history (Admin view)
    // If moduleName is passed, we are viewing a specific module's history (Lecturer view)
    // Otherwise, we are viewing the current user's (Student or Lecturer) own history.

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(moduleName != null ? "History: $moduleName" : "Attendance History"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: (studentUid == null && moduleName == null && currentUser != null)
            ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots()
            : null,
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return _buildEmptyState("Error loading profile details.");
          }

          String? userRole;
          List<String> userModules = [];

          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
            userRole = userData['role'];
            if (userRole == 'Lecturer') {
              userModules = List<String>.from(userData['modules'] ?? []);
            } else {
              userModules = List<String>.from(userData['enrolledModules'] ?? []);
            }
          }

          // Define the primary stream for sessions
          Query<Map<String, dynamic>> sessionsQuery = FirebaseFirestore.instance.collection('sessions');

          if (moduleName != null) {
            // Lecturer viewing a specific module's session list
            sessionsQuery = sessionsQuery.where('courseName', isEqualTo: moduleName);
          } else if (studentUid != null) {
            // Admin viewing a student - for now show all sessions where that student might have been
            // This logic is simplified to show all sessions, as we filter by attendance status below
          } else if (userRole == 'Lecturer') {
            // Lecturer viewing their own created sessions
            sessionsQuery = sessionsQuery.where('lecturerUid', isEqualTo: currentUser?.uid);
          } else if (userRole == 'Student') {
            // Student viewing sessions for modules they are enrolled in
            if (userModules.isEmpty) {
              return _buildEmptyState("You are not enrolled in any modules yet.");
            }
            sessionsQuery = sessionsQuery.where('courseName', whereIn: userModules);
          } else if (studentUid == null && moduleName == null) {
            // Default loading state for profile-based view
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
          }

          // Apply ordering
          try {
            sessionsQuery = sessionsQuery.orderBy('createdAt', descending: true);
          } catch (e) {
            debugPrint("Query build error: $e");
          }

          return StreamBuilder<QuerySnapshot>(
            stream: sessionsQuery.snapshots(),
            builder: (context, sessionSnapshot) {
              if (sessionSnapshot.hasError) {
                String errorMsg = sessionSnapshot.error.toString();
                if (errorMsg.contains("failed-precondition")) {
                  return _buildEmptyState("Database indexing in progress. Please try again in a minute.");
                }
                debugPrint("Firestore Query Error: ${sessionSnapshot.error}");
                return _buildEmptyState("Error loading history.");
              }

              if (sessionSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final sessions = sessionSnapshot.data?.docs ?? [];
              if (sessions.isEmpty) return _buildEmptyState("No sessions found.");

              // Secondary stream for attendance records
              Query<Map<String, dynamic>> attendanceQuery = FirebaseFirestore.instance.collection('attendance');
              if (moduleName != null) {
                // If lecturer is viewing module history, we don't necessarily filter by UID
                // But typically history is personal. Let's filter by studentUid if studentUid is provided
                if (studentUid != null) {
                  attendanceQuery = attendanceQuery.where('studentUid', isEqualTo: studentUid);
                }
              } else if (studentUid != null) {
                attendanceQuery = attendanceQuery.where('studentUid', isEqualTo: studentUid);
              } else if (userRole == 'Student') {
                attendanceQuery = attendanceQuery.where('studentUid', isEqualTo: currentUser?.uid);
              } else if (userRole == 'Lecturer') {
                // Lecturers don't have "attendance status" for their own sessions in the same way
                // They see "ACTIVE" or "CLOSED"
              }

              return StreamBuilder<QuerySnapshot>(
                stream: attendanceQuery.snapshots(),
                builder: (context, attendanceSnapshot) {
                  final attendanceDocs = attendanceSnapshot.data?.docs ?? [];
                  final statusMap = <String, String>{};

                  for (var doc in attendanceDocs) {
                    var data = doc.data() as Map<String, dynamic>;
                    String sId = data['sessionId'] ?? "";
                    if (sId.isNotEmpty) {
                      statusMap[sId] = data['status'] ?? "Present";
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      var sessionData = session.data() as Map<String, dynamic>;
                      final sessionId = session.id;
                      final createdAt = sessionData['createdAt'];
                      final date = createdAt is Timestamp ? createdAt.toDate() : DateTime.now();
                      
                      String status = statusMap[sessionId] ?? "?";
                      
                      // For lecturers viewing their own history, show session state
                      if (userRole == 'Lecturer' && moduleName == null) {
                        status = (sessionData['isActive'] ?? false) ? "ACTIVE" : "CLOSED";
                      }

                      Color statusColor = status == "Present" || status == "ACTIVE" ? Colors.green 
                          : (status == "Late" ? Colors.orange : (status == "CLOSED" ? Colors.blue : (status == "ABSENT" || status == "?" ? Colors.red : Colors.grey)));
                      
                      return _buildHistoryCard(
                        context,
                        title: sessionData['courseName'] ?? "Unknown Course",
                        subtitle: DateFormat('EEEE, dd MMMM yyyy - hh:mm a').format(date),
                        status: status == "?" ? "ABSENT" : status,
                        statusColor: statusColor,
                        icon: status == "Present" || status == "ACTIVE" ? Icons.check_circle 
                            : (status == "Late" ? Icons.access_time_filled : Icons.history),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, {required String title, required String subtitle, required String status, required Color statusColor, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(icon, color: statusColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
      ),
    );
  }
}
