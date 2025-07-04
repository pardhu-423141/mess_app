import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../login_page.dart';
import '../../services/notification_service.dart';
import '../../manager/add_extra_menu.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _cartItemCount = 0;
  Map<String, int> _cart = {};
  late TabController _tabController;
  String _userGender = '1';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeNotifications();
    _fetchUserGender();
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

      if (alreadyPrompted || isGranted || !mounted) return;

      if (mounted) {
        _showPermissionDialog(prefs);
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
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

  void _addToCart(String menuId, String collection) {
    final cartKey = '${collection}_$menuId';
    setState(() {
      _cart.update(cartKey, (value) => value + 1, ifAbsent: () => 1);
      _updateCartItemCount();
    });
  }

  void _removeFromCart(String menuId, String collection) {
    final cartKey = '${collection}_$menuId';
    setState(() {
      if (_cart.containsKey(cartKey)) {
        if (_cart[cartKey]! > 1) {
          _cart[cartKey] = _cart[cartKey]! - 1;
        } else {
          _cart.remove(cartKey);
        }
        _updateCartItemCount();
      }
    });
  }

  void _updateCartItemCount() {
    _cartItemCount = _cart.values.fold(0, (sum, quantity) => sum + quantity);
  }

  void _navigateToCart() {
    Navigator.pushNamed(
      context,
      '/cart',
      arguments: {
        'cart': _cart,
        'onCartUpdated': (Map<String, int> updatedCart) {
          if (mounted) {
            setState(() {
              _cart = updatedCart;
              _updateCartItemCount();
            });
          }
        },
      },
    );
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
      body: _ExtraMenuPage(
        cart: _cart,
        onAddToCart: (menuId, collection) => _addToCart(menuId, collection),
        onRemoveFromCart: (menuId, collection) => _removeFromCart(menuId, collection),
        userGender: _userGender,
      ),
      floatingActionButton: _cartItemCount > 0
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.shopping_cart_checkout),
              label: Text('Go to Cart ($_cartItemCount)'),
              onPressed: _navigateToCart,
              backgroundColor: Colors.green,
            )
          : null,
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

class _ExtraMenuPage extends StatelessWidget {
  final Map<String, int> cart;
  final Function(String, String) onAddToCart;
  final Function(String, String) onRemoveFromCart;
  final String userGender;

  const _ExtraMenuPage({
    required this.cart,
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
                  final int itemCount = cart[cartKey] ?? 0;

                  return _MenuItemCard(
                    itemName: currentMeal,
                    itemActualName: data['name'] ?? 'Unnamed Daily Meal',
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
          ),
          // --- Extra Menu Section ---
          // NEW: StreamBuilder for Extra Menu to determine if the section should be shown
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
                return const SizedBox.shrink(); // Hide if no data at all
              }

              final docs = snapshot.data!.docs;
              final List<DocumentSnapshot> displayDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final genderMatch = data['gender']?.toString() == userGender;
                final mealMatch = data['mealType']?.toString() == currentMeal;
                final hasRequiredFields = data.containsKey('name') && data.containsKey('price');

                final startTime = (data['startTime'] as Timestamp?)?.toDate();
                final endTime = (data['endTime'] as Timestamp?)?.toDate();
                final availableOrders = data['availableOrders'] as int? ?? 0;

                final isBookingOpened = startTime != null && endTime != null && now.isAfter(startTime) && now.isBefore(endTime);
                final isAvailableInStock = availableOrders > 0;
                final isActive = isBookingOpened && isAvailableInStock; // Item must be active and in stock

                return genderMatch && mealMatch && hasRequiredFields && isActive; // Only include active items
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

              // NEW: Conditional rendering of the entire "Extra Menu" section
              if (displayDocs.isEmpty) {
                return const SizedBox.shrink(); // Hide the entire section if no active items
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20), // Spacer before the header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Extra Menu',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                  ),
                  GridView.builder(
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
                      final int itemCount = cart[cartKey] ?? 0;

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
    required this.cardHeight,
    required this.cardWidth,
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
                              Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Rating: ${rating!.toStringAsFixed(1)}",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    final double imageSectionHeight = cardHeight * 0.60;
    final double nameSectionHeight = cardHeight * 0.10;
    final double detailsSectionHeight = cardHeight * 0.07;

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

    const double horizontalContentPadding = 4.0;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: imageSectionHeight,
            child: Stack(
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: imageSectionHeight,
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
                      child: Center(child: Icon(Icons.broken_image, size: cardHeight * 0.15, color: Colors.grey)),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: imageSectionHeight,
                    color: Colors.grey[200],
                    child: Center(child: Icon(Icons.fastfood, size: cardHeight * 0.15, color: Colors.grey)),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: rating != null && rating! > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.yellow, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                rating!.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      "₹$itemPrice",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: (imageSectionHeight * 0.08).clamp(minPriceFontSize, maxPriceFontSize),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: nameSectionHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalContentPadding, vertical: 1.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  itemName,
                  style: TextStyle(
                    fontSize: (nameSectionHeight * 0.6).clamp(minItemNameFontSize, maxItemNameFontSize),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          SizedBox(
            height: detailsSectionHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalContentPadding, vertical: 0.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () {
                    debugPrint('Details text tapped for: ${isGeneralMenuItem ? itemActualName : itemName}');
                    _showDetailsPopup(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue,
                          size: (detailsSectionHeight * 0.8).clamp(minDetailsFontSize + 1, maxDetailsFontSize + 1)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          'Details',
                          style: TextStyle(
                            fontSize: (detailsSectionHeight * 0.6).clamp(minDetailsFontSize, maxDetailsFontSize),
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double addOptionAvailableHeight = constraints.maxHeight;

                final double addButtonTextSize =
                    (addOptionAvailableHeight * 0.35).clamp(minAddButtonTextSize, maxAddButtonTextSize);
                final double iconSize = (addOptionAvailableHeight * 0.45).clamp(minIconSize, maxIconSize);
                final double counterTextSize =
                    (addOptionAvailableHeight * 0.38).clamp(minCounterTextSize, maxCounterTextSize);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalContentPadding, vertical: 0.0),
                  child: Center(
                    child: isActive
                        ? itemCount == 0
                            ? SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: canAddToCart ? onAdd : null,
                                  style: ElevatedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    backgroundColor: Colors.lightGreen[400],
                                    foregroundColor: Colors.white,
                                    textStyle:
                                        TextStyle(fontSize: addButtonTextSize, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    minimumSize:
                                        Size.fromHeight(addOptionAvailableHeight * 0.8),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Add'),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle),
                                    color: Colors.redAccent,
                                    onPressed: itemCount > 0 ? onRemove : null,
                                    iconSize: iconSize,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(minWidth: iconSize, minHeight: iconSize),
                                    splashRadius: iconSize * 0.7,
                                  ),
                                  Flexible(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 1.0),
                                      child: Text(
                                        itemCount.toString(),
                                        style: TextStyle(fontSize: counterTextSize, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle),
                                    color: Colors.green,
                                    onPressed: canAddToCart ? onAdd : null,
                                    iconSize: iconSize,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(minWidth: iconSize, minHeight: iconSize),
                                    splashRadius: iconSize * 0.7,
                                  ),
                                ],
                              )
                        : Text(
                            isAvailableInStock ? "Not available now" : "Sold Out",
                            style: TextStyle(color: Colors.grey, fontSize: addButtonTextSize),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}