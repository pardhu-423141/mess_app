/*import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UPIPaymentScreen extends StatefulWidget {
  final double amount;
  const UPIPaymentScreen({super.key, required this.amount});

  @override
  State<UPIPaymentScreen> createState() => _UPIPaymentScreenState();
}

class _UPIPaymentScreenState extends State<UPIPaymentScreen> {
  static const launcherChannel = MethodChannel('upi_launcher');
  static const paymentChannel = MethodChannel('upi_payment_channel');
  
  List<UPIApp> _upiApps = [];
  bool _isLoading = true;
  String? _errorMessage;

  final List<UPIApp> _allUpiApps = [
    UPIApp(
      name: 'Google Pay',
      package: 'com.google.android.apps.nbu.paisa.user',
      icon: 'assets/upi_logos/gpay.png',
    ),
    UPIApp(
      name: 'PhonePe', 
      package: 'com.phonepe.app',
      icon: 'assets/upi_logos/phonepe.png',
    ),
    UPIApp(
      name: 'Paytm',
      package: 'net.one97.paytm',
      icon: 'assets/upi_logos/paytm.png',
    ),
    UPIApp(
      name: 'Amazon Pay',
      package: 'in.amazon.mShop.android.shopping',
      icon: 'assets/upi_logos/amazonpay.png',
    ),
    UPIApp(
      name: 'BHIM',
      package: 'in.org.npci.upiapp',
      icon: 'assets/upi_logos/bhim.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initPaymentListener();
    _checkInstalledApps();
  }

  void _initPaymentListener() {
    paymentChannel.setMethodCallHandler((call) async {
      if (call.method == "onPaymentResponse") {
        final status = call.arguments['status'].toString().toUpperCase();
        final txnId = call.arguments['txnId'] ?? '';
        final responseCode = call.arguments['responseCode'] ?? '';
        final verified = call.arguments['verified'] ?? false;
        
        _handlePaymentResult(status, txnId, responseCode, verified);
      }
    });
  }

  Future<void> _checkInstalledApps() async {
    try {
      final installedApps = <UPIApp>[];
      
      for (var app in _allUpiApps) {
        final isInstalled = await _isAppInstalled(app.package);
        if (isInstalled) installedApps.add(app);
      }

      setState(() {
        _upiApps = installedApps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load UPI apps: ${e.toString()}';
      });
    }
  }

  Future<bool> _isAppInstalled(String packageName) async {
    try {
      return await launcherChannel.invokeMethod('isAppInstalled', {'packageName': packageName});
    } catch (e) {
      return false;
    }
  }

  Future<void> _startUpiPayment(UPIApp app) async {
    try {
      final result = await launcherChannel.invokeMethod('launchUpiTransaction', {
        'upiId': 'Q612775677@ybl',
        'name': 'PhonePeMerchant',
        'amount': widget.amount,
        'packageName': app.package,
        'note': 'NIT AP Mess Payment',
      });

      if (result['status'] == 'INITIATED') {
        _showPaymentProcessing();
      } else {
        throw Exception('Payment initiation failed: ${result['error'] ?? 'Unknown error'}');
      }
    } on PlatformException catch (e) {
      _showErrorMessage('Payment failed: ${e.message}');
    } catch (e) {
      _showErrorMessage('Error: ${e.toString()}');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showPaymentProcessing() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Processing Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              '₹${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Complete payment in your UPI app',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Do not close this screen',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _checkPaymentStatus();
                  },
                  child: const Text('Check Status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _checkPaymentStatus() {
    // Show a simple status check dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Status'),
        content: const Text('Please check your UPI app for payment confirmation, then return here.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showPaymentProcessing();
            },
            child: const Text('Still Processing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handlePaymentResult('SUCCESS', '', '00', true);
            },
            child: const Text('Payment Done'),
          ),
        ],
      ),
    );
  }

  void _handlePaymentResult(String status, String txnId, String responseCode, bool verified) {
    // Close any open dialogs
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    
    if (status == 'SUCCESS' || status == 'SUBMITTED') {
      _showSuccessDialog(txnId);
    } else if (status == 'FAILED') {
      _showErrorMessage('Payment failed. Please try again.');
    } else if (status == 'CANCELLED') {
      _showErrorMessage('Payment was cancelled.');
    } else {
      _showErrorMessage('Payment status: $status');
    }
  }

  void _showSuccessDialog(String txnId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Payment Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your payment has been completed successfully.',
              textAlign: TextAlign.center,
            ),
            if (txnId.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Transaction ID: $txnId',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close success dialog
              Navigator.of(context).pop('SUCCESS'); // Return to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Payment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.payment, size: 48, color: Colors.blue),
                      const SizedBox(height: 12),
                      Text(
                        '₹${widget.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose your preferred UPI app',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pay to: PhonePeMerchant',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_upiApps.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'No UPI apps found',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkInstalledApps,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _upiApps.length,
                  itemBuilder: (context, index) {
                    final app = _upiApps[index];
                    return InkWell(
                      onTap: () => _startUpiPayment(app),
                      borderRadius: BorderRadius.circular(12),
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                app.icon,
                                width: 48,
                                height: 48,
                                errorBuilder: (_, __, ___) => 
                                  const Icon(Icons.payment, size: 48, color: Colors.blue),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                app.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class UPIApp {
  final String name;
  final String package;
  final String icon;

  UPIApp({
    required this.name,
    required this.package,
    required this.icon,
  });
}*/

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cashfree_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CashfreePaymentScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  const CashfreePaymentScreen({super.key, required this.amount, required this.orderId});

  @override
  State<CashfreePaymentScreen> createState() => _CashfreePaymentScreenState();
}

