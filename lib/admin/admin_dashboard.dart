import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../login_page.dart';
import '../services/notification_service.dart';
import 'profile_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String selectedRole = 'regular';

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

  Future<void> _uploadExcelAndUpdateRoles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null) return;

    File file = File(result.files.single.path!);
    List<int> bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);
    var sheet = excel.tables[excel.tables.keys.first];

    if (sheet == null) return;

    for (int i = 1; i < sheet.rows.length; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty) continue;
      String? email = row[0]?.value?.toString().trim();

      if (email == null || email.isEmpty) continue;

      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final docId = userSnapshot.docs.first.id;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .update({'role': selectedRole});
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Roles updated to "$selectedRole" successfully.')),
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
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Welcome $name!', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedRole,
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedRole = value);
                }
              },
              items: const [
                DropdownMenuItem(value: 'regular', child: Text('Regular')),
                DropdownMenuItem(value: 'guest', child: Text('Guest')),
                DropdownMenuItem(value: 'employee', child: Text('Employee')),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _uploadExcelAndUpdateRoles,
              child: const Text('Upload Excel & Update Roles'),
            ),
          ],
        ),
      ),
    );
  }
}
