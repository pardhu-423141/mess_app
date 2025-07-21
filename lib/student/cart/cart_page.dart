import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_viewmodel.dart';
import 'cart_item_tile.dart';
import 'cart_helpers.dart';
import '../paymentPage.dart';
import '../../utils/meal_utils.dart'; // Assuming this provides getMealTimings and getMealCodes

class CartPage extends StatefulWidget {
  final Map<String, int> cart;
  final Function(Map<String, int>) onCartUpdated;

  const CartPage({
    super.key,
    required this.cart,
    required this.onCartUpdated,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with WidgetsBindingObserver {
  final CartViewModel _viewModel = CartViewModel();
  String? _currentUserId; // To store the current user ID for reservation management

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observe lifecycle events
    _viewModel.setCart(widget.cart);
    _fetchCartItems();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid; // Get user ID on init
    _checkForExpiredSession(); // Check for expired session on entering cart
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle app lifecycle changes (e.g., termination, background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // App is going to background or terminating.
      // We rely on the server-side cleanup for truly terminated apps.
      // However, we can also attempt a rollback if the user simply leaves the app.
      
    }
  }

  Future<void> _checkForExpiredSession() async {
    if (_currentUserId == null) return;

    final docRef = FirebaseFirestore.instance.collection('extra_reservations').doc(_currentUserId);
    final doc = await docRef.get();

    if (doc.exists && doc.data()?['status'] == 'pending') {
      final timestamp = (doc.data()?['timestamp'] as Timestamp?)?.toDate();
      if (timestamp != null && DateTime.now().difference(timestamp).inMinutes >= 5) {
        // Session expired, rollback and delete reservation
        await deleteReservation(_currentUserId!); // Explicitly delete the reservation
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.info, color: Colors.orange, size: 60),
              title: const Text('Session Expired!'),
              content: const Text('Your previous payment session has expired. Please try again.'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Optionally clear cart or refresh data
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }


  Future<void> _fetchCartItems() async {
    setState(() => _viewModel.isLoading = true);
    final Map<String, dynamic> fetchedData = {};

    try {
      for (final key in _viewModel.cart.keys) {
        final parts = key.split('_');
        if (parts.length < 2) continue;

        String collection = (parts[0] == 'extra') ? 'extra_menu' : 'general_menu';
        String itemId = parts.last;

        final doc = await FirebaseFirestore.instance.collection(collection).doc(itemId).get();
        if (doc.exists && doc.data() != null) {
          fetchedData[key] = doc.data()!;
        }
      }
    } catch (e) {
      debugPrint('Error fetching cart items: $e');
    }

    setState(() {
      _viewModel.itemsData = fetchedData;
      _viewModel.dataFetched = true;
      _viewModel.isLoading = false;
    });
  }

  Future<void> _handleProceedToPay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please log in to proceed with payment.")),
        );
      }
      return;
    }
    _currentUserId = user.uid; // Ensure user ID is set

    // Rollback any existing pending reservation for this user before creating a new one
    

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final gender = userDoc.data()?['mess'] == 'male' ? '1' : '0';

    final nowTime = TimeOfDay.now();
    String? mealName;
    getMealTimings().forEach((name, range) {
      if (isWithinRange(nowTime, range.start, range.end)) {
        mealName = name;
      }
    });

    if (mealName == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Current time doesn't fall into any meal slot.")),
        );
      }
      return;
    }

    final mealType = getMealCodes()[mealName!].toString();
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}";
    final baseId = "$dateStr$gender$mealType";

    final existing = await FirebaseFirestore.instance
        .collection('orders')
        .where('order_id', isGreaterThanOrEqualTo: baseId)
        .where('order_id', isLessThan: baseId + '9999')
        .get();
    final orderId = "$baseId${(existing.docs.length + 1).toString().padLeft(4, '0')}";

    List<Map<String, dynamic>> generalList = [];
    List<Map<String, dynamic>> extraList = [];
    Map<String, int> extraToReserve = {}; // Items to reserve

    for (final entry in _viewModel.cart.entries) {
      final parts = entry.key.split('_');
      if (parts.length < 3) continue;

      final isExtra = parts[0] == 'extra';
      final collection = isExtra ? 'extra_menu' : 'general_menu';
      final itemId = parts[2];
      final quantity = entry.value;

      final snapshot = await FirebaseFirestore.instance.collection(collection).doc(itemId).get();
      if (!snapshot.exists || snapshot.data() == null) continue;

      final data = snapshot.data()!;
      final item = {
        'itemId': itemId,
        'name': isExtra ? data['name'] : mealName,
        'quantity': quantity,
        'rated': false,
        'price': data['price'], // Assuming price is available in item data
      };

      if (isExtra) {
        extraList.add(item);
        extraToReserve[itemId] = quantity;
      } else {
        generalList.add(item);
      }
    }

    // Reserve extra items only if there are any
    if (extraToReserve.isNotEmpty) {
      final reserved = await reserveExtraItems(user.uid, extraToReserve);
      if (!reserved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Reservation failed. Not enough stock for some items. Please try again.")),
          );
        }
        return;
      }
    }

    final orderData = {
      'order_id': orderId,
      'user_id': user.uid,
      'amount': _viewModel.calculateTotal(),
      'created on': now,
      'status': 'not served',
      'QR_id': FirebaseFirestore.instance.collection('orders').doc().id, // Generate a unique QR ID
      'general_menu': generalList.isEmpty ? 'nil' : generalList,
      'extra_menu': extraList.isEmpty ? 'nil' : extraList,
      'payment_status': 'NOT_PAID',
    };

    // Store order data before proceeding to payment
    await FirebaseFirestore.instance.collection('orders').doc(orderId).set(orderData);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CashfreePaymentScreen(
          amount: _viewModel.calculateTotal(),
          orderId: orderId,
        ),
      ),
    );

    if (result != null && result['status'] == 'SUCCESS') {
      await markReservationCompleted(user.uid); // Mark reservation as completed
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            title: const Text('Payment Successful!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Amount Paid: ₹${_viewModel.calculateTotal().toStringAsFixed(2)}'),
                const SizedBox(height: 10),
                const Text('Your order has been placed successfully!'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _viewModel.cart); // Pop dialog
                  setState(() {
                    _viewModel.cart.clear();
                    _viewModel.itemsData.clear();
                  });
                  _viewModel.updateCart(widget.onCartUpdated);
                  Navigator.pop(context, _viewModel.cart); // Pop CartPage
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } else {
      // Payment failed or cancelled: Rollback items and delete reservation
      if (extraToReserve.isNotEmpty) {
        await rollbackExtraItems(extraToReserve);
      }
      await deleteReservation(user.uid); // Delete the pending reservation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed or cancelled. Items have been unreserved.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.cart.isEmpty && _viewModel.dataFetched) return _emptyCartUI();
    if (_viewModel.isLoading && !_viewModel.dataFetched) return _loadingUI();
    if (_viewModel.cart.isNotEmpty && _viewModel.itemsData.isEmpty && _viewModel.dataFetched) return _errorUI();

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart (${_viewModel.cart.length})'),
        actions: [
          TextButton(
            onPressed: () {
              if (_viewModel.cart.isEmpty) return;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Clear Cart'),
                  content: const Text('Are you sure you want to remove all items?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        setState(() {
                          _viewModel.cart.clear();
                          _viewModel.itemsData.clear();
                        });
                        _viewModel.updateCart(widget.onCartUpdated);
                        Navigator.pop(context, _viewModel.cart);
                        // If clearing cart, also attempt to rollback and delete any pending reservation
                        if (_currentUserId != null) {
                          await deleteReservation(_currentUserId!);
                        }
                      },
                      child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _viewModel.cart.length,
              itemBuilder: (context, index) {
                final key = _viewModel.cart.keys.elementAt(index);
                final item = _viewModel.itemsData[key];
                final qty = _viewModel.cart[key]!;
                if (item == null) return const SizedBox.shrink();
                return CartItemTile(
                  itemData: item,
                  quantity: qty,
                  onAdd: () {
                    setState(() {
                      _viewModel.addToCart(key);
                      _viewModel.updateCart(widget.onCartUpdated);
                    });
                  },
                  onRemove: () {
                    setState(() {
                      _viewModel.removeFromCart(key);
                      _viewModel.updateCart(widget.onCartUpdated);
                    });
                  },
                  onDelete: () {
                    setState(() {
                      _viewModel.removeItemCompletely(key);
                      _viewModel.updateCart(widget.onCartUpdated);
                    });
                  },
                );
              },
            ),
          ),
          _buildTotalAndPayButton(),
        ],
      ),
    );
  }

  Widget _buildTotalAndPayButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '₹${_viewModel.calculateTotal().toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _viewModel.isLoading ? null : _handleProceedToPay,
              child: _viewModel.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Proceed to Pay'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCartUI() => const Scaffold(
        body: Center(child: Text('Your cart is empty')),
      );

  Widget _loadingUI() => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );

  Widget _errorUI() => const Scaffold(
        body: Center(child: Text('Failed to load cart items')),
      );
}