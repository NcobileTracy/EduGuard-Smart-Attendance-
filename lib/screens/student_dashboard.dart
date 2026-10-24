import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class StudentDashboard extends StatefulWidget {
  final VoidCallback? onGoToProfile;
  const StudentDashboard({super.key, this.onGoToProfile});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh the dashboard every minute to remove expired sessions
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("EduGuard Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          String userName = userData['name'] ?? user?.email?.split('@')[0] ?? "Student";
          List<String> enrolledModules = List<String>.from(userData['enrolledModules'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome back,",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Student Number: ${userData['studentNumber'] ?? 'N/A'}",
                        style: const TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Active Sessions (FCM simulation)
                StreamBuilder<QuerySnapshot>(
                  stream: (() {
                    final now = DateTime.now();
                    final startOfToday = DateTime(now.year, now.month, now.day);
                    
                    return FirebaseFirestore.instance
                        .collection('sessions')
                        .where('courseName', whereIn: enrolledModules.isEmpty ? ['dummy'] : enrolledModules)
                        .where('isActive', isEqualTo: true)
                        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
                        .orderBy('createdAt', descending: true);
                  })().snapshots(),
                  builder: (context, sessionSnap) {
                    if (!sessionSnap.hasData || sessionSnap.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    // Filter out sessions that have expired locally
                    final now = DateTime.now();
                    final activeSessions = sessionSnap.data!.docs.where((doc) {
                      var session = doc.data() as Map<String, dynamic>;
                      Timestamp? expiresAt = session['expiresAt'];
                      if (expiresAt == null) return true;
                      return expiresAt.toDate().isAfter(now);
                    }).toList();

                    if (activeSessions.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sensors, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Live Sessions",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...activeSessions.map((doc) {
                          var session = doc.data() as Map<String, dynamic>;
                          Timestamp? expiresAt = session['expiresAt'];
                          String timeRemaining = "Active";
                          
                          if (expiresAt != null) {
                            final diff = expiresAt.toDate().difference(now);
                            if (diff.isNegative) {
                              timeRemaining = "Ending...";
                            } else {
                              timeRemaining = "${diff.inMinutes}m left";
                            }
                          }

                          return Card(
                            color: Colors.red[50],
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Icon(Icons.qr_code, color: Colors.white),
                              ),
                              title: Text(
                                session['courseName'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text("Session active. $timeRemaining"),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // This is a dashboard shortcut to scan
                                  // In StudentMainScreen, scan is index 1
                                  // This might need a better way to switch tabs but for now:
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Go to 'Scan QR' tab to mark attendance.")),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: const Text("JOIN"),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
                
                const Text(
                  "Overview",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        "Modules",
                        enrolledModules.length.toString(),
                        Icons.book,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('attendance')
                            .where('studentUid', isEqualTo: user?.uid)
                            .snapshots(),
                        builder: (context, attendanceSnap) {
                          final docs = attendanceSnap.data?.docs ?? [];
                          final int total = docs.length;
                          final int attended = docs.where((d) {
                            var data = d.data() as Map<String, dynamic>;
                            return data['status'] == 'Present' || data['status'] == 'Late';
                          }).length;
                          final double percent = total == 0 ? 0 : (attended / total) * 100;
                          
                          return _buildStatCard(
                            context,
                            "Attendance",
                            "${percent.toStringAsFixed(0)}%",
                            Icons.pie_chart,
                            percent > 75 ? Colors.green : (percent > 50 ? Colors.orange : Colors.red),
                            subtitle: "$attended/$total sessions",
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                
                const Text(
                  "Your Enrolled Modules",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                
                if (enrolledModules.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text(
                            "You are not enrolled in any modules yet.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: widget.onGoToProfile,
                            child: const Text("Go to Profile to Enroll"),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: enrolledModules.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            child: Icon(Icons.class_, color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(
                            enrolledModules[index],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text("Academic Year 2026"),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Could show module specific history
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
