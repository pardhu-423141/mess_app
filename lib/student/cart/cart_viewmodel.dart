import 'package:flutter/material.dart';

class CartViewModel extends ChangeNotifier {
  Map<String, int> cart = {};
  Map<String, dynamic> itemsData = {};
  bool isLoading = false;
  bool dataFetched = false;

  void setCart(Map<String, int> initialCart) {
    cart = Map.from(initialCart);
    notifyListeners();
  }

  void updateCart(Function(Map<String, int>) onCartUpdated) {
    onCartUpdated(cart);
  }

  void addToCart(String key) {
    final item = itemsData[key];
    if (item != null && item.containsKey('availableOrders')) {
      int available = item['availableOrders'];
      int current = cart[key] ?? 0;
      if (current < available) {
        cart.update(key, (v) => v + 1, ifAbsent: () => 1);
        notifyListeners();
      }
    } else {
      cart.update(key, (v) => v + 1, ifAbsent: () => 1);
      notifyListeners();
    }
  }

  void removeFromCart(String key) {
    if (cart.containsKey(key)) {
      if (cart[key]! > 1) {
        cart[key] = cart[key]! - 1;
      } else {
        cart.remove(key);
        itemsData.remove(key);
      }
      notifyListeners();
    }
  }

  void removeItemCompletely(String key) {
    cart.remove(key);
    itemsData.remove(key);
    notifyListeners();
  }

  double calculateTotal() {
    double total = 0.0;
    for (var key in cart.keys) {
      final item = itemsData[key];
      final qty = cart[key] ?? 0;
      if (item != null && item['price'] != null) {
        double price = item['price'] is String
            ? double.tryParse(item['price']) ?? 0.0
            : (item['price'] as num).toDouble();
        total += price * qty;
      }
    }
    return total;
  }
}
