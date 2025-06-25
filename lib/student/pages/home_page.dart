import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../login_page.dart';
import '../../services/notification_service.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _cartItemCount = 0;
  Map<String, int> _cart = {};
  late TabController _tabController;
  bool _hasShownCartPrompt = false;
  String _userGender = '1'; // Default to boy (1), will be fetched from Firestore

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
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
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

      _showPermissionDialog(prefs);
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
        content: const Text(
            'Enable notifications to stay informed about announcements and deadlines.'),
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
                if (mounted) Navigator.of(context).pop();
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
      _cartItemCount = _cart.values.fold(0, (sum, quantity) => sum + quantity);
    });
    
    // Show "Go to Cart" prompt after first item is added
    if (!_hasShownCartPrompt) {
      _hasShownCartPrompt = true;
      _showGoToCartPrompt();
    }
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
        _cartItemCount = _cart.values.fold(0, (sum, quantity) => sum + quantity);
      }
      
      // Reset prompt flag if cart becomes empty
      if (_cartItemCount == 0) {
        _hasShownCartPrompt = false;
      }
    });
  }

  void _showGoToCartPrompt() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Item added to cart! 🛒'),
        action: SnackBarAction(
          label: 'Go to Cart',
          onPressed: () => _navigateToCart(),
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

void _navigateToCart() {
  Navigator.pushNamed(
    context,
    '/cart',
    arguments: {
      'cart': _cart,
      'onCartUpdated': (Map<String, int> updatedCart) {
        // This callback will be called when cart is updated from CartPage
        if (mounted) {
          setState(() {
            _cart = updatedCart;
            _cartItemCount = _cart.values.fold(0, (sum, quantity) => sum + quantity);
            if (_cartItemCount == 0) {
              _hasShownCartPrompt = false;
            }
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () => _showProfileMenu(user, name, email),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Extra Menu'),
              Tab(text: 'General Menu'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ExtraMenuPage(
              cart: _cart,
              onAddToCart: (menuId) => _addToCart(menuId, 'extra_menu'),
              onRemoveFromCart: (menuId) => _removeFromCart(menuId, 'extra_menu'),
              userGender: _userGender,
            ),
            _GeneralMenuPage(
              cart: _cart,
              onAddToCart: (menuId) => _addToCart(menuId, 'general_menu'),
              onRemoveFromCart: (menuId) => _removeFromCart(menuId, 'general_menu'),
              userGender: _userGender,
            ),
          ],
        ),

        // Floating button appears only if there's at least one item
        floatingActionButton: _cartItemCount > 0
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.shopping_cart_checkout),
                label: Text('Go to Cart ($_cartItemCount)'),
                onPressed: _navigateToCart,
                backgroundColor: Colors.green,
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
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
            if (user?.photoURL != null) ...[
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(user!.photoURL!),
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
  final Function(String) onAddToCart;
  final Function(String) onRemoveFromCart;
  final String userGender;

  const _ExtraMenuPage({
    required this.cart,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.userGender,
  });

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> data, DateTime? endTime) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  data['name'] ?? 'Item Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildDetail('Price', '₹${data['price']}', Colors.green[800]!),
              if (data['rating'] != null)
                _buildDetail('Rating', data['rating'].toString(), Colors.deepPurple),
              if (data['description'] != null && data['description'].toString().trim().isNotEmpty)
                _buildDetail('Description', data['description'], Colors.black87),
              if (endTime != null)
                _buildDetail(
                  'Available Until',
                  '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                  Colors.orange[800]!,
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    textStyle: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  child: const Text('Close'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
            TextSpan(text: value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('extra_menu').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No extra menu items available."));
        }

        final docs = snapshot.data!.docs;
        final now = DateTime.now();

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final genderInDoc = data['gender']?.toString();
          return genderInDoc == userGender;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("No items available for your category."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final startTime = (data['startTime'] as Timestamp?)?.toDate();
            final endTime = (data['endTime'] as Timestamp?)?.toDate();
            final availableOrders = data['availableOrders'] ?? 0;

            final isActive = startTime != null &&
                endTime != null &&
                now.isAfter(startTime) &&
                now.isBefore(endTime) && availableOrders > 0;

            final cartKey = 'extra_menu_${doc.id}';
            final itemCount = cart[cartKey] ?? 0;
            final isAvailable = itemCount < availableOrders;

            return Card(
              elevation: 4,
              color: isActive ? Colors.white : Colors.grey[300],
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: data['photo'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['photo'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.fastfood),
                        ),
                      )
                    : const Icon(Icons.fastfood),
                title: Text(
                  data['name'] ?? 'Unnamed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Price: ₹${data['price'] ?? 0}",
                        style: const TextStyle(color: Colors.green)),
                    if (data['rating'] != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(' ${data['rating']}'),
                        ],
                      ),
                    TextButton.icon(
                      onPressed: () => _showDetailsDialog(context, data, endTime),
                      icon: const Icon(Icons.info_outline, color: Colors.blue),
                      label: const Text(
                        "Details",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
                trailing: isActive 
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.red),
                              onPressed: itemCount > 0
                                  ? () => onRemoveFromCart(doc.id)
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                itemCount.toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.green),
                              onPressed: isAvailable
                                  ? () => onAddToCart(doc.id)
                                  : () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('No more orders available!'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Unavailable',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}



class _GeneralMenuPage extends StatefulWidget {
  final Map<String, int> cart;
  final Function(String) onAddToCart;
  final Function(String) onRemoveFromCart;
  final String userGender;

  const _GeneralMenuPage({
    required this.cart,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.userGender,
  });

  @override
  State<_GeneralMenuPage> createState() => _GeneralMenuPageState();
}

class _GeneralMenuPageState extends State<_GeneralMenuPage> {
  final Map<String, String> dayMap = {
    "Monday": "1",
    "Tuesday": "2",
    "Wednesday": "3",
    "Thursday": "4",
    "Friday": "5",
    "Saturday": "6",
    "Sunday": "7",
  };

  final Map<String, String> mealMap = {
    "Breakfast": "1",
    "Lunch": "2",
    "Snacks": "3",
    "Dinner": "4",
  };

  late String selectedDay;
  String selectedMeal = "Breakfast";

  @override
  void initState() {
    super.initState();
    String today = DateFormat('EEEE').format(DateTime.now());
    selectedDay = dayMap.keys.contains(today) ? today : "Monday";
  }

  @override
  Widget build(BuildContext context) {
    String dayCode = dayMap[selectedDay]!;
    String mealCode = mealMap[selectedMeal]!;
    String menuId = "$dayCode$mealCode${widget.userGender}"; // Uses user's gender

    return Column(
      children: [
        // Day Selector
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: dayMap.keys.map((day) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: ChoiceChip(
                  label: Text(day),
                  selected: selectedDay == day,
                  onSelected: (_) {
                    setState(() {
                      selectedDay = day;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Meal Selector
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: mealMap.keys.map((meal) {
              return ChoiceChip(
                label: Text(meal),
                selected: selectedMeal == meal,
                onSelected: (_) {
                  setState(() {
                    selectedMeal = meal;
                  });
                },
              );
            }).toList(),
          ),
        ),

        const Divider(),

        // Menu Details
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('general_menu')
                .doc(menuId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text("No menu available for this time."));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final cartKey = 'general_menu_$menuId';
              final itemCount = widget.cart[cartKey] ?? 0;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (data['photo'] != null)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          child: Image.network(
                            data['photo'],
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 100),
                          ),
                        ),
                      ListTile(
                        title: Text(data['description'] ?? 'No description'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text("Price: ₹${data['price']}"),
                            if (data['rating'] != null)
                              Text("Rating: ${data['rating']}"),
                          ],
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.red),
                                onPressed: itemCount > 0
                                    ? () => widget.onRemoveFromCart(menuId)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  itemCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.green),
                                onPressed: () => widget.onAddToCart(menuId),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}