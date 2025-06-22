import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  Future<void> _startCall(String receiverUsername, String receiverFcmToken) async {
    final channelId = 'call_${widget.currentUsername}_$receiverUsername';

    await FirebaseFirestore.instance.collection('calls').doc(channelId).set({
      'callerId': widget.currentUsername,
      'receiverId': receiverUsername,
      'channelId': channelId,
      'status': 'ringing',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await sendPushMessage(
      receiverFcmToken,
      title: 'Incoming Call',
      body: '${widget.currentUsername} is calling you...',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          channelId: channelId,
          uid: 1,
        ),
      ),
    );
  }

  Future<void> sendPushMessage(String token,
      {required String title, required String body}) async {
    final url = Uri.parse(
      'https://us-central1-vcall-30196.cloudfunctions.net/sendCallNotification',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fcmToken': token,
        'title': title,
        'body': body,
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('✅ Push sent successfully');
    } else {
      debugPrint('❌ Push failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome, ${widget.currentUsername}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!.docs.where((doc) => doc.id != widget.currentUsername);

          if (users.isEmpty) {
            return const Center(
              child: Text('No other users online', style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: users.map((userDoc) {
              final username = userDoc['username'];
              final fcmToken = userDoc['fcmToken'];
              return Card(
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(username, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.video_call, color: Colors.tealAccent),
                  onTap: () => _startCall(username, fcmToken),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
