import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'admin_profile.dart';
import '../utils/pdf_helper.dart';
import '../widgets/textfield.dart';
import '../utils/university_data.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const AdminDashboard(),
      const ManageUsersScreen(),
      const AdminProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("EduGuard Admin"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, userSnap) {
          String adminName = "Admin";
          if (userSnap.hasData && userSnap.data!.exists) {
            var data = userSnap.data!.data() as Map<String, dynamic>;
            adminName = data['name'] ?? "Admin";
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              int studentCount = snapshot.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return data['role'] == 'Student';
              }).length;
              int lecturerCount = snapshot.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return data['role'] == 'Lecturer';
              }).length;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome, $adminName",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text(
                        "System Overview",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                      ),
                      SizedBox(height: 5),
                      const Text(
                        "Administrator",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "User Statistics",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context, 
                            "Students", 
                            studentCount.toString(), 
                            Icons.school, 
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildStatCard(
                            context, 
                            "Lecturers", 
                            lecturerCount.toString(), 
                            Icons.supervisor_account, 
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "Quick Actions",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    _buildQuickAction(
                      context,
                      "Manage Courses",
                      "Add/Remove academic courses",
                      Icons.school,
                      Colors.blue,
                      onTap: () => _showManageCoursesDialog(context),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickAction(
                      context,
                      "Manage Modules",
                      "Assign modules to courses",
                      Icons.library_books,
                      Colors.indigo,
                      onTap: () => _showManageModulesDialog(context),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickAction(
                      context,
                      "Device ID Reset",
                      "Reset student device binding",
                      Icons.phone_android,
                      Colors.orange,
                      onTap: () => _showResetDeviceDialog(context),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickAction(
                      context,
                      "System Health",
                      "All services operational",
                      Icons.check_circle,
                      Colors.teal,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showResetDeviceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ResetDeviceDialog(),
    );
  }

  void _showManageModulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ManageModulesDialog(),
    );
  }

  void _showManageCoursesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ManageCoursesDialog(),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 15),
          Text(
            count,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String title, String status, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(status, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class ResetDeviceDialog extends StatefulWidget {
  const ResetDeviceDialog({super.key});

  @override
  State<ResetDeviceDialog> createState() => _ResetDeviceDialogState();
}

class _ResetDeviceDialogState extends State<ResetDeviceDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Reset Device ID"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Allows a student to log in from a new device by clearing their current binding.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Student Name or No.",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = "";
                  }),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'Student')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  
                  var students = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = (data['name'] ?? "").toString().toLowerCase();
                    String studentNo = (data['studentNumber'] ?? "").toString().toLowerCase();
                    return name.contains(_searchQuery) || studentNo.contains(_searchQuery);
                  }).toList();

                  if (students.isEmpty) return const Text("No students found.");

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      var student = students[index];
                      var studentData = student.data() as Map<String, dynamic>;
                      bool hasDeviceId = studentData.containsKey('deviceId') && studentData['deviceId'] != null;

                      return ListTile(
                        title: Text(studentData['name'] ?? "No Name"),
                        subtitle: Text(studentData['studentNumber'] ?? studentData['email'] ?? "No Email"),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasDeviceId ? Colors.orange : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: hasDeviceId ? () async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(student.id)
                                .update({'deviceId': FieldValue.delete()});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Device ID reset successful")),
                              );
                            }
                          } : null,
                          child: const Text("Reset", style: TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
      ],
    );
  }
}

class ManageCoursesDialog extends StatefulWidget {
  const ManageCoursesDialog({super.key});

  @override
  State<ManageCoursesDialog> createState() => _ManageCoursesDialogState();
}

class _ManageCoursesDialogState extends State<ManageCoursesDialog> {
  String? _selectedFaculty;
  String? _selectedSchool;
  final _courseController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    List<String> faculties = universityData.keys.toList();
    List<String> schools = _selectedFaculty != null ? universityData[_selectedFaculty]!.keys.toList() : [];

