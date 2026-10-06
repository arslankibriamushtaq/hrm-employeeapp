import 'package:flutter/material.dart';

import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'leave_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // Rebuilt on each switch, so every tab shows fresh data when opened.
    final pages = [
      DashboardScreen(onOpenTab: _goTo),
      const AttendanceScreen(),
      const LeaveScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.access_time), selectedIcon: Icon(Icons.access_time_filled), label: 'Attendance'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Leave'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Tab indexes used by [DashboardScreen] shortcuts.
class Tabs {
  static const attendance = 1;
  static const leave = 2;
}
