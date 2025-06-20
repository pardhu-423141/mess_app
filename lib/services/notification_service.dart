import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  static Future<bool> areNotificationsEnabled() async {
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.areNotificationsEnabled() ?? false;
  }
}
