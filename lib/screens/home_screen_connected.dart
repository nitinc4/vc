import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // Make sure this is in your pubspec.yaml
import './call_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
      print('DEBUG: Call already in progress, skipping duplicate initiation.');
      return;
    }
    setState(() {
      _isCalling = true; // Set calling state to true
    });

    final uuid = const Uuid();
    final channelId = uuid.v4(); // Unique channel ID for Agora
    final callkitUuid = uuid.v4(); // Unique CallKit ID for flutter_callkit_incoming notification

    // Get the caller's UID
    final callerUid = _generateUidFromUsername(widget.currentUsername);

    try {
      // Create call document in Firestore
      await FirebaseFirestore.instance.collection('calls').doc(channelId).set({
        'callerId': widget.currentUsername,
        'receiverId': receiverUsername,
        'channelId': channelId,
        'callkitId': callkitUuid, // Store CallKit ID in Firestore
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'initiated',
      });
      print('DEBUG: Call document created for channel: $channelId, CallKit ID: $callkitUuid');
    } catch (e) {
      print('ERROR: Failed to create call document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate call (Firestore): $e')),
        );
      }
      setState(() {
        _isCalling = false; // Reset state on error
      });
      return; // Stop if Firestore operation fails
    }

    try {
      // Send push message with unique channelId and callerId in data payload
      await sendPushMessage(
        receiverFcmToken,
        title: 'Incoming Call',
        body: '${widget.currentUsername} is calling you...',
        callerId: widget.currentUsername, // Pass callerId for CallKit display
        channelId: channelId, // Pass the unique channelId
        callkitId: callkitUuid, // Pass CallKit ID to FCM for receiver to use
      );
    } catch (e) {
      print('ERROR: Failed to send push message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send call notification (FCM): $e')),
        );
      }
      setState(() {
        _isCalling = false; // Reset state on error
      });
      return; // Stop if FCM sending fails
    }

    // Navigate to the call screen for the caller
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            channelId: channelId,
            uid: callerUid, // Use the generated UID for the caller
          ),
        ),
      ).then((_) {
        // This callback is called when CallScreen is popped
        setState(() {
          _isCalling = false; // Reset state when call screen is closed
        });
      });
    } else {
      setState(() {
        _isCalling = false; // Reset state if widget is unmounted unexpectedly
      });
    }
  }

  Future<void> sendPushMessage(String token, {
    required String title,
    required String body,
    required String callerId,
    required String channelId,
    String? callkitId, // Accept CallKit ID
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
          'callkitId': callkitId, // Include in FCM data payload
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Push sent successfully');
      } else {
        debugPrint('❌ Push failed: ${response.statusCode} ${response.body}');
        // Throw an exception to be caught by the calling function
        throw Exception('Push failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error sending push message: $e');
      rethrow; // Re-throw to be caught by _startCall's try-catch
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

          // Filter out the current user
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
                  onTap: (isOnline && !_isCalling) // Disable tap if user is offline or already calling
                      ? () => _startCall(username, fcmToken!)
                      : null, // Set onTap to null to disable interaction
                  enabled: isOnline && !_isCalling, // Visually disable if user is offline or already calling
                ),
              );
            },
          );
        },
      ),
    );
  }
}