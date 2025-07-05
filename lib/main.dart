import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_app/manager/pages/general_menu_viewer.dart';
import 'package:mess_app/student/cart_page.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'login_page.dart';

import 'admin/admin_dashboard.dart';
import 'employee/employee_dashboard.dart';
import 'manager/manager_dashboard.dart';
import 'student/student_dashboard.dart';
import 'manager/update_general_menu.dart';

// ✅ Import the extra mess menu screen
import 'manager/add_extra_menu.dart'; // Make sure this file exists
import 'manager/pages/extra_menu_page.dart'; // Make sure this file exists
import 'student/pages/redirect_page.dart';
import 'package:app_links/app_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();
  Widget _startScreen = const SplashToSignInScreen();

  @override
  void initState() {
    super.initState();
    _initDeepLinkHandler();
  }

  Future<void> _initDeepLinkHandler() async {
    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null && initialUri.path.contains("payment-success")) {
      final orderId = initialUri.queryParameters['order_id'];
      setState(() {
        _startScreen = PaymentRedirectPage(orderId: orderId);
      });
    }

    _appLinks.uriLinkStream.listen((uri) {
      if (uri.path.contains("payment-success")) {
        final orderId = uri.queryParameters['order_id'];
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PaymentRedirectPage(orderId: orderId)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Auth Role App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _startScreen,
      routes: {
        '/login': (context) => const LoginPage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/employee-dashboard': (context) => const EmployeeDashboard(),
        '/manager-dashboard': (context) => const ManagerDashboard(),
        '/student-dashboard': (context) => const StudentDashboard(),
        '/add_extra_menu': (context) => const AddExtraMenuPage(),
        '/update_general_menu': (context) => const UpdateGeneralMenuPage(),
        '/general_menu_viewer': (context) => const GeneralMenuViewerPage(),
        '/extra_menu_page': (context) => const ExtraMenuPage(),
        '/cart': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return CartPage(
            cart: args['cart'],
            onCartUpdated: args['onCartUpdated'],
          );
        },
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
      // User is already logged in, navigate based on role
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigateBasedOnRole(user);
      });
    } else {
      // No user logged in, show splash for 3 seconds then go to login
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
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userRef.get();
    final data = docSnapshot.data();
    final role = data?['role'];

    if (!mounted) return;

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
      Navigator.pushReplacementNamed(context, '/student-dashboard');
    } else if (role == 'guest') {
      if (!data!.containsKey('Sex')) {
        await userRef.update({'Sex': 1});
        await Future.delayed(const Duration(milliseconds: 500));
      }
      Navigator.pushReplacementNamed(context, '/student-dashboard');
    } else {
      // For admin/manager/employee roles
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
        default:
          Navigator.pushReplacementNamed(context, '/login');
          break;
      }
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