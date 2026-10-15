import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background FCM handler
}

class NotificationService extends GetxService {
  static NotificationService get to => Get.find();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Real-time Expense Notifications',
    description: 'Notifications for new room expenses and account updates.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<NotificationService> init() async {
    // 1. Request FCM Permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 2. Local Notifications Initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localPlugin.initialize(initSettings);

    // Create High Importance Android Channel
    await _localPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Set Foreground presentation options for iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Foreground Message Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showNotification(
          title: notification.title ?? 'Bachelor Khata',
          body: notification.body ?? '',
        );
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    return this;
  }

  /// Displays a heads-up banner with sound and vibration
  Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await _localPlugin.show(
      id == 0 ? DateTime.now().millisecondsSinceEpoch ~/ 1000 : id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Subscribe to room FCM topic
  Future<void> subscribeToRoom(String roomCode) async {
    try {
      await _fcm.subscribeToTopic('room_$roomCode');
    } catch (_) {}
  }

  /// Unsubscribe from room FCM topic
  Future<void> unsubscribeFromRoom(String roomCode) async {
    try {
      await _fcm.unsubscribeFromTopic('room_$roomCode');
    } catch (_) {}
  }
}