class _CashfreePaymentScreenState extends State<CashfreePaymentScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _paymentUrl;
  String? _orderId;
  bool _paymentCompleted = false;
  String? _paymentStatusMessage;

  @override
  void initState() {
    super.initState();
    _startPayment();
  }

  String _sanitizeCustomerId(String email) {
    return email.replaceAll('@', '_').replaceAll('.', '_');
  }

  Future<void> _startPayment() async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _paymentCompleted = false;
    _paymentStatusMessage = null;
  });

  final user = FirebaseAuth.instance.currentUser!;
  final email = user.email!;
  final phone = (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty)
      ? user.phoneNumber!
      : '9999999999';

  final paymentUrl = await CashfreeApi.generatePaymentLink(
    orderId: widget.orderId,
    orderAmount: widget.amount.toStringAsFixed(2),
    customerEmail: email,
    customerPhone: phone,
    customerId: _sanitizeCustomerId(email),
  );

  if (paymentUrl == null) {
    setState(() {
      _errorMessage = 'Failed to generate payment link.';
      _isLoading = false;
    });
    return;
  }

  _orderId = widget.orderId;
  _paymentUrl = paymentUrl;

  final uri = Uri.parse(paymentUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    setState(() {
      _isLoading = false;
    });
  } else {
    setState(() {
      _errorMessage = 'Could not open payment page.';
      _isLoading = false;
    });
  }
}


  Future<void> _checkPaymentStatus() async {
    if (_orderId == null) return;

    setState(() {
      _isLoading = true;
      _paymentStatusMessage = null;
    });

    try {
      // Query Firestore for transaction with this orderId and check if status is SUCCESS
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('order_id', isEqualTo: _orderId)
          .where('status', isEqualTo: 'SUCCESS')
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Payment success found
        setState(() {
          _paymentCompleted = true;
          _paymentStatusMessage = 'Payment Successful! 🎉';
          _isLoading = false;
        });

        // Return success result to previous screen
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pop(context, {
            'status': 'SUCCESS',
            'order_id': _orderId,
            'payment_url': _paymentUrl,
            // You can add more payment details from snapshot.docs.first.data() if needed
          });
        });
      } else {
        // Payment not successful or still pending
        setState(() {
          _paymentStatusMessage = 'Payment not confirmed yet. Please wait or try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _paymentStatusMessage = 'Error checking payment status: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cashfree Payment')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cashfree Payment')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startPayment,
                child: const Text('Retry Payment'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cashfree Payment')),
      body: Center(
        child: _paymentCompleted
            ? Text(
                _paymentStatusMessage ?? '',
                style: const TextStyle(color: Colors.green, fontSize: 18),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_paymentStatusMessage != null) ...[
                    Text(
                      _paymentStatusMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Payment started for Order $_orderId.\nPlease complete the payment in browser and then check status.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _checkPaymentStatus,
                    child: const Text('Check Payment Status'),
                  ),
                ],
              ),
      ),
    );
  }
}
