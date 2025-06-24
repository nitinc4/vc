import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

class LocalNotificationService {
  static Future<void> showIncomingCallNotification(String callerId, String channelId) async {
    final uuid = const Uuid().v4();

    final params = CallKitParams.fromJson({
      'id': uuid, // Unique ID for this specific CallKit notification
      'nameCaller': callerId,
      'appName': 'VideoCallApp',
      'avatar': 'https://i.pravatar.cc/100', // Consider using a real avatar or placeholder
      'handle': callerId, // Usually the number or identifier of the caller
      'type': 1, // Incoming call
      'duration': 30000, // 30 seconds timeout for the CallKit UI
      'textAccept': 'Accept',
      'textDecline': 'Decline',
      'extra': {
        'channelId': channelId, // Important: pass channelId here for CallKit
        'callerId': callerId,   // Important: pass callerId here for CallKit
      },
      'android': {
        'isCustomNotification': true, // Use custom layout/behavior
        'isShowLogo': false,
        'isShowCallback': true,
        'ringtonePath': 'system_ringtone_default', // Ensure this ringtone exists or provide custom
        'backgroundColor': '#0955fa',
        'actionColor': '#ffffff',
        'isShowMissedCallNotification': true,
        'action': 'com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT', // Or ACTION_CALL_INCOMING depending on desired launch trigger
        'uri': 'vcapp://call', // Match the data scheme/host from AndroidManifest.xml
      },
      'ios': {
        'handleType': 'generic', // Use 'generic' for general calls, 'phoneNumber' or 'emailAddress' if applicable
        'supportsHolding': false,
        'supportsDTMF': false,
        'supportsGrouping': false,
        'supportsUngrouping': false,
        'ringtonePath': 'Ringtone.caf', // Ensure this exists in your iOS project (e.g., in Runner directory)
      }
    });

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}

/// Called when FCM arrives in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // Ensure Firebase is initialized for background messages
  final data = message.data;
  final callerId = data['callerId'] ?? 'Unknown Caller'; // Provide a better default if possible
  final channelId = data['channelId'] ?? 'default_channel'; // Fallback, but should always be provided by backend
  print('DEBUG: Handling background FCM: Caller: $callerId, Channel: $channelId, Message Data: $data'); // Debugging
  await LocalNotificationService.showIncomingCallNotification(callerId, channelId);
}