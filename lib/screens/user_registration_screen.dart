import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen_connected.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    if (savedUsername != null && savedUsername.isNotEmpty) {
      _navigateToHome(savedUsername);
    }
  }

  Future<void> _saveUsernameAndFCM(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(username).set({
          'username': username,
          'fcmToken': fcmToken,
          'lastLogin': FieldValue.serverTimestamp(), // Optional: track last login
        }, SetOptions(merge: true)); // Use merge to update if doc exists, or create if not
        print('✅ Saved $username with token $fcmToken to Firestore');
      } catch (e) {
        print('❌ Failed to save to Firestore: $e');
      }
    } else {
      print('❌ Failed to get FCM token');
    }
  }

  void _onSubmit() async {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      await _saveUsernameAndFCM(username);
      _navigateToHome(username);
    } else {
      // Show an error or toast if username is empty
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty!')),
      );
    }
  }

  void _navigateToHome(String username) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreenConnected(currentUsername: username),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter your username',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[850],
                  hintText: 'Username',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none, // Remove default border
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  ),
                ),
                textInputAction: TextInputAction.done, // Adds a done button to keyboard
                onSubmitted: (_) => _onSubmit(), // Call onSubmit when done is pressed
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent, // Button color
                  foregroundColor: Colors.white, // Text color
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5, // Add a slight shadow
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}