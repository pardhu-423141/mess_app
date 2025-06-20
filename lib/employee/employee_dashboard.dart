import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../login_page.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  Future<void> _signOut(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return; 
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Employee';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Text('Welcome $name!', style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
