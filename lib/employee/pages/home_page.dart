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
    final generalMenuRaw = orderData['general_menu'];
    final extraMenuRaw = orderData['extra_menu'];

    List<Widget> generalMenuWidgets = [];
    if (generalMenuRaw is List) {
      generalMenuWidgets.add(
        const Text("General Menu Items", style: TextStyle(fontWeight: FontWeight.bold)),
      );

      for (var item in generalMenuRaw) {
        final itemMap = item as Map<String, dynamic>;
        final quantity = itemMap['quantity'] ?? 1;
        final name = itemMap['name'] ?? 'Unnamed';

        generalMenuWidgets.add(Text("- $name (x$quantity)"));
      }
      generalMenuWidgets.add(const SizedBox(height: 10));
    }

    List<Widget> extraMenuWidgets = [];
    if (extraMenuRaw is List) {
      extraMenuWidgets.add(
        const Text("Extra Menu Items", style: TextStyle(fontWeight: FontWeight.bold)),
      );

      for (var item in extraMenuRaw) {
        final itemMap = item as Map<String, dynamic>;
        final quantity = itemMap['quantity'] ?? 1;
        final name = itemMap['name'] ?? 'Unnamed';

        extraMenuWidgets.add(Text("- $name (x$quantity)"));
      }
      extraMenuWidgets.add(const SizedBox(height: 10));
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Order Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Order ID: $orderId"),
                Text("User ID: ${orderData['user_id']}"),
                Text("Amount: ₹${orderData['amount']}"),
                if (orderData['created on'] != null)
                  Text("Timestamp: ${orderData['created on'].toDate()}"),
                const SizedBox(height: 12),
                ...generalMenuWidgets,
                ...extraMenuWidgets,
                if (generalMenuWidgets.length <= 1 && extraMenuWidgets.length <= 1)
                  const Text("No menu items found in this order."),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
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
