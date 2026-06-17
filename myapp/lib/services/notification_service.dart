import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'friend_requests_channel',
        'Permintaan Teman',
        description: 'Notifikasi permintaan pertemanan masuk',
        importance: Importance.high,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'game_challenges_channel',
        'Tantangan Bermain',
        description: 'Notifikasi tantangan bermain dari teman',
        importance: Importance.max,
      ),
    );
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
      'Reminder',
      'Jangan lupa klaim XP harianmu!',
      notificationDetails,
    );
  }

  Future<void> showFriendRequestNotification({
    required String fromUid,
    required String fromDisplayName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'friend_requests_channel',
      'Permintaan Teman',
      channelDescription: 'Notifikasi permintaan pertemanan masuk',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
    );

    await _plugin.show(
      fromUid.hashCode.abs() % 10000,
      'Permintaan Pertemanan',
      '$fromDisplayName ingin berteman denganmu',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showGameChallengeNotification({
    required String fromUid,
    required String fromDisplayName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'game_challenges_channel',
      'Tantangan Bermain',
      channelDescription: 'Notifikasi tantangan bermain dari teman',
      importance: Importance.max,
      priority: Priority.high,
      autoCancel: true,
    );

    await _plugin.show(
      (fromUid.hashCode.abs() % 10000) + 10000,
      'Tantangan Bermain!',
      '$fromDisplayName mengajakmu bermain kuis',
      const NotificationDetails(android: androidDetails),
    );
  }
}
