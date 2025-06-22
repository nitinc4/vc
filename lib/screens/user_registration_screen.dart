import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import './home_screen_connected.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  Future<void> _registerUser(String username) async {
    if (username.isEmpty) return;

    setState(() => _loading = true);

    final fcmToken = await FirebaseMessaging.instance.getToken();

    await FirebaseFirestore.instance.collection('users').doc(username).set({
      'username': username,
      'fcmToken': fcmToken,
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreenConnected(currentUsername: username),
      ),
    );

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Video Call')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, size: 80, color: Colors.tealAccent),
              const SizedBox(height: 20),
              const Text(
                'Enter your username to start',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Username',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loading ? null : () => _registerUser(_controller.text.trim()),
                icon: const Icon(Icons.login),
                label: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Continue'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
