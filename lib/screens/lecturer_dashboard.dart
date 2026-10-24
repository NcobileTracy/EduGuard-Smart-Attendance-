import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/button.dart';
import 'session_register.dart';
import 'attendance_history.dart';

class LecturerDashboard extends StatefulWidget {
  final Function(String?)? onModuleSelected;
  const LecturerDashboard({super.key, this.onModuleSelected});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  String? _selectedModule;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("EduGuard Lecturer"),
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
          String userName = userData['name'] ?? user?.email?.split('@')[0] ?? "Lecturer";
          List<String> modules = List<String>.from(userData['modules'] ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                        "Welcome Back,",
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
                      const Text(
                        "Ready to take attendance?",
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                
                const Text(
                  "Create A Session",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),

                if (modules.isEmpty)
                  _buildEmptyModulesCard()
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Select Active Module",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(Icons.book, color: Theme.of(context).colorScheme.primary),
                        ),
                        initialValue: modules.contains(_selectedModule) ? _selectedModule : null,
                        items: modules.map((String module) {
                          return DropdownMenuItem<String>(
                            value: module,
                            child: Text(module),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedModule = newValue;
                          });
                          if (widget.onModuleSelected != null) {
                            widget.onModuleSelected!(newValue);
                          }
                        },
                      ),
                      
                      const SizedBox(height: 25),
                      
                      _buildActionCard(
                        context,
                        "Generate Attendance QR",
                        "Create a new QR code for students to scan for the selected module.",
                        Icons.qr_code_2,
                        _selectedModule == null ? null : () {
                          Navigator.pushNamed(context, '/generate', arguments: _selectedModule);
                        },
                      ),
                      
                      const SizedBox(height: 15),
                      
                      _buildActionCard(
                        context,
                        "View Today's Registry",
                        "Check who has signed in for today's session.",
                        Icons.list_alt,
                        _selectedModule == null ? null : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SessionRegisterScreen(moduleName: _selectedModule!),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildActionCard(
                        context,
                        "All Session History",
                        "View a historical log of all sessions you have created.",
                        Icons.history,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AttendanceHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                
                if (_selectedModule == null && modules.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "Please select a module to enable actions",
                        style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyModulesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 50, color: Colors.orange),
            const SizedBox(height: 15),
            const Text(
              "No Modules Found",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "You haven't added any modules to your profile yet. Add modules to start generating QR codes.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: "Go to Profile",
              onPressed: () => Navigator.pushNamed(context, '/lecturer-profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback? onTap) {
    final bool isEnabled = onTap != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: Card(
        elevation: isEnabled ? 2 : 0,
        color: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
