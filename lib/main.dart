import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vc/screens/call_screen.dart';
import 'package:vc/screens/user_registration_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await LocalNotificationService.initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  LocalNotificationService.showNotification(
    title: message.notification?.title ?? 'Call',
    body: message.notification?.body ?? 'Incoming call',
  );
}

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) async {
        if (details.payload == 'call') {
          final callSnap = await FirebaseFirestore.instance
              .collection('calls')
              .where('status', isEqualTo: 'ringing')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (callSnap.docs.isNotEmpty) {
            final call = callSnap.docs.first.data();
            final channelId = call['channelId'] ?? '';
            navigatorKey.currentState?.push(MaterialPageRoute(
              builder: (_) => CallScreen(channelId: channelId, uid: 2),
            ));
          }
        }
      },
    );

    String? token = await FirebaseMessaging.instance.getToken();
    print('🔐 FCM Token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      print('📥 Foreground FCM: ${message.notification?.title}');
      showNotification(
        title: message.notification?.title ?? 'Call',
        body: message.notification?.body ?? 'Incoming call',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final callSnap = await FirebaseFirestore.instance
          .collection('calls')
          .where('status', isEqualTo: 'ringing')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (callSnap.docs.isNotEmpty) {
        final call = callSnap.docs.first.data();
        final channelId = call['channelId'] ?? '';
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => CallScreen(channelId: channelId, uid: 2),
        ));
      }
    });
  }

  static void showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'call_channel',
      'Call Notifications',
      channelDescription: 'Used for incoming call alerts',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ticker: 'ticker',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _plugin.show(0, title, body, details, payload: 'call');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call App',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const UserRegistrationScreen(),
    );
  }
}
