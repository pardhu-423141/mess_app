import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'login_page.dart';

import 'admin/admin_dashboard.dart';
import 'employee/employee_dashboard.dart';
import 'manager/manager_dashboard.dart';
import 'student/student_dashboard.dart';
import 'manager/update_general_menu.dart';

// ✅ Import the extra mess menu screen
import 'manager/add_extra_menu.dart'; // Make sure this file exists

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth Role App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashToSignInScreen(),
      
      // ✅ Routing table
      routes: {
        '/login': (context) => const LoginPage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/employee-dashboard': (context) => const EmployeeDashboard(),
        '/manager-dashboard': (context) => const ManagerDashboard(),
        '/student-dashboard': (context) => const StudentDashboard(),
        '/add_extra_menu': (context) => const AddExtraMenuPage(),
        '/update_general_menu':(context) => const UpdateGeneralMenuPage(),
      },
    );
  }
}

class SplashToSignInScreen extends StatefulWidget {
  const SplashToSignInScreen({super.key});

  @override
  State<SplashToSignInScreen> createState() => _SplashToSignInScreenState();
}

class _SplashToSignInScreenState extends State<SplashToSignInScreen> {
  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigateBasedOnRole(user);
      });
    } else {
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      });
    }
  }

  Future<void> navigateBasedOnRole(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final role = doc.data()?['role'];

    if (!mounted) return;

    switch (role) {
      case 'admin':
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
        break;
      case 'manager':
        Navigator.pushReplacementNamed(context, '/manager-dashboard');
        break;
      case 'employee':
        Navigator.pushReplacementNamed(context, '/employee-dashboard');
        break;
      case 'regular':
      case 'guest':
      default:
        Navigator.pushReplacementNamed(context, '/student-dashboard');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(seconds: 1),
          child: Image.asset('assets/NIT_Andhra_Pradesh.png', width: 200),
        ),
      ),
    );
  }
}
