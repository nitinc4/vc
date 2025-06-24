import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Import for Timer

// ✅ CORRECTED IMPORTS for your local files
import 'package:flutter_callkit_incoming/entities/entities.dart'; // ✅ Re-import Event enum
import 'screens/user_registration_screen.dart'; // Correct relative path
import 'screens/call_screen.dart';             // Correct relative path
import 'services/notification_service.dart';   // Correct relative path
import 'services/permissions_service.dart';    // Correct relative path


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Set<String> _processedCallKitIds = {};
Timer? _callAcceptanceTimer;

/// Entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await PermissionsService.requestAllPermissions();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  setupCallkitListeners();

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingCallChannelId = prefs.getString('pendingCallChannelId');
    if (pendingCallChannelId != null) {
      print('DEBUG: App started with pending call. Navigating to CallScreen for channel: $pendingCallChannelId');
      await prefs.remove('pendingCallChannelId');
      _navigateToCallScreen(pendingCallChannelId);
    }
  });
}

void _navigateToCallScreen(String channelId) {
  if (navigatorKey.currentState != null && navigatorKey.currentState!.mounted) {
    bool alreadyOnCallScreen = false;
    navigatorKey.currentState?.popUntil((route) {
      if (route is MaterialPageRoute &&
          route.settings.name == '/callScreen' &&
          route.settings.arguments != null &&
          route.settings.arguments is Map &&
          (route.settings.arguments as Map)['channelId'] == channelId) {
        alreadyOnCallScreen = true;
      }
      return true;
    });

    if (!alreadyOnCallScreen) {
      print('DEBUG: Pushing CallScreen for channel: $channelId');
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => CallScreen(uid: 0, channelId: channelId),
          settings: RouteSettings(name: '/callScreen', arguments: {'channelId': channelId}),
        ),
      );
    } else {
      print('DEBUG: Already on CallScreen for channel $channelId. Not navigating again.');
    }
  } else {
    print('DEBUG: Navigator not ready to navigate to CallScreen.');
  }
}


/// Listen to CallKit events (Accept/Decline)
void setupCallkitListeners() {
  FlutterCallkitIncoming.onEvent.listen((event) async {
    final Event? eventType = event?.event; // ✅ Corrected type to Event?
    final body = event?.body;
    final callkitId = body?['id'];

    // For debugging, print its toString() representation, not the raw enum
    print('CallKit Event Received: ${eventType.toString()}, ID: $callkitId, Body: $body');
    print('DEBUG: eventType value (enum.toString()): "${eventType.toString()}"');
    // Removed .length and .trim() as eventType is not a String
    print('DEBUG: eventType type: ${eventType.runtimeType}');


    if (callkitId == null) {
      print('DEBUG: CallKit event received with null ID. Skipping processing.');
      return;
    }

    // ✅ Corrected: Compare directly to Event enum constants
    switch (eventType) {
      case Event.actionCallIncoming: // ✅ This is the correct way to compare
        if (_processedCallKitIds.contains(callkitId)) {
          print('DEBUG: Already processed ACTION_CALL_INCOMING for ID: $callkitId. Skipping.');
          return;
        }
        _processedCallKitIds.add(callkitId);
        print('DEBUG: Processing new ACTION_CALL_INCOMING for ID: $callkitId.');
        break;

      case Event.actionCallAccept: // ✅ Corrected
        if (_callAcceptanceTimer != null && _callAcceptanceTimer!.isActive) {
          print('DEBUG: Call ACCEPT debounce active. Skipping duplicate accept event for ID: $callkitId');
          return;
        }

        _callAcceptanceTimer = Timer(const Duration(milliseconds: 500), () async {
          print('DEBUG: Call ACCEPT timer triggered for ID: $callkitId');
          final channelId = body?['extra']?['channelId'];
          if (channelId != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('pendingCallChannelId', channelId);

            _navigateToCallScreen(channelId);
            await prefs.remove('pendingCallChannelId');
          } else {
            print('ERROR: ACTION_CALL_ACCEPT event missing channelId.');
          }
          _processedCallKitIds.remove(callkitId);
          _callAcceptanceTimer = null;
        });
        break;

      case Event.actionCallDecline: // ✅ Corrected
      case Event.actionCallEnded:   // ✅ Corrected
      case Event.actionCallTimeout: // ✅ Corrected
        final callId = body?['id'];
        if (callId != null) {
          print('CallKit ACTION_CALL_DECLINE/ENDED/TIMEOUT for ID: $callId');
          await FlutterCallkitIncoming.endCall(callId);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pendingCallChannelId');
          _processedCallKitIds.remove(callId);
          _callAcceptanceTimer?.cancel();
          _callAcceptanceTimer = null;
        }
        break;

      default:
        // When using switch with enum, default handles any unexpected enum values,
        // or if eventType itself is null.
        print('DEBUG: Unhandled CallKit Event Type: ${eventType.toString()}');
        break;
    }
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('FCM Received (Foreground): ${message.data}');
    final callerId = message.data['callerId'];
    final channelId = message.data['channelId'];
    if (callerId != null && channelId != null) {
      LocalNotificationService.showIncomingCallNotification(callerId, channelId);
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call App',
      navigatorKey: navigatorKey,
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const UserRegistrationScreen(),
    );
  }
}