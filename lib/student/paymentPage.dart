import 'package:flutter/material.dart';

class PaymentPage extends StatelessWidget {
  final double totalAmount;

  const PaymentPage({super.key, required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Page')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Proceeding to pay ₹${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Simulate payment success and go back
                Navigator.of(context).pop(true); // returns success
              },
              child: const Text('Complete Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
