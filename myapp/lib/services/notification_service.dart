import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings);
  }

  Future<void> showNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_channel',
      'Daily Reminder',
      channelDescription: 'Reminder XP harian',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      'Reminder 🎮',
      'Jangan lupa klaim XP harianmu!',
      notificationDetails,
    );
  }
}
