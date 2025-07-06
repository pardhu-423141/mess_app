import 'package:flutter/material.dart';
import './orders_page.dart'; // or your actual home page

class PaymentRedirectPage extends StatefulWidget {
  final String? orderId;
  const PaymentRedirectPage({super.key, this.orderId});

  @override
  State<PaymentRedirectPage> createState() => _PaymentRedirectPageState();
}

class _PaymentRedirectPageState extends State<PaymentRedirectPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () => _showSuccessDialog());
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Payment Successful"),
        content: Text("Your order ${widget.orderId ?? ''} was successful."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OrdersPage()), // Change if role-based
                (route) => false,
              );
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
