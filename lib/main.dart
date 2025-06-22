import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vc/screens/user_registration_screen.dart';
import 'package:vc/services/notification_service.dart';
import 'package:vc/services/permissions_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Request permissions for camera, mic, and notifications
  await PermissionsService.requestAllPermissions();

  // Initialize FCM + Local Notifications + Routing
  await NotificationService.init();

  // Background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

/// 🔔 Background handler for FCM notifications
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  NotificationService.showNotification(
    title: message.notification?.title ?? 'Call',
    body: message.notification?.body ?? 'Incoming call',
    payload: _generatePayloadFromData(message.data),
  );
}

/// 📦 Helper to encode payload for routing
String _generatePayloadFromData(Map<String, dynamic> data) {
  final callerId = data['callerId'] ?? 'unknown';
  final channelId = data['channelId'] ?? 'default_channel';
  return 'call|$callerId|$channelId';
}

/// 🌙 Root App
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call App',
      navigatorKey: NotificationService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF101012),
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent.shade400,
          secondary: Colors.teal,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
      ),
      home: const UserRegistrationScreen(),
    );
  }
}
