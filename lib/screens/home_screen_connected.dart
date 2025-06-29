import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    usersRef = FirebaseFirestore.instance.collection('users');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Helper to generate a consistent UID for Agora from username
  int _generateUidFromUsername(String username) {
    return username.hashCode.abs() % 4294967295; // Max 32-bit unsigned integer
  }

  Future<void> _initiateCallWithInputUsername() async {
    final targetUsername = _usernameController.text.trim();
    if (targetUsername.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a username to call.')),
        );
      }
      return;
    }

    if (targetUsername == widget.currentUsername) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot call yourself.')),
        );
      }
      return;
    }

    setState(() {
      _isCalling = true; // Set calling state immediately
    });

    try {
      // Fetch the FCM token for the target username
      final userDoc = await usersRef.doc(targetUsername).get();

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User "$targetUsername" not found.')),
          );
        }
        setState(() {
          _isCalling = false; // Reset calling state
        });
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final receiverFcmToken = userData['fcmToken'] as String?;

      if (receiverFcmToken == null || receiverFcmToken.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User "$targetUsername" is currently offline or has no FCM token.')),
          );
        }
        setState(() {
          _isCalling = false; // Reset calling state
        });
        return;
      }

      await _startCall(targetUsername, receiverFcmToken);
    } catch (e) {
      debugPrint('ERROR: Error initiating call with input: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate call: $e')),
        );
      }
      setState(() {
        _isCalling = false; // Reset calling state on error
      });
    }
  }

  Future<void> _startCall(String receiverUsername, String receiverFcmToken) async {
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
        title: Text('Logged in as: ${widget.currentUsername}')), // Modified title
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Enter username to call',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[800],
                labelStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                if (!_isCalling) {
                  _initiateCallWithInputUsername();
                }
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isCalling ? null : _initiateCallWithInputUsername,
              icon: _isCalling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.video_call),
              label: Text(_isCalling ? 'Calling...' : 'Call User'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}