import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// ignore: unused_import
import 'package:firebase_core/firebase_core.dart';
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

  // 1. Create a call record
  await FirebaseFirestore.instance.collection('calls').doc(channelId).set({
    'callerId': widget.currentUsername,
    'receiverId': receiverUsername,
    'channelId': channelId,
    'status': 'ringing',
    'timestamp': FieldValue.serverTimestamp(),
  });

  // 2. Send a notification to receiver
  await sendPushMessage(
    receiverFcmToken,
    title: 'Incoming Call',
    body: '${widget.currentUsername} is calling you...',
  );

  // 3. Navigate to CallScreen and pass required params
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CallScreen(
        channelId: channelId,
        uid: 1, // Caller UID (callee will use 2)
      ),
    ),
  );
}
  Future<void> sendPushMessage(String token,
      {required String title, required String body}) async {
    final url = Uri.parse(
      'https://us-central1-vcall-30196.cloudfunctions.net/sendCallNotification',
    ); // Replace with your actual URL if different

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
      appBar: AppBar(title: Text('Hello ${widget.currentUsername}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final users = snapshot.data!.docs.where(
            (doc) => doc.id != widget.currentUsername,
          ); // exclude self

          return ListView(
            children: users.map((userDoc) {
              final username = userDoc['username'];
              final fcmToken = userDoc['fcmToken'];
              return ListTile(
                title: Text(username),
                trailing: const Icon(Icons.call),
                onTap: () => _startCall(username, fcmToken),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
