import 'dart:convert';
import 'package:http/http.dart' as http;

class CashfreeApi {
  static const String appId = 'TEST1070066112e93ffbe0458667a64116600701';
  static const String secretKey =
      'cfsk_ma_test_7094f9e3fdde0c5967e7d33c8e684057_a20d08ad';

  static Future<String?> generatePaymentLink({
    required String orderId,
    required String orderAmount,
    required String customerEmail,
    required String customerPhone,
    required String customerId,
  }) async {
    final url = Uri.parse('https://sandbox.cashfree.com/pg/links');

    final headers = {
      'Content-Type': 'application/json',
      'x-api-version': '2022-09-01',
      'x-client-id': appId,
      'x-client-secret': secretKey,
    };

    final body = {
      "customer_details": {
        "customer_id": customerId,
        "customer_email": customerEmail,
        "customer_phone": customerPhone,
      },
      "link_notify": {"send_sms": false, "send_email": true},
      "link_meta": {
        "return_url": 'messapp://payment-success?order_id=$orderId',
        
        "notify_url":
            "https://mess-app-gwvg.onrender.com/cashfree-webhook",
        "notes": {"internal_order_id": orderId},
      },
      "link_id": orderId,
      "link_amount": double.parse(orderAmount),
      "link_currency": "INR",
      "link_purpose": "UPI Payment for Order $orderId",
      "payment_methods": ["upi"],
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      print('✅ Payment Link: ${data['link_url']}');
      return data['link_url'];
    } else {
      print('❌ Error generating payment link: ${response.body}');
      return null;
    }
  }
}
