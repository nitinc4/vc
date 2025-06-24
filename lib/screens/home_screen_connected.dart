import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // Added for unique channel IDs
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

  @override
  void initState() {
    super.initState();
    usersRef = FirebaseFirestore.instance.collection('users');
  }

  // Helper to generate a consistent UID for Agora from username
  int _generateUidFromUsername(String username) {
    // A simple hash. For production, consider a more robust, collision-resistant hash
    // that fits within Agora's uint32 UID range.
    // Ensure the hash is deterministic for the same username.
    // Agora UIDs are unsigned 32-bit integers, so result needs to be positive.
    return username.hashCode.abs() % 4294967295; // Max 32-bit unsigned integer
  }

  Future<void> _startCall(String receiverUsername, String receiverFcmToken) async {
    final uuid = const Uuid();
    final channelId = uuid.v4(); // Generate a unique UUID for the channel

    // Get the caller's UID
    final callerUid = _generateUidFromUsername(widget.currentUsername);

    try {
      await FirebaseFirestore.instance.collection('calls').doc(channelId).set({
        'callerId': widget.currentUsername,
        'receiverId': receiverUsername,
        'channelId': channelId,
        'timestamp': FieldValue.serverTimestamp(), // Optional: add call initiation time
        'status': 'initiated', // Add a call status
      });
      print('DEBUG: Call document created for channel: $channelId');
    } catch (e) {
      print('ERROR: Failed to create call document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate call: $e')),
        );
      }
      return; // Stop if Firestore operation fails
    }


    // Send push message with unique channelId and callerId in data payload
    await sendPushMessage(
      receiverFcmToken,
      title: 'Incoming Call',
      body: '${widget.currentUsername} is calling you...',
      callerId: widget.currentUsername, // Pass callerId for CallKit display
      channelId: channelId, // Pass the unique channelId
    );

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
      );
    }
  }

  Future<void> sendPushMessage(String token, {
    required String title,
    required String body,
    required String callerId, // Added callerId
    required String channelId, // Added channelId
  }) async {
    // Ensure this URL points to your actual Firebase Cloud Function for sending notifications
    final url = Uri.parse(
      'https://us-central1-vcall-30196.cloudfunctions.net/sendCallNotification',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcmToken': token,
          // 'title': title, // These are not strictly needed if your backend sends data-only
          // 'body': body,   // but can be included for debugging or fallback.
          'callerId': callerId, // Important for CallKit display on receiver side
          'channelId': channelId, // Important for CallKit joining on receiver side
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Push sent successfully');
      } else {
        debugPrint('❌ Push failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error sending push message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.currentUsername}'),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {}); // Simple way to re-trigger stream builder
            },
          ),
        ],
      ),
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
              final fcmToken = userDoc['fcmToken'] as String?; // FCM token can be null

              // Ensure fcmToken is not null or empty before allowing a call
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
                  onTap: isOnline
                      ? () => _startCall(username, fcmToken!)
                      : null, // Disable tap if user is offline
                  enabled: isOnline, // Visually disable if user is offline
                ),
              );
            },
          );
        },
      ),
    );
  }
}