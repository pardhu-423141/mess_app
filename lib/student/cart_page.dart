import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class _CartPageState extends State<CartPage> {
  Map<String, int> _cart = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cart = Map.from(widget.cart);
  }

  void _updateCart() {
    widget.onCartUpdated(_cart);
  }

  void _addToCart(String cartKey) {
    setState(() {
      _cart.update(cartKey, (value) => value + 1, ifAbsent: () => 1);
    });
    _updateCart();
  }

  void _removeFromCart(String cartKey) {
    setState(() {
      if (_cart.containsKey(cartKey)) {
        if (_cart[cartKey]! > 1) {
          _cart[cartKey] = _cart[cartKey]! - 1;
        } else {
          _cart.remove(cartKey);
        }
      }
    });
    _updateCart();
  }

  void _removeItemCompletely(String cartKey) {
    setState(() {
      _cart.remove(cartKey);
    });
    _updateCart();
  }

  Future<Map<String, dynamic>> _fetchCartItems() async {
    final Map<String, dynamic> itemsData = {};
    
    try {
      print('Cart keys: ${_cart.keys.toList()}'); // Debug print
      
      for (String cartKey in _cart.keys) {
        print('Processing cart key: $cartKey'); // Debug print
        
        final parts = cartKey.split('_');
        if (parts.length < 2) {
          print('Invalid cart key format: $cartKey');
          continue;
        }
        
        // Map cart key prefixes to actual Firestore collection names
        String collection;
        String itemId;
        
        if (parts.length >= 3) {
          // Handle format like: general_menu_111 or extra_menu_201
          if (parts[0] == 'general' && parts[1] == 'menu') {
            collection = 'general_menu';
            itemId = parts[2]; // Just the ID part
          } else if (parts[0] == 'extra' && parts[1] == 'menu') {
            collection = 'extra_menu';
            itemId = parts[2]; // Just the ID part
          } else {
            print('Unknown collection format for cart key: $cartKey');
            continue;
          }
        } else {
          // Handle legacy format like: general_111 or extra_201
          if (parts[0] == 'general') {
            collection = 'general_menu';
            itemId = parts[1];
          } else if (parts[0] == 'extra') {
            collection = 'extra_menu';
            itemId = parts[1];
          } else {
            print('Unknown collection prefix for cart key: $cartKey');
            continue;
          }
        }
        
        print('Collection: $collection, ItemId: $itemId'); // Debug print
        
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(itemId)
            .get();
            
        print('Document exists: ${doc.exists}'); // Debug print
        
        if (doc.exists && doc.data() != null) {
          itemsData[cartKey] = doc.data()!;
          print('Added item data for: $cartKey'); // Debug print
        } else {
          print('Document not found or empty for: $collection/$itemId');
        }
      }
      
      print('Total items loaded: ${itemsData.length}'); // Debug print
      
    } catch (e) {
      print('Error fetching cart items: $e');
      print('Stack trace: ${StackTrace.current}');
    }
    
    return itemsData;
  }

  double _calculateTotal(Map<String, dynamic> itemsData) {
    double total = 0.0;
    for (String cartKey in _cart.keys) {
      final quantity = _cart[cartKey] ?? 0;
      final itemData = itemsData[cartKey];
      if (itemData != null && itemData['price'] != null) {
        double price = 0.0;
        if (itemData['price'] is String) {
          price = double.tryParse(itemData['price']) ?? 0.0;
        } else if (itemData['price'] is num) {
          price = (itemData['price'] as num).toDouble();
        }
        total += price * quantity;
      }
    }
    return total;
  }

  Future<void> _proceedToPay(double totalAmount) async {
    setState(() {
      _isLoading = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        title: const Text('Payment Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount Paid: ₹${totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            const Text('Your order has been placed successfully!'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              setState(() {
                _cart.clear();
              });
              _updateCart();
              Navigator.of(context).pop(); // Go back to dashboard
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Cart'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 10),
              Text(
                'Add some delicious items to get started!',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Cart (${_cart.length} items)'),
        actions: [
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Cart'),
                  content: const Text('Are you sure you want to remove all items from your cart?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _cart.clear();
                        });
                        _updateCart();
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.red)),
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
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchCartItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final itemsData = snapshot.data ?? {};
                
                print('Items data received: ${itemsData.keys.toList()}'); // Debug print
                
                if (itemsData.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.orange),
                        SizedBox(height: 16),
                        Text(
                          'Unable to load cart items',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please check your internet connection and try again',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cart.length,
                  separatorBuilder: (context, index) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final cartEntry = _cart.entries.elementAt(index);
                    final cartKey = cartEntry.key;
                    final quantity = cartEntry.value;
                    
                    final itemData = itemsData[cartKey];
                    if (itemData == null) return const SizedBox.shrink();

                    // Handle price conversion - it might be stored as String or num
                    double price = 0.0;
                    if (itemData['price'] != null) {
                      if (itemData['price'] is String) {
                        price = double.tryParse(itemData['price']) ?? 0.0;
                      } else if (itemData['price'] is num) {
                        price = (itemData['price'] as num).toDouble();
                      }
                    }
                    
                    final itemTotal = price * quantity;

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Item Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: itemData['photo'] != null
                                  ? Image.network(
                                      itemData['photo'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => 
                                          const Icon(Icons.fastfood, size: 60),
                                    )
                                  : const Icon(Icons.fastfood, size: 60),
                            ),
                            const SizedBox(width: 12),
                            
                            // Item Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemData['name']?.toString() ?? 
                                    itemData['description']?.toString() ?? 
                                    'Unnamed Item',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹$price each',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (itemData['rating'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 16),
                                        Text(
                                          ' ${itemData['rating']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    'Total: ₹${itemTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Quantity Controls
                            Column(
                              children: [
                                // Remove item button
                                IconButton(
                                  onPressed: () => _removeItemCompletely(cartKey),
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Remove item',
                                ),
                                const SizedBox(height: 8),
                                
                                // Quantity controls
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () => _removeFromCart(cartKey),
                                        icon: const Icon(Icons.remove),
                                        iconSize: 18,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          quantity.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _addToCart(cartKey),
                                        icon: const Icon(Icons.add),
                                        iconSize: 18,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
          
          // Bottom Section with Total and Pay Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchCartItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final itemsData = snapshot.data!;
                final total = _calculateTotal(itemsData);

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _proceedToPay(total),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Proceed to Pay',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}