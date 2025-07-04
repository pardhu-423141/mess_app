import 'package:flutter/material.dart';
import './pages/home_page.dart';
import './pages/extra_menu_page.dart';
import './pages/general_menu_viewer.dart';
import './pages/analytics_page.dart';
import '../profile.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const ExtraMenuPage(),
      const GeneralMenuViewerPage(),
      const AnalyticsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Manager Dashboard')),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: 'Extra Menu'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'General Menu'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
