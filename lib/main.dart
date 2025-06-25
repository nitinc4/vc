import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:vc/screens/user_registration_screen.dart';
import 'package:vc/screens/call_screen.dart';
import 'package:vc/services/notification_service.dart';
import 'package:vc/services/permissions_service.dart';
import 'package:flutter/foundation.dart';
import 'package:vc/screens/home_screen_connected.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Set<String> processedCallKitIds = {};
Set<String> activeChannelIds = {};

DateTime? lastIncomingCallTime;
const Duration incomingCallCooldownDuration = Duration(seconds: 10);

Timer? _callAcceptanceTimer;


/// Determines the initial widget to display when the app starts.
/// Prioritizes pending calls, then saved usernames, then registration.
Future<Widget> _getInitialWidget() async {
  final prefs = await SharedPreferences.getInstance();
  final pendingCallChannelId = prefs.getString('pendingCallChannelId');
  
  if (pendingCallChannelId != null) {
    debugPrint('DEBUG: Cold start detected with pending call to channel: $pendingCallChannelId. Navigating to CallScreen as initial route.');
    await prefs.remove('pendingCallChannelId'); // Clear as we are about to navigate to it (CRITICAL FOR COLD START)
    return CallScreen(uid: 0, channelId: pendingCallChannelId);
  } else {
    final savedUsername = prefs.getString('currentUsername');
    if (savedUsername != null && savedUsername.isNotEmpty) {
      debugPrint('DEBUG: Cold start detected with saved username: $savedUsername. Navigating to HomeScreenConnected as initial route.');
      return HomeScreenConnected(currentUsername: savedUsername);
    }
    debugPrint('DEBUG: Cold start detected, no pending call or saved username. Navigating to UserRegistrationScreen as initial route.');
    return const UserRegistrationScreen();
  }
}

/// Entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await PermissionsService.requestAllPermissions();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  setupCallkitListeners();

  final initialWidget = await _getInitialWidget();

  runApp(MyApp(initialWidget: initialWidget));
}

class MyApp extends StatelessWidget {
  final Widget initialWidget;

  const MyApp({super.key, required this.initialWidget});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call App',
      navigatorKey: navigatorKey,
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: initialWidget,
    );
  }
}

void _navigateToCallScreen(String channelId) {
  if (navigatorKey.currentState != null && navigatorKey.currentState!.mounted) {
    debugPrint('DEBUG: Navigator is ready. Attempting to navigate to CallScreen for channel: $channelId');
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
      debugPrint('DEBUG: Pushing CallScreen as replacement for channel: $channelId');
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (_) => CallScreen(uid: 0, channelId: channelId),
          settings: RouteSettings(name: '/callScreen', arguments: {'channelId': channelId}),
        ),
      );
    } else {
      debugPrint('DEBUG: Already on CallScreen for channel $channelId. Not navigating again.');
    }
  } else {
    debugPrint('DEBUG: Navigator not ready to navigate to CallScreen.');
  }
}


/// Listen to CallKit events (Accept/Decline)
void setupCallkitListeners() {
  FlutterCallkitIncoming.onEvent.listen((event) async {
    final Event? eventType = event?.event;
    final body = event?.body;
    final callkitId = body?['id'];

    debugPrint('CallKit Event Received: ${eventType.toString()}, ID: $callkitId, Body: $body');
    debugPrint('DEBUG: eventType value (enum.toString()): "${eventType.toString()}"');
    debugPrint('DEBUG: eventType type: ${eventType.runtimeType}');


    if (callkitId == null) {
      debugPrint('DEBUG: CallKit event received with null ID. Skipping processing.');
      return;
    }

    switch (eventType) {
      case Event.actionCallIncoming:
        if (!processedCallKitIds.contains(callkitId)) {
          processedCallKitIds.add(callkitId);
          debugPrint('DEBUG: ACTION_CALL_INCOMING event received for new ID: $callkitId. Marking as processed.');
        } else {
          debugPrint('DEBUG: Skipping duplicate ACTION_CALL_INCOMING event for ID: $callkitId. Already processed.');
        }
        break; 

      case Event.actionCallAccept:
        debugPrint('DEBUG: Call ACCEPT event received for ID: $callkitId. Attempting immediate navigation.');
        final channelId = body?['extra']?['channelId'];
        if (channelId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pendingCallChannelId', channelId); // Set for cold start handling by _getInitialWidget

          // For warm launches (app already in foreground/background), navigate immediately
          _navigateToCallScreen(channelId);
          activeChannelIds.add(channelId);
          debugPrint('DEBUG: Channel $channelId added to activeChannelIds on ACCEPT.');

          // REMOVED: await prefs.remove('pendingCallChannelId');
          // This line is removed. pendingCallChannelId is now cleared only by _getInitialWidget
          // (on cold start) or by the call end/decline handlers.
        } else {
          debugPrint('ERROR: ACTION_CALL_ACCEPT event missing channelId.');
        }
        processedCallKitIds.remove(callkitId);
        break;

      case Event.actionCallDecline:
      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        final callId = body?['id'];
        final channelId = body?['extra']?['channelId'];
        if (callId != null) {
          debugPrint('CallKit ACTION_CALL_DECLINE/ENDED/TIMEOUT for ID: $callId');
          await FlutterCallkitIncoming.endCall(callId);
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pendingCallChannelId'); // Clear on call end/decline
          processedCallKitIds.remove(callId);
          if (channelId != null) {
            activeChannelIds.remove(channelId);
            debugPrint('DEBUG: Channel $channelId removed from activeChannelIds on END/DECLINE/TIMEOUT.');
          }
        }
        break;

      default:
        debugPrint('DEBUG: Unhandled CallKit Event Type: ${eventType.toString()}');
        break;
    }
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('FCM Received (Foreground): ${message.data}');
    final callerId = message.data['callerId'];
    final channelId = message.data['channelId'];
    final fcmCallKitId = message.data['callkitId'];

    if (fcmCallKitId != null && processedCallKitIds.contains(fcmCallKitId)) {
        debugPrint('DEBUG: FCM for already processed CallKit ID: $fcmCallKitId. Skipping visual notification.');
        return;
    }

    if (callerId != null && channelId != null) {
      LocalNotificationService.showIncomingCallNotification(callerId, channelId, incomingCallkitId: fcmCallKitId);
    }
  });
}