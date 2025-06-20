import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login_page.dart';
import '../services/notification_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.initialize();

    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool('notificationsPrompted') ?? false;
    final isGranted = await NotificationService.areNotificationsEnabled();

    if (alreadyPrompted || isGranted || !mounted) return;

    _showPermissionDialog(prefs);
  }

  void _showPermissionDialog(SharedPreferences prefs) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: const Text(
            'Enable notifications to stay informed about announcements and deadlines.'),
        actions: [
          TextButton(
            onPressed: () async {
              await Permission.notification.request();
              await prefs.setBool('notificationsPrompted', true);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Enable'),
          ),
          TextButton(
            onPressed: () async {
              await prefs.setBool('notificationsPrompted', true);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: Text('Welcome $name!', style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
