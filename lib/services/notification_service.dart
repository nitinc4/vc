import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'package:vc/main.dart'; // Corrected import to access processedCallKitIds, activeChannelIds, lastIncomingCallTime
import 'package:flutter/foundation.dart'; // Added for debugPrint

class LocalNotificationService {
  static Future<void> showIncomingCallNotification(String callerId, String channelId, {String? incomingCallkitId}) async {
    final uuid = incomingCallkitId ?? const Uuid().v4();

    // ROBUSTNESS CHECK 1 (Highest Priority): Discard if Call Screen is already active (any call)
    if (activeChannelIds.isNotEmpty) {
      debugPrint('DEBUG: Incoming call notification BLOCKED (Active Call Screen): A call is already ongoing on channel(s): $activeChannelIds. Call ID: $uuid, Channel: $channelId.');
      return;
    }

    // ROBUSTNESS CHECK 2: Debounce for duplicate notification UUIDs (within session)
    if (processedCallKitIds.contains(uuid)) {
      debugPrint('DEBUG: Incoming call notification BLOCKED (Duplicate CallKit ID): Already processed notification for ID: $uuid. Channel: $channelId.');
      return;
    }

    // ROBUSTNESS CHECK 3: Implement 10-second cooldown period between notifications
    if (lastIncomingCallTime != null && DateTime.now().difference(lastIncomingCallTime!) < incomingCallCooldownDuration) {
      final Duration remainingCooldown = incomingCallCooldownDuration - DateTime.now().difference(lastIncomingCallTime!);
      debugPrint('DEBUG: Incoming call notification BLOCKED (Cooldown Active): Another notification shown recently. Remaining cooldown: ${remainingCooldown.inSeconds}s. Call ID: $uuid, Channel: $channelId.');
      return;
    }
    
    // If all checks pass, proceed to show notification
    // Update last incoming call time only if the notification is about to be shown
    lastIncomingCallTime = DateTime.now();


    // Add the ID to the set BEFORE showing the notification (for current session debounce)
    processedCallKitIds.add(uuid);
    debugPrint('DEBUG: showIncomingCallNotification: Preparing to show CallKit Incoming UI for Call ID: $uuid, Channel: $channelId.');


    final params = CallKitParams.fromJson({
      'id': uuid,
      'nameCaller': callerId,
      'appName': 'VideoCallApp',
      'avatar': 'https://i.pravatar.cc/100',
      'handle': callerId,
      'type': 1,
      'duration': 30000,
      'textAccept': 'Accept',
      'textDecline': 'Decline',
      'extra': {
        'channelId': channelId,
        'callerId': callerId,
        'callkitId': uuid,
      },
      'android': {
        'isCustomNotification': true,
        'isShowLogo': false,
        'isShowCallback': true,
        'ringtonePath': 'system_ringtone_default',
        'backgroundColor': '#0955fa',
        'actionColor': '#ffffff',
        'isShowMissedCallNotification': true,
        'action': 'com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT',
        'uri': 'vcapp://call',
      },
      'ios': {
        'handleType': 'generic',
        'supportsHolding': false,
        'supportsDTMF': false,
        'supportsGrouping': false,
        'supportsUngrouping': false,
        'ringtonePath': 'Ringtone.caf',
      }
    });

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('DEBUG: showIncomingCallNotification: Successfully showed CallKit Incoming UI for ID: $uuid, Channel: $channelId.');
    } catch (e) {
      debugPrint('ERROR: Failed to show CallKit Incoming UI for ID: $uuid, Channel: $channelId - $e');
      // If showing fails, remove from processed IDs so it can be retried if another FCM comes
      processedCallKitIds.remove(uuid);
    }
  }
}

/// Called when FCM arrives in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  final callerId = data['callerId'] ?? 'Unknown Caller';
  final channelId = data['channelId'] ?? 'default_channel';
  final callkitId = data['callkitId'];
  debugPrint('DEBUG: Handling background FCM: Caller: $callerId, Channel: $channelId, CallKit ID: $callkitId, Message Data: $data');
  await LocalNotificationService.showIncomingCallNotification(callerId, channelId, incomingCallkitId: callkitId);
}