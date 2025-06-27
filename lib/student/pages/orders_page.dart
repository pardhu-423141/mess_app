import 'dart:convert'; // For jsonEncode

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../manager/add_extra_menu.dart'; // for getMealTimings()

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    super.initState();
  }

  /// Determine if an order is expired based on timestamp
  bool _isOrderExpired(Timestamp timestamp) {
    final DateTime orderTime = timestamp.toDate();
    final now = DateTime.now();

    final mealTimes = getMealTimings(); // imported from add_extra_menu.dart
    for (var range in mealTimes.values) {
      final start = DateTime(orderTime.year, orderTime.month, orderTime.day, range.start.hour, range.start.minute);
      final end = DateTime(orderTime.year, orderTime.month, orderTime.day, range.end.hour, range.end.minute);
      if (orderTime.isAfter(start) && orderTime.isBefore(end)) {
        return now.isAfter(end);
      }
    }
    return true;
  }

  /// Show a QR code in a dialog with full order details
  void _showQRDialog(Map<String, dynamic> orderData) {
    final qrPayload = {
      'order_id': orderData['order_id'],
      'amount': orderData['amount'],
      'user_id': orderData['user_id'],
      'timestamp': (orderData['created on'] as Timestamp).toDate().toIso8601String(),
      'QR_id' : orderData['QR_id'],
    };

    final qrString = jsonEncode(qrPayload); // Clean JSON encoding

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
          )
        ],
      ),
    );
  }

  /// Build the list of orders per category
  Widget _buildOrderList(List<QueryDocumentSnapshot> orders, bool showGenerate) {
    if (orders.isEmpty) {
      return const Center(child: Text("No orders available"));
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final data = orders[index].data() as Map<String, dynamic>;
        final orderId = data['order_id']?.toString() ?? '';
        final amount = data['amount'] ?? 0;
        final createdOn = (data['created on'] as Timestamp).toDate();

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            title: Text("Order ID: $orderId"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Amount: ₹$amount"),
                Text("Created: ${DateFormat.yMd().add_jm().format(createdOn)}"),
              ],
            ),
            trailing: showGenerate
                ? ElevatedButton(
                    onPressed: () => _showQRDialog(data),
                    child: const Text("Generate QR"),
                  )
                : null,
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
          tabs: const [
            Tab(text: "Active"),
            Tab(text: "Inactive"),
            Tab(text: "Expired"),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('user_id', isEqualTo: currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
              _buildOrderList(activeOrders, true),   // Active tab with QR
              _buildOrderList(inactiveOrders, false), // Inactive tab
              _buildOrderList(expiredOrders, false),  // Expired tab
            ],
          );
        },
      ),
    );
  }
}
