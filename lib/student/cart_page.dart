import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartPage extends StatefulWidget {
  final Map<String, int> cart;
  final Function(Map<String, int>) onCartUpdated;

  const CartPage({
    super.key,
    required this.cart,
    required this.onCartUpdated,
  });

  // Static method to handle route creation
  static Route<dynamic> route(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>;
    return MaterialPageRoute(
      builder: (context) {
        return CartPage(
          cart: args['cart'],
          onCartUpdated: args['onCartUpdated'],
        );
      },
    );
  }

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late Map<String, int> _cart;
  double _totalAmount = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cart = Map.from(widget.cart);
    _fetchCartItems();
  }

  Future<void> _fetchCartItems() async {
    setState(() => _isLoading = true);
    double total = 0.0;

    try {
      for (var entry in _cart.entries) {
        final parts = entry.key.split('_');
        if (parts.length != 2) continue;

        final collection = parts[0]; // 'extra_menu' or 'general_menu'
        final menuId = parts[1];
        final quantity = entry.value;

        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(menuId)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final price = (data['price'] as num?)?.toDouble() ?? 0.0;
          total += price * quantity;
        }
      }
    } catch (e) {
      debugPrint('Error fetching cart items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading cart items')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _totalAmount = total;
        _isLoading = false;
      });
    }
  }

  void _updateQuantity(String key, int newQuantity) {
    setState(() {
      if (newQuantity > 0) {
        _cart[key] = newQuantity;
      } else {
        _cart.remove(key);
      }
    });
    _fetchCartItems();
  }

  void _proceedToCheckout() {
    widget.onCartUpdated(_cart);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Text('Total amount: ₹${_totalAmount.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _placeOrder();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add({
            'userId': user.uid,
            'items': _cart,
            'totalAmount': _totalAmount,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _cart.clear();
        _totalAmount = 0.0;
      });
      widget.onCartUpdated(_cart);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${orderRef.id} placed successfully!'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to place order. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onCartUpdated(_cart);
            Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cart.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final key = _cart.keys.elementAt(index);
                          final parts = key.split('_');
                          final collection = parts[0];
                          final menuId = parts[1];
                          final quantity = _cart[key]!;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection(collection)
                                .doc(menuId)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const ListTile(
                                  leading: CircularProgressIndicator(),
                                  title: Text('Loading...'),
                                );
                              }

                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                return ListTile(
                                  title: Text('Item not found ($key)'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _updateQuantity(key, 0),
                                  ),
                                );
                              }

                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              final name = data['name'] ?? 'Unnamed Item';
                              final price = (data['price'] as num?)?.toDouble() ?? 0.0;
                              final photo = data['photo'];

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ListTile(
                                  leading: photo != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            photo,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.fastfood),
                                          ),
                                        )
                                      : const Icon(Icons.fastfood),
                                  title: Text(name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Price: ₹$price'),
                                      Text('Subtotal: ₹${(price * quantity).toStringAsFixed(2)}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove),
                                        onPressed: () => _updateQuantity(key, quantity - 1),
                                      ),
                                      Text(quantity.toString()),
                                      IconButton(
                                        icon: const Icon(Icons.add),
                                        onPressed: () => _updateQuantity(key, quantity + 1),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    _buildCheckoutSection(),
                  ],
                ),
    );
  }

  Widget _buildCheckoutSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${_totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _proceedToCheckout,
              child: const Text(
                'Proceed to Checkout',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}