import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// ignore: unused_import
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'package:vc/screens/call_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:vc/main.dart'; // Import main.dart to access activeChannelIds

class HomeScreenConnected extends StatefulWidget {
  final String currentUsername;

  const HomeScreenConnected({super.key, required this.currentUsername});

  @override
  State<HomeScreenConnected> createState() => _HomeScreenConnectedState();
}

class _HomeScreenConnectedState extends State<HomeScreenConnected> {
  late final CollectionReference usersRef;
  bool _isCalling = false; // State to prevent multiple call initiations

  @override
  void initState() {
    super.initState();
    usersRef = FirebaseFirestore.instance.collection('users');
  }

  // Helper to generate a consistent UID for Agora from username
  int _generateUidFromUsername(String username) {
    return username.hashCode.abs() % 4294967295; // Max 32-bit unsigned integer
  }

  Future<void> _startCall(String receiverUsername, String receiverFcmToken) async {
    if (_isCalling) {
      debugPrint('DEBUG: Call initiation already in progress. Ignoring duplicate tap.');
      return;
    }
    setState(() {
      _isCalling = true;
    });

    final uuid = const Uuid();
    final List<String> sortedUsernames = [widget.currentUsername, receiverUsername]..sort();
    final String channelId = '${sortedUsernames[0]}_${sortedUsernames[1]}'; // Consistent channel ID
    
    // NEW: Generate callkitUuid from sorted usernames as well, distinguishing it
    final String callkitUuid = '${sortedUsernames[0]}_${sortedUsernames[1]}_callkit_notification'; // Consistent CallKit ID

    // Check if this channelId is already active
    if (activeChannelIds.contains(channelId)) {
      debugPrint('DEBUG: Call to $receiverUsername already active on channel $channelId. Not sending notification.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call to $receiverUsername is already active.')),
        );
      }
      setState(() {
        _isCalling = false;
      });
      return;
    }

    final callerUid = _generateUidFromUsername(widget.currentUsername);

    debugPrint('DEBUG: CALL INITIATION START');
    debugPrint('DEBUG: Current User (Caller) Username: ${widget.currentUsername}');
    debugPrint('DEBUG: Current User (Caller) FCM Token: ${await FirebaseMessaging.instance.getToken()}');
    debugPrint('DEBUG: Intended Receiver Username: $receiverUsername');
    debugPrint('DEBUG: Intended Receiver FCM Token: $receiverFcmToken');
    debugPrint('DEBUG: Generated Channel ID: $channelId');
    debugPrint('DEBUG: Generated CallKit UUID: $callkitUuid'); // Now derived from usernames

    try {
      await FirebaseFirestore.instance.collection('calls').doc(channelId).set({
        'callerId': widget.currentUsername,
        'receiverId': receiverUsername,
        'channelId': channelId,
        'callkitId': callkitUuid, // Store the derived CallKit ID
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'initiated',
      });
      debugPrint('DEBUG: Firestore call document created successfully.');
    } catch (e) {
      debugPrint('ERROR: Failed to create call document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate call (Firestore): $e')),
        );
      }
      setState(() {
        _isCalling = false;
      });
      return;
    }

    try {
      debugPrint('DEBUG: Attempting to send push message...');
      await sendPushMessage(
        receiverFcmToken,
        title: 'Incoming Call',
        body: '${widget.currentUsername} is calling you...',
        callerId: widget.currentUsername,
        channelId: channelId,
        callkitId: callkitUuid, // Pass the derived CallKit ID
      );
      debugPrint('DEBUG: Push message function called. Waiting for response...');
    } catch (e) {
      debugPrint('ERROR: sendPushMessage failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send call notification (FCM): $e')),
        );
      }
      setState(() {
        _isCalling = false;
      });
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            channelId: channelId,
            uid: callerUid,
          ),
        ),
      ).then((_) {
        debugPrint('DEBUG: CallScreen popped. Resetting _isCalling state.');
        setState(() {
          _isCalling = false;
        });
      });
    } else {
      debugPrint('DEBUG: Widget unmounted before navigation. Resetting _isCalling state.');
      setState(() {
        _isCalling = false;
      });
    }
  }

  Future<void> sendPushMessage(String token, {
    required String title,
    required String body,
    required String callerId,
    required String channelId,
    String? callkitId,
  }) async {
    final url = Uri.parse(
      'https://us-central1-vcall-30196.cloudfunctions.net/sendCallNotification',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcmToken': token,
          'title': title,
          'body': body,
          'callerId': callerId,
          'channelId': channelId,
          'callkitId': callkitId,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Push sent successfully');
      } else {
        debugPrint('❌ Push failed: ${response.statusCode} ${response.body}');
        throw Exception('Push failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error sending push message: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.currentUsername}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No users found', style: TextStyle(color: Colors.grey)),
            );
          }

          final users = snapshot.data!.docs.where((doc) => doc.id != widget.currentUsername).toList();

          if (users.isEmpty) {
            return const Center(
              child: Text('No other users online', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final username = userDoc['username'] as String;
              final fcmToken = userDoc['fcmToken'] as String?;

              final isOnline = fcmToken != null && fcmToken.isNotEmpty;

              return Card(
                color: isOnline ? Colors.grey[900] : Colors.grey[800],
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    username,
                    style: TextStyle(
                      color: isOnline ? Colors.white : Colors.grey[500],
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline ? Colors.greenAccent : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.tealAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isOnline ? Icons.video_call : Icons.videocam_off,
                      color: isOnline ? Colors.tealAccent : Colors.grey,
                      size: 28,
                    ),
                  ),
                  onTap: (isOnline && !_isCalling)
                      ? () => _startCall(username, fcmToken!)
                      : null,
                  enabled: isOnline && !_isCalling,
                ),
              );
            },
          );
        },
      ),
    );
  }
}