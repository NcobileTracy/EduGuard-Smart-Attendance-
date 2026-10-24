import 'package:flutter/material.dart';
import 'lecturer_dashboard.dart';
import 'generate_qrcode.dart';
import 'attendance_history.dart';
import 'lecturer_profile.dart';
import 'session_register.dart';

class LecturerMainScreen extends StatefulWidget {
  const LecturerMainScreen({super.key});

  @override
  State<LecturerMainScreen> createState() => _LecturerMainScreenState();
}

class _LecturerMainScreenState extends State<LecturerMainScreen> {
  int _selectedIndex = 0;
  String? _selectedModule;

  void _onModuleSelected(String? module) {
    setState(() {
      _selectedModule = module;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      LecturerDashboard(onModuleSelected: _onModuleSelected),
      GenerateQRScreen(moduleName: _selectedModule),
      _selectedModule != null 
          ? SessionRegisterScreen(moduleName: _selectedModule!)
          : AttendanceHistoryScreen(),
      const LecturerProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_2_outlined), activeIcon: Icon(Icons.qr_code_2), label: 'Create QR'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Registry'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
