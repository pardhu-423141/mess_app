import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_app/manager/pages/general_menu_viewer.dart';
import 'package:mess_app/student/cart/cart_page.dart';
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
import 'student/pages/rating_popup.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Define a consistent theme for the app, similar to Cred's dark theme


final ThemeData credTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF1A1A1A), // Dark background
  hintColor: const Color(0xFF9E9E9E), // Light grey for subtle hints
  cardColor: const Color(0xFF2C2C2C), // Slightly lighter dark for cards
  scaffoldBackgroundColor: const Color(0xFF1A1A1A),
  fontFamily: 'Montserrat', // A modern, clean font (you might need to add this to pubspec.yaml)
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Georgia',
      color: Colors.white,
      fontSize: 34,
      fontWeight: FontWeight.bold,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Georgia',
      color: Colors.white,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Georgia',
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Georgia',
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.white,
      fontSize: 16,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Montserrat',
      color: Color(0xFF9E9E9E),
      fontSize: 14,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Montserrat',
      color: Color(0xFF9E9E9E),
      fontSize: 12,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Montserrat',
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A1A1A),
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      fontFamily: 'Montserrat',
    ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6A1B9A),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'Montserrat',
      ),
      // Corrected: Removed const and used withAlpha for deprecated withOpacity
      shadowColor: const Color(0xFF6A1B9A).withAlpha((0.5 * 255).round()),
      elevation: 5,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF6A1B9A), width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: 'Montserrat',
      ),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFF2C2C2C),
    selectedColor: const Color(0xFF6A1B9A),
    labelStyle: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
    // Corrected: Removed const and used withAlpha for deprecated withOpacity
    shadowColor: Colors.black.withAlpha((0.3 * 255).round()),
    elevation: 2,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2C2C2C),
    labelStyle: const TextStyle(color: Color(0xFF9E9E9E), fontFamily: 'Montserrat'),
    hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontFamily: 'Montserrat'),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10.0),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  // Corrected: dialogTheme expects DialogThemeData as per your error message.
  // The 'const' is also removed as it contains non-const expressions.
  dialogTheme: DialogThemeData( // Changed from DialogTheme to DialogThemeData
    backgroundColor: const Color(0xFF2C2C2C),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15.0),
    ),
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.bold,
      fontFamily: 'Montserrat',
    ),
    contentTextStyle: const TextStyle(
      color: Colors.white70,
      fontFamily: 'Montserrat',
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF9E9E9E),
      textStyle: const TextStyle(fontFamily: 'Montserrat'),
    ),
  ),
  iconTheme: const IconThemeData(
    color: Color(0xFF9E9E9E),
    size: 24.0,
  ),
  primaryIconTheme: const IconThemeData(
    color: Colors.white,
  ),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: const Color(0xFF6A1B9A),
    // Corrected: Used withAlpha for deprecated withOpacity
    selectionColor: const Color(0xFF6A1B9A).withAlpha((0.3 * 255).round()),
    selectionHandleColor: const Color(0xFF6A1B9A),
  ),
  sliderTheme: SliderThemeData(
    activeTrackColor: const Color(0xFF6A1B9A),
    // Corrected: Used withAlpha for deprecated withOpacity
    inactiveTrackColor: const Color(0xFF9E9E9E).withAlpha((0.3 * 255).round()),
    thumbColor: Colors.white,
    // Corrected: Used withAlpha for deprecated withOpacity
    overlayColor: const Color(0xFF6A1B9A).withAlpha((0.2 * 255).round()),
    valueIndicatorColor: const Color(0xFF6A1B9A),
    valueIndicatorTextStyle: const TextStyle(
      color: Colors.white,
      fontFamily: 'Montserrat',
    ),
  ),
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: MaterialColor(
      0xFF6A1B9A,
      const <int, Color>{
        50: Color(0xFFE9D8F5),
        100: Color(0xFFC7A2E0),
        200: Color(0xFFA46BD0),
        300: Color(0xFF8135C0),
        400: Color(0xFF6A1B9A),
        500: Color(0xFF530F7C),
        600: Color(0xFF4C0C72),
        700: Color(0xFF450968),
        800: Color(0xFF3E065E),
        900: Color(0xFF370354),
      },
    ),
    brightness: Brightness.dark,
  ).copyWith(secondary: const Color(0xFF6A1B9A)),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return Colors.white;
      }
      return const Color(0xFF9E9E9E);
    }),
    trackColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF6A1B9A);
      }
      return const Color(0xFF2C2C2C);
    }),
  ),
  checkboxTheme: CheckboxThemeData(
    fillColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF6A1B9A);
      }
      return const Color(0xFF2C2C2C);
    }),
    checkColor: MaterialStateProperty.all(Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4.0),
    ),
  ),
  radioTheme: RadioThemeData(
    fillColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.selected)) {
        return const Color(0xFF6A1B9A);
      }
      return const Color(0xFF2C2C2C);
    }),
  ),
  // Corrected: cardTheme expects CardThemeData as per your error message.
  // The 'const' is also removed as it contains non-const expressions.
  cardTheme: CardThemeData( // Changed from CardTheme to CardThemeData
    color: const Color(0xFF2C2C2C),
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
    ),
    margin: const EdgeInsets.all(8.0),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFF2C2C2C),
    thickness: 1,
    space: 16,
    indent: 16,
    endIndent: 16,
  ),
  // Corrected: Used withAlpha for deprecated withOpacity
  splashColor: const Color(0xFF6A1B9A).withAlpha((0.2 * 255).round()),
  // Corrected: Used withAlpha for deprecated withOpacity
  highlightColor: const Color(0xFF6A1B9A).withAlpha((0.1 * 255).round()),
);


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // You can handle background notification logic here
  print("🔔 BG Message: ${message.messageId}");
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
    setUserMessFieldToSex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RatingPopup.show(context);
    });
    
  }
  
  Future<void> setUserMessFieldToSex() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint("⚠️ No user is currently logged in.");
        return;
      }

      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await userDocRef.get();

      if (!docSnapshot.exists) {
        debugPrint("⚠️ User document does not exist.");
        return;
      }

      final data = docSnapshot.data();
      if (data == null || !data.containsKey('Sex')) {
        debugPrint("⚠️ 'Sex' field is missing in user document.");
        return;
      }

      final sex = data['Sex'];
      await userDocRef.update({'mess': sex});
      debugPrint("✅ Set 'mess' field to '$sex' for user ${user.uid}");
    } catch (e) {
      debugPrint("❌ Error setting mess field: $e");
    }
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
      theme: credTheme,
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
    debugPrint("🔧 Value of selectedSex: $role");
    if (!mounted) return;

    if (role == 'regular') {
      if (data == null || !data.containsKey('mess')) {
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
          await userRef.update({'mess': selectedSex});
          // Small delay to ensure Firestore update is done before navigation
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      Navigator.pushReplacementNamed(context, '/student-dashboard');
    } else if (role == 'guest') {
      if (!data!.containsKey('mess')) {
        await userRef.update({'mess': 1});
        await Future.delayed(const Duration(milliseconds: 500));
      }
      Navigator.pushReplacementNamed(context, '/student-dashboard');
    }else if (role == 'manager') {
      debugPrint("🔧 role is manager");
      if (!data!.containsKey('mess')) {
        debugPrint("🔧 but failed");
        // Show popup to select sex, wait for user to choose
        final selectedSex = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text("Select Your Mess"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(height: 16),
                  Text("You are manager for which mess?"),
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
          await userRef.update({'mess': selectedSex});
          // Small delay to ensure Firestore update is done before navigation
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      Navigator.pushReplacementNamed(context, '/manager-dashboard');
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