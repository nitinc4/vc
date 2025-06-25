import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'package:vc/main.dart'; // Corrected import to access processedCallKitIds
import 'package:flutter/foundation.dart'; // Added for debugPrint

class LocalNotificationService {
  static Future<void> showIncomingCallNotification(String callerId, String channelId, {String? incomingCallkitId}) async {
    final uuid = incomingCallkitId ?? const Uuid().v4(); // Use provided ID from FCM or generate new if not provided

    // CRITICAL DEBOUNCE: Check if this CallKit ID has already been processed to avoid duplicate notifications
    if (processedCallKitIds.contains(uuid)) { // Updated variable name
      debugPrint('DEBUG: showIncomingCallNotification: Skipping duplicate notification for CallKit ID: $uuid. Already processed in this app session.');
      return;
    }

    // Add the ID to the set to mark it as processed before attempting to show the notification
    processedCallKitIds.add(uuid); // Updated variable name
    debugPrint('DEBUG: showIncomingCallNotification: Preparing to show notification for CallKit ID: $uuid');


    final params = CallKitParams.fromJson({
      'id': uuid, // Use the ID passed from FCM (or generated)
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
        'callkitId': uuid,      // Ensure it's passed back in extra for CallKit events from plugin
      },
      'android': {
        'isCustomNotification': true, // Use custom layout/behavior
        'isShowLogo': false,
        'isShowCallback': true,
        'ringtonePath': 'system_ringtone_default', // Ensure this ringtone exists or provide custom
        'backgroundColor': '#0955fa',
        'actionColor': '#ffffff',
        'isShowMissedCallNotification': true,
        // These 'action' and 'uri' are critical for Android to launch your app when CallKit is accepted.
        // They must correspond to an <intent-filter> in your AndroidManifest.xml's MainActivity.
        'action': 'com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT',
        'uri': 'vcapp://call', // This URI should match AndroidManifest data tag for MainActivity
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

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('DEBUG: showIncomingCallNotification: Successfully showed CallKit Incoming UI for ID: $uuid');
    } catch (e) {
      debugPrint('ERROR: Failed to show CallKit Incoming UI for ID: $uuid - $e');
      // If showing fails, remove from processed IDs so it can be retried if another FCM comes
      processedCallKitIds.remove(uuid); // Updated variable name
    }
  }
}

/// Called when FCM arrives in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // Ensure Firebase is initialized for background messages
  final data = message.data;
  final callerId = data['callerId'] ?? 'Unknown Caller'; // Provide a better default if possible
  final channelId = data['channelId'] ?? 'default_channel'; // Fallback, but should always be provided by backend
  final callkitId = data['callkitId']; // Get CallKit ID from FCM
  debugPrint('DEBUG: Handling background FCM: Caller: $callerId, Channel: $channelId, CallKit ID: $callkitId, Message Data: $data');
  await LocalNotificationService.showIncomingCallNotification(callerId, channelId, incomingCallkitId: callkitId); // Pass the ID
}