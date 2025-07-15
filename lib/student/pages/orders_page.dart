import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/meal_utils.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }



  bool _isOrderExpired(Timestamp timestamp) {
    final DateTime orderTime = timestamp.toDate();
    final now = DateTime.now();
    final mealTimes = getMealTimings();
    for (var range in mealTimes.values) {
      // Ensure we are comparing dates on the same day for meal timings
      final start = DateTime(orderTime.year, orderTime.month, orderTime.day, range.start.hour, range.start.minute);
      final end = DateTime(orderTime.year, orderTime.month, orderTime.day, range.end.hour, range.end.minute);

      // Check if the order was placed within a meal time range
      if (orderTime.isAfter(start.subtract(const Duration(seconds: 1))) && orderTime.isBefore(end.add(const Duration(seconds: 1)))) {
        return now.isAfter(end);
      }
    }
    // If the order time doesn't fall within any defined meal window, consider it expired
    // or handle as per your application's logic. For now, returning true.
    // If the order time doesn't fall within any defined meal window, consider it expired
    // or handle as per your application's logic. For now, returning true.
    return true;
  }

  void _showQRDialog(Map<String, dynamic> orderData) {
    final qrPayload = {
      'order_id': orderData['order_id'],
      'amount': orderData['amount'],
      'user_id': orderData['user_id'],
      'timestamp': (orderData['created on'] as Timestamp)
          .toDate()
          .toIso8601String(),
      'QR_id': orderData['QR_id'],
    };

    final qrString = jsonEncode(qrPayload);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Order QR Code"),
        content: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: QrImageView(
              data: qrString,
              backgroundColor: Colors.white,
              version: QrVersions.auto,
              size: 200,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsDialog(Map<String, dynamic> data) {
    final List<Widget> itemWidgets = [];

    final generalMenu = data['general_menu'] is List
        ? data['general_menu'] as List<dynamic>
        : [];
    if (generalMenu.isNotEmpty) {
      itemWidgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "General Menu",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );

      itemWidgets.addAll(generalMenu.map((item) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.restaurant_menu, color: Colors.deepPurple),
            title: Text(item['name'] ?? 'Unnamed Item'),
            trailing: Text("x${item['quantity'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      }).toList());
    }

    final extraMenu = data['extra_menu'];
    final parsedExtraMenu = extraMenu is List ? extraMenu : [];

    if (parsedExtraMenu.isNotEmpty) {
      itemWidgets.add(
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            "Extra Menu",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );

      itemWidgets.addAll(parsedExtraMenu.map((item) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.local_dining, color: Colors.orange),
            title: Text(item['name'] ?? 'Unnamed Extra'),
            trailing: Text("x${item['quantity'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      }).toList());
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Order Items"),
        content: SizedBox(
          width: double.maxFinite,
          child: itemWidgets.isEmpty
              ? const Text("No items found in this order.")
              : ListView(shrinkWrap: true, children: itemWidgets),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(
    List<QueryDocumentSnapshot> orders,
    bool showGenerate,
  ) {
    if (orders.isEmpty) {
      return const Center(
        child: Text("No orders available", style: TextStyle(fontSize: 16)),
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final data = orders[index].data() as Map<String, dynamic>;
        final orderId = data['order_id']?.toString() ?? 'N/A';
        final amount = data['amount'] ?? 0;
        final timestamp = data['created on'] as Timestamp;
        final orderTime = timestamp.toDate();

        DateTime? displayTime;
        String timeLabel = '';

        if (data['status'] == 'served') {
          displayTime = orderTime;
          timeLabel = 'Served at';
        } else {
          final mealTimings = getMealTimings();
          for (var range in mealTimings.values) {
            final start = DateTime(orderTime.year, orderTime.month, orderTime.day, range.start.hour, range.start.minute);
            final end = DateTime(orderTime.year, orderTime.month, orderTime.day, range.end.hour, range.end.minute);
            if (orderTime.isAfter(start.subtract(const Duration(seconds: 1))) && orderTime.isBefore(end.add(const Duration(seconds: 1)))) {
              displayTime = end;
              timeLabel = data['status'] == 'pending'
                  ? 'Expires at'
                  : 'Expired at';
              break;
            }
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Order ID: $orderId",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      "Amount: ₹$amount",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (displayTime != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "$timeLabel: ${DateFormat('dd/MM/yyyy • hh:mm a').format(displayTime)}",
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showGenerate)
                      ElevatedButton.icon(
                        onPressed: () => _showQRDialog(data),
                        icon: const Icon(Icons.qr_code),
                        label: const Text("Show QR"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showOrderDetailsDialog(data),
                      icon: const Icon(Icons.info_outline),
                      label: const Text("Details"),
                    ),
                  ],
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Orders"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurple,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.check_circle_outline), text: "Active"),
            Tab(icon: Icon(Icons.history), text: "Inactive"),
            Tab(icon: Icon(Icons.cancel_outlined), text: "Expired"),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('user_id', isEqualTo: currentUser?.uid)
            .where('payment_status', isEqualTo: 'SUCCESS')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No orders found.", style: TextStyle(fontSize: 16)));
          }

          final activeOrders = <QueryDocumentSnapshot>[];
          final inactiveOrders = <QueryDocumentSnapshot>[];
          final expiredOrders = <QueryDocumentSnapshot>[];

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];
            final created = data['created on'] as Timestamp;

            if (status == 'served') {
              inactiveOrders.add(doc);
            } else if (_isOrderExpired(created)) {
              expiredOrders.add(doc);
            } else {
              activeOrders.add(doc);
            }
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOrderList(activeOrders, true),
              _buildOrderList(inactiveOrders, false),
              _buildOrderList(expiredOrders, false),
            ],
          );
        },
      ),
    );
  }
}
