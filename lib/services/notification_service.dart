import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vc/screens/incoming_call_screen.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> init() async {
    await _fcm.requestPermission();

    final fcmToken = await _fcm.getToken();
    print('🔐 FCM Token: $fcmToken');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        final parts = details.payload?.split('|') ?? [];
        final callerId = parts.length > 1 ? parts[1] : 'unknown';
        final channelId = parts.length > 2 ? parts[2] : 'default_channel';

        print('📲 Notification tapped → callerId: $callerId, channelId: $channelId');

        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            callerId: callerId,
            channelId: channelId,
          ),
        ));
      },
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      print('📩 onMessage Data: $data');

      final isCall = data['type'] == 'call' ||
          message.notification?.title?.toLowerCase().contains('call') == true;

      if (isCall) {
        final callerId = data['callerId'] ?? 'unknown';
        final channelId = data['channelId'] ?? 'default_channel';

        print('📞 Showing call notification: channelId = $channelId');

        showNotification(
          title: message.notification?.title ?? 'Incoming Call',
          body: message.notification?.body ?? 'Someone is calling...',
          payload: 'call|$callerId|$channelId',
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      print('🟢 App opened from notification with data: $data');

      final callerId = data['callerId'] ?? 'unknown';
      final channelId = data['channelId'] ?? 'default_channel';

      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callerId: callerId,
          channelId: channelId,
        ),
      ));
    });

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  static Future<void> _backgroundHandler(RemoteMessage message) async {
    print('🔕 Background notification received');
    final data = message.data;
    print('📦 Background Data: $data');

    final callerId = data['callerId'] ?? 'unknown';
    const channelId = 'default_channel';

    await showNotification(
      title: message.notification?.title ?? 'Call',
      body: message.notification?.body ?? 'Incoming call',
      payload: 'call|${data['callerId'] ?? 'unknown'}|default_channel',
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Incoming call alerts',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ticker: 'ticker',
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(0, title, body, details, payload: payload);
  }
}
