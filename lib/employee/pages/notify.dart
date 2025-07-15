import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotifyPage extends StatelessWidget {
  const NotifyPage({super.key});

  Future<void> _sendNotification(String type) async {
    final uri = Uri.parse('https://32cb3a837005.ngrok-free.app/$type'); // Replace with your server URL
    try {
      final response = await http.post(uri);
      if (response.statusCode == 200) {
        debugPrint('✅ Notification sent: $type');
      } else {
        debugPrint('❌ Failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notify Users')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _sendNotification('messStart'),
              child: const Text('Mess Start'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _sendNotification('messEnd'),
              child: const Text('Mess End'),
            ),
          ],
        ),
      ),
    );
  }
}
