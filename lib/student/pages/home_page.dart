import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../login_page.dart';
import '../../services/notification_service.dart';
import '../../utils/meal_utils.dart';
import './rating_popup.dart';
import '../../utils/reservation_cleanup.dart';
// --- Existing Meal Time Utilities (no changes needed here) ---


String getCurrentMealType() {
  final now = TimeOfDay.now();
  final timings = getMealTimings();

  for (var entry in timings.entries) {
    final range = entry.value;
    final int nowInMinutes = now.hour * 60 + now.minute;
    final int startInMinutes = range.start.hour * 60 + range.start.minute;
    final int endInMinutes = range.end.hour * 60 + range.end.minute;

    if (nowInMinutes >= startInMinutes && nowInMinutes <= endInMinutes) {
      return entry.key;
    }
  }
  return 'Breakfast';
}

DateTime? getMealClosingTime(String mealType) {
  final timings = getMealTimings();
  final range = timings[mealType];
  if (range == null) return null;

  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, range.end.hour, range.end.minute);
}

String getMealTypeFromCode(String itemId) {
  if (itemId.length >= 2) {
    final mealCodeChar = itemId[1];
    switch (mealCodeChar) {
      case '1':
        return 'Breakfast';
      case '2':
        return 'Lunch';
      case '3':
        return 'Snacks';
      case '4':
        return 'Dinner';
      default:
        return 'Unknown Meal';
    }
  }
  return 'Unknown Meal';
}

String getDayStringFromIdDigit(String itemId) {
  if (itemId.isNotEmpty) {
    final dayCodeChar = itemId[0];
    final int? dayNum = int.tryParse(dayCodeChar);
    if (dayNum != null && dayNum >= 1 && dayNum <= 7) {
      switch (dayNum) {
        case 1:
          return 'Monday';
        case 2:
          return 'Tuesday';
        case 3:
          return 'Wednesday';
        case 4:
          return 'Thursday';
        case 5:
          return 'Friday';
        case 6:
          return 'Saturday';
        case 7:
          return 'Sunday';
      }
    }
  }
  return 'Unknown Day';
}

String getCurrentActualDayString() {
  final now = DateTime.now();
  return DateFormat('EEEE').format(now);
}
// --- End Meal Time Utilities ---