    return AlertDialog(
      title: const Text("Manage Courses"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedFaculty,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Select Faculty"),
              items: faculties.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) => setState(() { _selectedFaculty = val; _selectedSchool = null; }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedSchool,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Select School"),
              items: schools.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) => setState(() => _selectedSchool = val),
            ),
            const SizedBox(height: 10),
            CustomTextField(label: "New Course Name (e.g. BSc Computer Science)", controller: _courseController),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (_selectedFaculty == null || _selectedSchool == null || _courseController.text.isEmpty) return;
            
            await FirebaseFirestore.instance.collection('courses_list').add({
              'faculty': _selectedFaculty,
              'school': _selectedSchool,
              'courseName': _courseController.text.trim(),
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text("Add Course"),
        ),
      ],
    );
  }
}

class ManageModulesDialog extends StatefulWidget {
  const ManageModulesDialog({super.key});

  @override
  State<ManageModulesDialog> createState() => _ManageModulesDialogState();
}

class _ManageModulesDialogState extends State<ManageModulesDialog> {
  String? _selectedFaculty;
  String? _selectedSchool;
  String? _selectedCourse;
  final _moduleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    List<String> faculties = universityData.keys.toList();
    List<String> schools = _selectedFaculty != null ? universityData[_selectedFaculty]!.keys.toList() : [];

    return AlertDialog(
      title: const Text("Manage Modules"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedFaculty,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Select Faculty"),
              items: faculties.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) => setState(() { _selectedFaculty = val; _selectedSchool = null; _selectedCourse = null; }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedSchool,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Select School"),
              items: schools.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) => setState(() { _selectedSchool = val; _selectedCourse = null; }),
            ),
            const SizedBox(height: 10),
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
                      var data = doc.data() as Map<String, dynamic>;
                      if (data['courseName'] != null) {
                        courses.add(data['courseName']);
                      }
                    }
                  }
                  courses = courses.toSet().toList(); // Remove duplicates

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCourse,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Select Course"),
                    items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (val) => setState(() => _selectedCourse = val),
                  );
                },
              ),
            const SizedBox(height: 10),
            CustomTextField(label: "New Module Name (e.g. COMS101)", controller: _moduleController),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (_selectedFaculty == null || _selectedSchool == null || _selectedCourse == null || _moduleController.text.isEmpty) return;
            
            await FirebaseFirestore.instance.collection('modules_list').add({
              'faculty': _selectedFaculty,
              'school': _selectedSchool,
              'course': _selectedCourse,
              'moduleName': _moduleController.text.trim(),
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text("Add Module"),
        ),
      ],
    );
  }
}


class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _filterRole = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("User Management"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', 'Student', 'Lecturer'].map((role) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(role),
                    selected: _filterRole == role,
                    onSelected: (selected) {
                      if (selected) setState(() => _filterRole = role);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLecturerDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _filterRole == 'All' 
          ? FirebaseFirestore.instance.collection('users').snapshots()
          : FirebaseFirestore.instance.collection('users').where('role', isEqualTo: _filterRole).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 100, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text("No users found", style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var user = docs[index].data() as Map<String, dynamic>;
              String role = user['role'] ?? 'Unknown';
              Color roleColor = role == 'Admin' ? Colors.red : (role == 'Lecturer' ? Colors.green : Colors.blue);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: roleColor.withValues(alpha: 0.1),
                    child: Icon(
                      role == 'Lecturer' ? Icons.work : (role == 'Admin' ? Icons.admin_panel_settings : Icons.school),
                      color: roleColor,
                    ),
                  ),
                  title: Text(
                    "${user['name'] ?? ''} ${user['surname'] ?? ''}".trim().isEmpty ? "No Name" : "${user['name'] ?? ''} ${user['surname'] ?? ''}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['email'] ?? ""),
                      if (user['school'] != null)
                        Text("${user['school']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  trailing: role != 'Admin' 
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: () => _confirmDelete(context, docs[index].id, user['name'] ?? "this user"),
                      )
                    : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete $name? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(docId).delete();
              if (context.mounted) Navigator.pop(context);
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddLecturerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddLecturerDialog(),
    );
  }
}

class AddLecturerDialog extends StatefulWidget {
  const AddLecturerDialog({super.key});

  @override
  State<AddLecturerDialog> createState() => _AddLecturerDialogState();
}

