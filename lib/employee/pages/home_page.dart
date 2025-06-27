import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScanQR extends StatefulWidget {
  @override
  _ScanQRState createState() => _ScanQRState();
}

class _ScanQRState extends State<ScanQR> {
  String qrRaw = "Not Yet Scanned";

  void _scanQRCode() async {
    var result = await BarcodeScanner.scan();

    setState(() {
      qrRaw = result.rawContent.isEmpty ? "Scan Cancelled" : result.rawContent;
    });

    try {
      final qrData = jsonDecode(result.rawContent);
      final String orderId = qrData['order_id'];
      final String qrIdFromQR = qrData['QR_id'];

      print("Scanned Order ID: $orderId, QR ID: $qrIdFromQR");

      DocumentReference orderRef =
          FirebaseFirestore.instance.collection('orders').doc(orderId);
      DocumentSnapshot snapshot = await orderRef.get();

      if (!snapshot.exists) {
        _showErrorDialog('Order not found.');
        return;
      }

      final originalData = snapshot.data() as Map<String, dynamic>;

      if (originalData['QR_id'] != qrIdFromQR) {
        _showErrorDialog('QR ID does not match. Possible tampering.');
        return;
      }

      final String status = originalData['status'] ?? '';
      print("Order status: $status");

      if (status == 'not served') {
        // ✅ Update status to 'served'
        await orderRef.update({'status': 'served'});

        // ✅ Fetch updated data
        final updatedSnapshot = await orderRef.get();
        final updatedData = updatedSnapshot.data() as Map<String, dynamic>;
        
        // ✅ Show order details with updated data
        _showOrderDetailsDialog(updatedData, orderId);
      } else if (status == 'served') {
        _showErrorDialog('Order already served.');
      } else {
        _showErrorDialog('Order status: $status');
      }
    } catch (e, stackTrace) {
      print("Exception: $e");
      print(stackTrace);
      _showErrorDialog('Invalid QR.');
    }
  }

  void _showOrderDetailsDialog(Map<String, dynamic> orderData, String orderId) async {
    final extraMenuRaw = orderData['extra_menu'];
    final generalMenuRaw = orderData['general_menu'];

    final Map<String, dynamic> extraMenu =
        (extraMenuRaw is Map<String, dynamic>) ? extraMenuRaw : {};
    final Map<String, dynamic> generalMenu =
        (generalMenuRaw is Map<String, dynamic>) ? generalMenuRaw : {};

    // Fetch item names for general menu
    List<Widget> generalMenuWidgets = [];
    if (generalMenu.isNotEmpty) {
      generalMenuWidgets.add(
        Text("General Menu Items", style: TextStyle(fontWeight: FontWeight.bold)),
      );
      for (var entry in generalMenu.entries) {
        String itemId = entry.key;
        int quantity = entry.value;

        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('general_menu')
            .doc(itemId)
            .get();

        String itemName = doc.exists ? (doc.data() as Map)['name'] ?? itemId : itemId;
        generalMenuWidgets.add(Text("- $itemName x$quantity"));
      }
      generalMenuWidgets.add(SizedBox(height: 10));
    }

    // Fetch item names for extra menu
    List<Widget> extraMenuWidgets = [];
    if (extraMenu.isNotEmpty) {
      extraMenuWidgets.add(
        Text("Extra Menu Items", style: TextStyle(fontWeight: FontWeight.bold)),
      );
      for (var entry in extraMenu.entries) {
        String itemId = entry.key;
        int quantity = entry.value;

        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('extra_menu')
            .doc(itemId)
            .get();

        String itemName = doc.exists ? (doc.data() as Map)['name'] ?? itemId : itemId;
        extraMenuWidgets.add(Text("- $itemName x$quantity"));
      }
      extraMenuWidgets.add(SizedBox(height: 10));
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Order Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order ID: $orderId"),
                Text("User ID: ${orderData['user_id']}"),
                Text("Amount: ₹${orderData['amount']}"),
                Text("Timestamp: ${orderData['timestamp']}"),
                SizedBox(height: 12),
                ...generalMenuWidgets,
                ...extraMenuWidgets,
                if (generalMenuWidgets.isEmpty && extraMenuWidgets.isEmpty)
                  Text("No menu items found in this order."),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ],
        );
      },
    );
  }



  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notice'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Scan Result", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _scanQRCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.indigo),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: EdgeInsets.all(16),
              ),
              child: Text("Open Scanner", style: TextStyle(color: Colors.indigo)),
            ),
          ],
        ),
      ),
    );
  }
}