// NEW: Define a global or accessible ValueNotifier for the cart
// This allows other widgets to listen to cart changes without rebuilding the whole HomePage.
final ValueNotifier<Map<String, int>> _cartNotifier = ValueNotifier({});

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // Removed _cartItemCount and _cart as they will be managed by _cartNotifier
  late TabController _tabController;
  String _userGender = '1';
  static bool _hasShownPopup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeNotifications();
    _fetchUserGender();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRatingPopupOnce();
    });
    cleanupExpiredReservations();
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final notification = message.notification!;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(notification.title ?? 'Message'),
            content: Text(notification.body ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              )
            ],
          ),
        );
      }
});
  }
  void _showRatingPopupOnce() {
    if (!_hasShownPopup) {
      _hasShownPopup = true; // mark as shown
      RatingPopup.show(context);
    }
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserGender() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userGender = userData['Sex']?.toString() ?? '1';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user gender: $e');
    }
  }

  Future<void> _initializeNotifications() async {
  try {
    await NotificationService.initialize();

    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool('notificationsPrompted') ?? false;
    final isGranted = await NotificationService.areNotificationsEnabled();

    if (!alreadyPrompted && !isGranted && mounted) {
      _showPermissionDialog(prefs);
    }

    // ✅ Step 1: Request push permission (for iOS, web)
    await FirebaseMessaging.instance.requestPermission();

    // ✅ Step 2: Get FCM token
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('📲 FCM Token: $token');

    // ✅ Step 3: Get current user
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && token != null) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      // ✅ Use set with merge: true to avoid update failure if document doesn't exist
      await userRef.set(
            {'fcm_token': token},
            SetOptions(merge: true), // Use merge to only update the 'profile' field
          );
      debugPrint('✅ FCM token saved to Firestore for user: ${user.uid}');
    } else {
      debugPrint('❌ User or token is null');
    }

    // ✅ Step 4: Handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser != null) {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(refreshedUser.uid);
        await userRef.set({'fcm_Token': newToken}, SetOptions(merge: true));
        debugPrint('🔄 FCM token refreshed and updated in Firestore');
      }
    });
  } catch (e) {
    debugPrint('❌ Error in _initializeNotifications: $e');
  }
}



  void _showPermissionDialog(SharedPreferences prefs) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: const Text('Enable notifications to stay informed about announcements and deadlines.'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await Permission.notification.request();
                await prefs.setBool('notificationsPrompted', true);
                if (!mounted) return;
                Navigator.of(context).pop();
              } catch (e) {
                debugPrint('Error requesting permission: $e');
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to enable notifications. Please try from app settings.')),
                  );
                }
              }
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
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error signing out. Please try again.')),
        );
      }
    }
  }

  // Updated cart manipulation methods to use _cartNotifier
  void _addToCart(String menuId, String collection) {
    final cartKey = '${collection}_$menuId';
    final currentCart = Map<String, int>.from(_cartNotifier.value); // Create a mutable copy
    currentCart.update(cartKey, (value) => value + 1, ifAbsent: () => 1);
    _cartNotifier.value = currentCart; // Update the ValueNotifier
  }

  void _removeFromCart(String menuId, String collection) {
    final cartKey = '${collection}_$menuId';
    final currentCart = Map<String, int>.from(_cartNotifier.value); // Create a mutable copy
    if (currentCart.containsKey(cartKey)) {
      if (currentCart[cartKey]! > 1) {
        currentCart[cartKey] = currentCart[cartKey]! - 1;
      } else {
        currentCart.remove(cartKey);
      }
      _cartNotifier.value = currentCart; // Update the ValueNotifier
    }
  }

  // _updateCartItemCount is no longer needed here as ValueListenableBuilder will handle it

  void _navigateToCart() async {
  final updatedCart = await Navigator.pushNamed(
    context,
    '/cart',
    arguments: {
      'cart': _cartNotifier.value,
      'onCartUpdated': (Map<String, int> updatedCart) {
        _cartNotifier.value = updatedCart;
      },
    },
  );

  if (updatedCart is Map<String, int>) {
    _cartNotifier.value = updatedCart;
  }
}

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? 'Student';
    final email = user?.email ?? 'No email';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showProfileMenu(user, name, email),
          ),
        ],
      ),
      // Pass the cart functions and userGender to _ExtraMenuPage
      body: _ExtraMenuPage(
        onAddToCart: _addToCart,
        onRemoveFromCart: _removeFromCart,
        userGender: _userGender,
      ),
      // Use ValueListenableBuilder to rebuild only the FloatingActionButton
      floatingActionButton: ValueListenableBuilder<Map<String, int>>(
        valueListenable: _cartNotifier,
        builder: (context, cartValue, child) {
          final cartItemCount = cartValue.values.fold(0, (sum, quantity) => sum + quantity);
          return cartItemCount > 0
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text('Go to Cart ($cartItemCount)'),
                  onPressed: _navigateToCart,
                  backgroundColor: Colors.green,
                )
              : const SizedBox.shrink(); // Use SizedBox.shrink() instead of null
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showProfileMenu(User? user, String name, String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Profile: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name'),
            Text('Email: $email'),
            if (user?.photoURL != null && user!.photoURL!.isNotEmpty) ...[
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(user.photoURL!),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                onPressed: () {
                  Navigator.pop(context);
                  _signOut();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Updated _ExtraMenuPage to be a StatelessWidget and use ValueListenableBuilder
class _ExtraMenuPage extends StatelessWidget {
  // Removed 'cart' from constructor
  final Function(String, String) onAddToCart;
  final Function(String, String) onRemoveFromCart;
  final String userGender;

  const _ExtraMenuPage({
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.userGender,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);
    final screenWidth = mediaQueryData.size.width;
    final screenHeight = mediaQueryData.size.height;
    final double bottomSystemInset = mediaQueryData.padding.bottom;

    const double horizontalPadding = 12.0;
    const double crossAxisSpacing = 16.0;
    const int crossAxisCount = 2;

    final double availableWidth = screenWidth - (2 * horizontalPadding) - ((crossAxisCount - 1) * crossAxisSpacing);
    final double cardWidth = availableWidth / crossAxisCount;

    final double cardHeight = screenHeight / 4;
    final double dynamicChildAspectRatio = cardWidth / cardHeight;

    final double fabHeight = 56.0;
    final double fabMargin = 16.0;
    final double minBottomPaddingForFAB = fabHeight + fabMargin + bottomSystemInset;

    final currentMeal = getCurrentMealType();
    final currentActualDay = getCurrentActualDayString();
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, horizontalPadding, horizontalPadding, minBottomPaddingForFAB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- General Menu Section ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Daily Meal: $currentMeal ($currentActualDay)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('general_menu').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      "No general menu items available.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              final List<DocumentSnapshot> generalMenuItems = [];

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final itemId = doc.id;

                final String? hostel = data['hostel']?.toString();
                final String mealTypeFromCode = getMealTypeFromCode(itemId);
                final String itemDayFromId = getDayStringFromIdDigit(itemId);

                if (hostel == userGender &&
                    mealTypeFromCode == currentMeal &&
                    itemDayFromId == currentActualDay) {
                  generalMenuItems.add(doc);
                }
              }

              if (generalMenuItems.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      "No daily $currentMeal items for your category today ($currentActualDay).",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                );
              }

              return ValueListenableBuilder<Map<String, int>>( // Listen to _cartNotifier
                valueListenable: _cartNotifier,
                builder: (context, cartValue, child) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: crossAxisSpacing,
                      mainAxisSpacing: 16,
                      childAspectRatio: dynamicChildAspectRatio,
                    ),
                    itemCount: generalMenuItems.length,
                    itemBuilder: (context, index) {
                      final doc = generalMenuItems[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final String itemPriceString;
                      final dynamic priceData = data['price'];
                      if (priceData is int || priceData is double) {
                        itemPriceString = priceData.toString();
                      } else if (priceData is String) {
                        itemPriceString = priceData;
                      } else {
                        itemPriceString = 'N/A';
                      }
                      final description = data['description'] ?? 'No description available.';
                      final imageUrl = data['imageUrl'] as String?;
                      final double? rating = (data['rating'] as num?)?.toDouble();

                      final mealRange = getMealTimings()[currentMeal];
                      final isBookingOpened = mealRange != null &&
                          now.hour * 60 + now.minute >= mealRange.start.hour * 60 + mealRange.start.minute &&
                          now.hour * 60 + now.minute <= mealRange.end.hour * 60 + mealRange.end.minute;

                      final bookingClosingTime = getMealClosingTime(currentMeal);

                      final cartKey = 'general_menu_${doc.id}';
                      final int itemCount = cartValue[cartKey] ?? 0; // Use cartValue from ValueListenableBuilder

                      return _MenuItemCard(
                        itemName: currentMeal,
                        itemActualName: data['name'] ?? currentMeal,
                        itemPrice: itemPriceString,
                        imageUrl: imageUrl,
                        itemCount: itemCount,
                        isActive: isBookingOpened,
                        isAvailableInStock: true,
                        canAddToCart: isBookingOpened,
                        onAdd: () => onAddToCart(doc.id, 'general_menu'),
                        onRemove: () => onRemoveFromCart(doc.id, 'general_menu'),
                        description: description,
                        bookingClosingTime: bookingClosingTime,
                        cardHeight: cardHeight,
                        cardWidth: cardWidth,
                        isGeneralMenuItem: true,
                        rating: rating,
                      );
                    },
                  );
                },
              );
            },
          ),
          // --- Extra Menu Section ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('extra_menu').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }

              final docs = snapshot.data!.docs;
              final List<DocumentSnapshot> displayDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final genderMatch = data['gender']?.toString() == userGender;
                final mealMatch = data['mealType']?.toString() == currentMeal;
                final hasRequiredFields = data.containsKey('name') && data.containsKey('price');

                final startTime = (data['startTime'] as Timestamp?)?.toDate();
                final endTime = (data['endTime'] as Timestamp?)?.toDate();
                
                final isBookingOpened = startTime != null && endTime != null && now.isAfter(startTime) && now.isBefore(endTime);
                final isActive = isBookingOpened && data['status']=='active';

                return genderMatch && mealMatch && hasRequiredFields && isActive;
              }).toList();

              displayDocs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;

                final startTimeA = (dataA['startTime'] as Timestamp?)?.toDate();
                final endTimeA = (dataA['endTime'] as Timestamp?)?.toDate();
                final availableOrdersA = dataA['availableOrders'] as int? ?? 0;
                final isBookingOpenedA = startTimeA != null && endTimeA != null && now.isAfter(startTimeA) && now.isBefore(endTimeA);
                final isActiveA = isBookingOpenedA && availableOrdersA > 0;

                final startTimeB = (dataB['startTime'] as Timestamp?)?.toDate();
                final endTimeB = (dataB['endTime'] as Timestamp?)?.toDate();
                final availableOrdersB = dataB['availableOrders'] as int? ?? 0;
                final isBookingOpenedB = startTimeB != null && endTimeB != null && now.isAfter(startTimeB) && now.isBefore(endTimeB);
                final isActiveB = isBookingOpenedB && availableOrdersB > 0;

                if (isActiveA && !isActiveB) return -1;
                if (!isActiveA && isActiveB) return 1;

                final nameA = dataA['name']?.toString() ?? '';
                final nameB = dataB['name']?.toString() ?? '';
                return nameA.compareTo(nameB);
              });

              if (displayDocs.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Extra Menu',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                  ),
                  ValueListenableBuilder<Map<String, int>>( // Listen to _cartNotifier
                    valueListenable: _cartNotifier,
                    builder: (context, cartValue, child) {
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: crossAxisSpacing,
                          mainAxisSpacing: 16,
                          childAspectRatio: dynamicChildAspectRatio,
                        ),
                        itemCount: displayDocs.length,
                        itemBuilder: (context, index) {
                          final doc = displayDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final String itemPriceString;
                          final dynamic priceData = data['price'];
                          if (priceData is int || priceData is double) {
                            itemPriceString = priceData.toString();
                          } else if (priceData is String) {
                            itemPriceString = priceData;
                          } else {
                            itemPriceString = 'N/A';
                          }

                          final startTime = (data['startTime'] as Timestamp?)?.toDate();
                          final endTime = (data['endTime'] as Timestamp?)?.toDate();
                          final availableOrders = data['availableOrders'] as int? ?? 0;
                          final description = data['description'] ?? 'No description available.';
                          final imageUrl = data['imageUrl'] as String?;
                          final double? rating = (data['rating'] as num?)?.toDouble();

                          final isBookingOpened = startTime != null && endTime != null && now.isAfter(startTime) && now.isBefore(endTime);
                          final isAvailableInStock = availableOrders > 0;
                          final isActive = isBookingOpened && isAvailableInStock;

                          final cartKey = 'extra_menu_${doc.id}';
                          final int itemCount = cartValue[cartKey] ?? 0; // Use cartValue from ValueListenableBuilder

                          return _MenuItemCard(
                            itemName: data['name'] ?? 'Unnamed Item',
                            itemActualName: data['name'] ?? 'Unnamed Item',
                            itemPrice: itemPriceString,
                            imageUrl: imageUrl,
                            itemCount: itemCount,
                            isActive: isActive,
                            isAvailableInStock: isAvailableInStock,
                            canAddToCart: itemCount < availableOrders && isActive,
                            onAdd: () => onAddToCart(doc.id, 'extra_menu'),
                            onRemove: () => onRemoveFromCart(doc.id, 'extra_menu'),
                            description: description,
                            bookingClosingTime: endTime,
                            cardHeight: cardHeight,
                            cardWidth: cardWidth,
                            isGeneralMenuItem: false,
                            rating: rating,
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}


class _MenuItemCard extends StatelessWidget {
  final String itemName;
  final String itemActualName;
  final String itemPrice;
  final String? imageUrl;
  final int itemCount;
  final bool isActive;
  final bool isAvailableInStock;
  final bool canAddToCart;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final String description;
  final DateTime? bookingClosingTime;
  final double cardHeight;
  final double cardWidth;
  final bool isGeneralMenuItem;
  final double? rating;

  const _MenuItemCard({
    required this.itemName,
    required this.itemActualName,
    required this.itemPrice,
    this.imageUrl,
    required this.itemCount,
    required this.isActive,
    required this.isAvailableInStock,
    required this.canAddToCart,
    required this.onAdd,
    required this.onRemove,
    required this.description,
    this.bookingClosingTime,
    required this.cardHeight, // Crucial for sizing
    required this.cardWidth,  // Crucial for sizing
    required this.isGeneralMenuItem,
    this.rating,
  });

  void _showDetailsPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: EdgeInsets.zero,
          titlePadding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 0),
          title: Text(
            isGeneralMenuItem ? itemActualName : itemName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.fastfood, size: 80, color: Colors.grey)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Price: ₹$itemPrice",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (rating != null && rating! > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Rating: ${rating!.toStringAsFixed(1)}",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      const Text(
                        "Description:",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        description,
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      if (bookingClosingTime != null)
                        Text(
                          "Booking Closes At: ${DateFormat('h:mm a').format(bookingClosingTime!)}",
                          style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                        ),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Define min/max font sizes to control scaling.
    const double minItemNameFontSize = 10.0;
    const double maxItemNameFontSize = 13.0;
    const double minDetailsFontSize = 7.0;
    const double maxDetailsFontSize = 9.0;
    const double minPriceFontSize = 9.0;
    const double maxPriceFontSize = 12.0;
    const double minAddButtonTextSize = 9.0;
    const double maxAddButtonTextSize = 12.0;
    const double minIconSize = 13.0;
    const double maxIconSize = 16.0;
    const double minCounterTextSize = 11.0;
    const double maxCounterTextSize = 13.0;

    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetailsPopup(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section (takes 60% of the card's vertical space)
              Expanded(
                flex: 6,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.fastfood, size: 50, color: Colors.grey)),
                      ),
              ),
              // Text Content Section + Cart Controls (takes 40% of the card's vertical space)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space between children
                    mainAxisSize: MainAxisSize.max, // Take all available space within Expanded
                    children: [
                      // Item Name
                      Text(
                        isGeneralMenuItem ? itemActualName : itemName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: cardWidth * 0.1 > maxItemNameFontSize
                              ? maxItemNameFontSize
                              : (cardWidth * 0.1 < minItemNameFontSize ? minItemNameFontSize : cardWidth * 0.1),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),

                      // Item Price
                      Text(
                        "₹$itemPrice",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: cardWidth * 0.08 > maxPriceFontSize
                              ? maxPriceFontSize
                              : (cardWidth * 0.08 < minPriceFontSize ? minPriceFontSize : cardWidth * 0.08),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Rating
                      if (rating != null && rating! > 0)
                        Row(
                          children: [
                            Icon(Icons.star,
                                color: Colors.amber,
                                size: cardWidth * 0.07 > maxIconSize ? maxIconSize : cardWidth * 0.07),
                            const SizedBox(width: 4),
                            Text(
                              rating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: cardWidth * 0.07 > maxDetailsFontSize
                                    ? maxDetailsFontSize
                                    : (cardWidth * 0.07 < minDetailsFontSize ? minDetailsFontSize : cardWidth * 0.07),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      
                      // Spacer to push cart controls to the bottom
                      const Spacer(),

                      // Cart Controls
                      _buildCartControls(
                        context,
                        itemCount,
                        isActive,
                        isAvailableInStock,
                        canAddToCart,
                        onAdd,
                        onRemove,
                        cardWidth,
                        minAddButtonTextSize,
                        maxAddButtonTextSize,
                        minIconSize,
                        maxIconSize,
                        minCounterTextSize,
                        maxCounterTextSize,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartControls(
    BuildContext context,
    int itemCount,
    bool isActive,
    bool isAvailableInStock,
    bool canAddToCart,
    VoidCallback onAdd,
    VoidCallback onRemove,
    double cardWidth,
    double minAddButtonTextSize,
    double maxAddButtonTextSize,
    double minIconSize,
    double maxIconSize,
    double minCounterTextSize,
    double maxCounterTextSize,
  ) {
    if (!isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          isGeneralMenuItem ? 'Booking Closed' : 'Unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: cardWidth * 0.08 > maxAddButtonTextSize
                ? maxAddButtonTextSize
                : (cardWidth * 0.08 < minAddButtonTextSize ? minAddButtonTextSize : cardWidth * 0.08),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (!isAvailableInStock && !isGeneralMenuItem) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.8),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Out of Stock',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: cardWidth * 0.08 > maxAddButtonTextSize
                ? maxAddButtonTextSize
                : (cardWidth * 0.08 < minAddButtonTextSize ? minAddButtonTextSize : cardWidth * 0.08),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (itemCount > 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            icon: Icons.remove,
            onPressed: onRemove,
            iconSize: cardWidth * 0.09 > maxIconSize ? maxIconSize : (cardWidth * 0.09 < minIconSize ? minIconSize : cardWidth * 0.09),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '$itemCount',
              style: TextStyle(
                fontSize: cardWidth * 0.1 > maxCounterTextSize
                    ? maxCounterTextSize
                    : (cardWidth * 0.1 < minCounterTextSize ? minCounterTextSize : cardWidth * 0.1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildActionButton(
            icon: Icons.add,
            onPressed: canAddToCart ? onAdd : null,
            iconSize: cardWidth * 0.09 > maxIconSize ? maxIconSize : (cardWidth * 0.09 < minIconSize ? minIconSize : cardWidth * 0.09),
          ),
        ],
      );
    } else {
      return SizedBox( // Use SizedBox here to ensure consistent height for the button
        width: double.infinity,
        height: cardWidth * 0.12, // Approximate height for the button to be consistent
        child: ElevatedButton(
          onPressed: canAddToCart ? onAdd : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canAddToCart ? Theme.of(context).primaryColor : Colors.grey,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            padding: EdgeInsets.zero, // Remove default padding to let content control size
          ),
          child: Text(
            'Add to Cart',
            style: TextStyle(
              fontSize: cardWidth * 0.08 > maxAddButtonTextSize
                  ? maxAddButtonTextSize
                  : (cardWidth * 0.08 < minAddButtonTextSize ? minAddButtonTextSize : cardWidth * 0.08),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double iconSize,
  }) {
    // Ensure the button itself has a fixed size based on iconSize
    final double buttonSize = iconSize * 1.8; // A factor to make the circle larger than the icon
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: FittedBox( // Use FittedBox to scale the IconButton if necessary
        child: IconButton(
          icon: Icon(icon, color: Colors.green),
          onPressed: onPressed,
          padding: EdgeInsets.zero, // Essential for tight spacing
          constraints: const BoxConstraints(), // Removes default minimum constraints
        ),
      ),
    );
  }
}