class _AddLecturerDialogState extends State<AddLecturerDialog> {
  final nameController = TextEditingController();
  final surnameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  String? _selectedFaculty;
  String? _selectedSchool;
  String? _selectedCourse;
  String? _selectedGender;
  final List<String> _selectedModules = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    List<String> faculties = universityData.keys.toList();
    List<String> schools = _selectedFaculty != null ? universityData[_selectedFaculty]!.keys.toList() : [];

    return AlertDialog(
      title: const Text("Add Lecturer"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              CustomTextField(label: "First Name", controller: nameController),
              const SizedBox(height: 10),
              CustomTextField(label: "Surname", controller: surnameController),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(labelText: "Gender"),
                items: ["Male", "Female", "Other"]
                    .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGender = val),
              ),
              const SizedBox(height: 10),
              CustomTextField(label: "Email", controller: emailController),
              const SizedBox(height: 10),
              CustomTextField(label: "Password", controller: passwordController, isPassword: true),
              const Divider(height: 30),
              const Text("Academic Placement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedFaculty,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Faculty"),
                items: faculties.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => setState(() { 
                  _selectedFaculty = val; 
                  _selectedSchool = null; 
                  _selectedCourse = null;
                  _selectedModules.clear();
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedSchool,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "School"),
                items: schools.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) => setState(() { 
                  _selectedSchool = val;
                  _selectedCourse = null;
                  _selectedModules.clear();
                }),
              ),
              if (_selectedSchool != null) ...[
                const SizedBox(height: 10),
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
                        var data = doc.data() as Map<String, dynamic>;
                        if (data['courseName'] != null) {
                          courses.add(data['courseName']);
                        }
                      }
                    }
                    courses = courses.toSet().toList();

                    return DropdownButtonFormField<String>(
                      initialValue: _selectedCourse,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: "Course"),
                      items: courses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) => setState(() {
                        _selectedCourse = val;
                        _selectedModules.clear();
                      }),
                    );
                  },
                ),
              ],
              if (_selectedCourse != null) ...[
                const SizedBox(height: 20),
                const Text("Assign Modules", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('modules_list')
                      .where('course', isEqualTo: _selectedCourse).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    var modules = snapshot.data!.docs;
                    if (modules.isEmpty) return const Text("No modules found for this course.", style: TextStyle(fontSize: 11));
                    
                    return Wrap(
                      spacing: 8,
                      children: modules.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String mod = data['moduleName'] ?? "Unknown";
                        bool isSelected = _selectedModules.contains(mod);
                        return FilterChip(
                          label: Text(mod, style: const TextStyle(fontSize: 10)),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedModules.add(mod);
                              } else {
                                _selectedModules.remove(mod);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
      ),
      actions: _isLoading ? [] : [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            if (emailController.text.isEmpty || nameController.text.isEmpty || passwordController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please fill in all fields")),
              );
              return;
            }

            setState(() => _isLoading = true);

            try {
              FirebaseApp secondaryApp;
              try {
                secondaryApp = Firebase.app('LecturerRegistration');
              } catch (e) {
                secondaryApp = await Firebase.initializeApp(
                  name: 'LecturerRegistration',
                  options: Firebase.app().options,
                );
              }

              // 2. Create the lecturer in Firebase Auth
              UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp)
                  .createUserWithEmailAndPassword(
                email: emailController.text.trim(),
                password: passwordController.text.trim(),
              );

              // Send verification email
              await userCredential.user!.sendEmailVerification();

              // 3. Save detailed lecturer info to Firestore using the primary app
              await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
                'uid': userCredential.user!.uid,
                'name': nameController.text.trim(),
                'surname': surnameController.text.trim(),
                'gender': _selectedGender,
                'email': emailController.text.trim(),
                'role': 'Lecturer',
                'faculty': _selectedFaculty,
                'school': _selectedSchool,
                'modules': _selectedModules,
                'createdAt': FieldValue.serverTimestamp(),
              });

              // 4. Delete the temporary secondary app
              await secondaryApp.delete();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Lecturer account created successfully!")),
                );
              }
            } on FirebaseAuthException catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Auth Error: ${e.message}")),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            } finally {
              if (context.mounted) setState(() => _isLoading = false);
            }
          },
          child: const Text("Add Lecturer"),
        ),
      ],
    );
  }
}
