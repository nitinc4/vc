import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await LocalNotificationService.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

/// Background handler for FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  LocalNotificationService.showNotification(
    title: message.notification?.title ?? 'Call',
    body: message.notification?.body ?? 'Incoming call',
  );
}

/// Notification helper class
class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload == 'call') {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => const CallScreen(),
          ));
        }
      },
    );

    // Get FCM token
    String? token = await FirebaseMessaging.instance.getToken();
    print('🔐 FCM Token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      print('📥 Foreground message: ${message.notification?.title}');
      showNotification(
        title: message.notification?.title ?? 'Call',
        body: message.notification?.body ?? 'Incoming call',
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => const CallScreen(),
      ));
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

/// Global navigator key to navigate from background
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call App',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

/// Simple home screen to simulate user
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User A')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Simulate Incoming Call'),
          onPressed: () {
            LocalNotificationService.showNotification(
              title: 'Incoming Call',
              body: 'User B is calling...',
            );
          },
        ),
      ),
    );
  }
}

/// Dummy call screen UI
class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, color: Colors.white, size: 100),
            const SizedBox(height: 20),
            const Text('In Call with User B',
                style: TextStyle(color: Colors.white, fontSize: 24)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('End Call'),
            )
          ],
        ),
      ),
    );
  }
}
