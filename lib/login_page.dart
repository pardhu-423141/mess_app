import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin/admin_dashboard.dart';
import 'manager/manager_dashboard.dart';
import 'employee/employee_dashboard.dart';
import 'student/student_dashboard.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> createUserIfNotExists(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      final checkEmail = RegExp(r'@student.nitandhra.ac.in$');
      final email = user.email ?? '';
      if (checkEmail.hasMatch(email)) {
        await docRef.set({
          'name': user.displayName ?? '',
          'email': user.email,
          'role': 'regular',
        });
      } else {
        await docRef.set({
          'name': user.displayName ?? '',
          'email': user.email,
          'role': 'guest',
        });
      }
    }
  }

  Future<void> navigateBasedOnRole(BuildContext context, User user) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userRef.get();
    final data = docSnapshot.data();
    final role = data?['role'];

    if (!context.mounted) return;

    if (role == 'regular') {
      if (!data!.containsKey('Sex')) {
        // Show popup to select sex, wait for user to choose
        final selectedSex = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text("Select Your Hostel"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    "⚠️ Please choose your hostel type carefully. "
                    "If entered incorrectly, you must visit the hostel office to change it.",
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  Text("Are you a Boys or Girls hostel student?"),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, 1); // Boys = 1
                  },
                  child: const Text("Boys"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, 0); // Girls = 0
                  },
                  child: const Text("Girls"),
                ),
              ],
            );
          },
        );

        if (selectedSex != null) {
          await userRef.update({'Sex': selectedSex});
          // Small delay to ensure Firestore update is done before navigation
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentDashboard()));
    } else if (role == 'guest') {
      if (!data!.containsKey('Sex')) {
        await userRef.update({'Sex': 1});
        await Future.delayed(const Duration(milliseconds: 500));
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentDashboard()));
    } else {
      // For admin/manager/employee roles
      switch (role) {
        case 'admin':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
          break;
        case 'manager':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ManagerDashboard()));
          break;
        case 'employee':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmployeeDashboard()));
          break;
        default:
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentDashboard()));
          break;
      }
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await createUserIfNotExists(user);
        if (!context.mounted) return; 
        await navigateBasedOnRole(context, user);
      }
    } catch (e) {
      if (!context.mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          onPressed: () => _signInWithGoogle(context),
        ),
      ),
    );
  }
}