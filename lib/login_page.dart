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
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = doc.data()?['role'];
    if (!context.mounted) return; 
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
      case 'regular':
      case 'guest':
      default:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudentDashboard()));
        break;
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
