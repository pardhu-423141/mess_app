import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class NotificationSender {
  // 🔐 Replace with your actual Firebase Cloud Messaging Server Key
  static const String _serverKey = 'ya29.c.c0ASRK0Gbb33eJm9b4vfIa9HOWh3vcazoHXjWx97rRbd6tqRLYQwiCGkGWQvl0beCUIU79st3jcxdmTXLVN91kI0gOHxCdqw54-KHcacfkIkPBaORPrTveu8_wWlKCrjpsJeUmDGa6owNPIjmt1WHObdHjMniH9sSTBoiqrlbFACsi9kUzIHfRv-2eyw1qEDseMYXNIKHxHMlcQ46zlnyojFVRGa9Ie2Spsx3ZduAXVlZ6wpPoCRySionJAAlLsF9bvx-CaZ6cXIvbdrdIAPVw00Z_MjX6d4zT8nyId7Jkhzu6f-5fxFJYhLpda9as_z8sik9eShZjyij33wmD2o6HtX1lNJCqILRaadqbg5JiJSBP9-7SLmaQXiMOjhsN388KlIi98_1rcnu9xRp81ivlnBk-Zrrk83_vVzwX38ZRyqmupJJwyWShrVdtJrvy9xmzqo6aWMo3I8JhfIWBj9-asu36B8Rrp7cIejQyI9Vu1fZbkaM_fRX8YFj9S5u3oaZmm_5iV5OkQ4w15tBXX349QwwlVSXpWdmXXZYc-w85Mq6ssJ51mQsb1sUxipl7rIoZ-WynIJtkUsqdgaF5dqXh35kZ0myJj_8F9MgyoZ2V-FWl1uU696Zsk7u4y3_cXnwwo2QZw5ZrFsJZsn_5hIe4fv-ipvr30qcr3oqgh-5uMdu9-IwoXQlRIssyVremWsvZzI1Mq69-ezrxocpyOU1SulSf6RZz8lcUUaB9Qrbu8aQxjZd8iIyy2p8ehRbSiWQZmzsvxOuyxUsWSOO5g46Fw_ZB8moiblmzS-8Vcsc_ne6si3wtoxZtwIdMMvqq__urg9lQxBBmQiyIgy0fOb0Y7Rylr9d3X-ssZbqhIi_ayaikV-nVfu9p_WlXX3zxnBRYMxkwUSpOnWeYW7JnY2kyFb6Bxh_gxZrqtXmmWvwX0IBfInpl0jxlXi1OQryfv2pFhyaieokVUFxOFjtqh4uRvvfRS5cW1uZ4eXfw5VjOcvB0I';

  static Future<void> sendNotificationToRegulars(BuildContext context, String title, String body) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('users')
          .where('role', isEqualTo: 'regular')
          .get();

      for (final doc in snapshot.docs) {
        final token = doc['fcm_token'];
        if (token != null && token is String) {
          await _sendPushNotification(token, title, body);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification sent to all regular users.')),
      );
    } catch (e) {
      debugPrint('❌ Failed to send notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send notifications.')),
      );
    }
  }

  static Future<void> _sendPushNotification(String token, String title, String body) async {
    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'key=$_serverKey',
    };

    final payload = {
      'to': token,
      'notification': {
        'title': title,
        'body': body,
      },
      'priority': 'high',
    };

    await http.post(url, headers: headers, body: jsonEncode(payload));
  }
}
