import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../login_page.dart';
import '../../../services/notification_service.dart';
import '../../../utils/reservation_cleanup.dart';
import '../../messSwitchButton.dart';
import '../rating_popup.dart';

import 'cart_notifier.dart';
import 'extra_menu_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static bool _hasShownPopup = false;
  String _userGender = '1';
  bool _isLoadingGender = true; // ✅ Added loading flag

  @override
  void initState() {
    super.initState();
    _fetchUserGender();
    _initializeNotifications();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownPopup) {
        _hasShownPopup = true;
        RatingPopup.show(context);
      }
    });

    cleanupExpiredReservations();

    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(message.notification!.title ?? 'Message'),
            content: Text(message.notification!.body ?? ''),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    });
  }

  Future<void> _fetchUserGender() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _userGender = data['mess']?.toString() ?? '1';
          _isLoadingGender = false; // ✅ Set loading false when gender fetched
        });
      } else {
        setState(() => _isLoadingGender = false); // ✅ Fallback
      }
    } else {
      setState(() => _isLoadingGender = false); // ✅ Fallback
    }
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.initialize();
    final prefs = await SharedPreferences.getInstance();

    if (!(await NotificationService.areNotificationsEnabled()) &&
        !(prefs.getBool('notificationsPrompted') ?? false)) {
      _showPermissionDialog(prefs);
    }

    final token = await FirebaseMessaging.instance.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'fcm_token': token},
        SetOptions(merge: true),
      );
    }
  }

  void _showPermissionDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: const Text('Enable notifications to stay updated.'),
        actions: [
          TextButton(
            onPressed: () async {
              await Permission.notification.request();
              await prefs.setBool('notificationsPrompted', true);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Enable'),
          ),
          TextButton(
            onPressed: () async {
              await prefs.setBool('notificationsPrompted', true);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _navigateToCart() async {
    final result = await Navigator.pushNamed(context, '/cart', arguments: {
      'cart': cartNotifier.value,
      'onCartUpdated': (Map<String, int> updated) => cartNotifier.value = updated,
    });
    if (result is Map<String, int>) cartNotifier.value = result;
  }

  void _signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  void _showProfileMenu(User user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Profile: ${user.displayName ?? "User"}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Email: ${user.email}'),
            if (user.photoURL != null)
              CircleAvatar(radius: 30, backgroundImage: NetworkImage(user.photoURL!)),
            const SizedBox(height: 10),
            MessSwitcherButton(),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              onPressed: () {
                Navigator.pop(context);
                _signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(String id, String collection) {
    final key = '${collection}_$id';
    final current = Map<String, int>.from(cartNotifier.value);
    current.update(key, (v) => v + 1, ifAbsent: () => 1);
    cartNotifier.value = current;
  }

  void _removeFromCart(String id, String collection) {
    final key = '${collection}_$id';
    final current = Map<String, int>.from(cartNotifier.value);
    if (current.containsKey(key)) {
      if (current[key]! > 1) {
        current[key] = current[key]! - 1;
      } else {
        current.remove(key);
      }
      cartNotifier.value = current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              if (user != null) _showProfileMenu(user);
            },
          ),
        ],
      ),
      body: _isLoadingGender
          ? const Center(child: CircularProgressIndicator()) // ✅ Don't build UI until gender is ready
          : ExtraMenuPage(
              onAddToCart: _addToCart,
              onRemoveFromCart: _removeFromCart,
              userGender: _userGender,
            ),
      floatingActionButton: ValueListenableBuilder<Map<String, int>>(
        valueListenable: cartNotifier,
        builder: (context, cart, _) {
          final count = cart.values.fold(0, (a, b) => a + b);
          return count > 0
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('Go to Cart ($count)'),
                  onPressed: _navigateToCart,
                )
              : const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
