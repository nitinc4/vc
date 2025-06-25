import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vc/screens/home_screen_connected.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Keep this import for saving username

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final Uuid _uuid = const Uuid();

  String? _errorMessage;
  // bool _isLoading = true; // REMOVED: No longer needed for initial check

  @override
  void initState() {
    super.initState();
    // REMOVED: _checkSavedUsername(); // Initial check and navigation is now handled in main.dart
  }

  // REMOVED: _checkSavedUsername() method as it's handled by main.dart now
  // Future<void> _checkSavedUsername() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final savedUsername = prefs.getString('currentUsername');
  //   if (savedUsername != null && savedUsername.isNotEmpty) {
  //     _usernameController.text = savedUsername;
  //     if (mounted) {
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => HomeScreenConnected(currentUsername: savedUsername),
  //         ),
  //       );
  //     }
  //   }
  //   setState(() {
  //     _isLoading = false;
  //   });
  // }


  Future<void> _registerUser() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Username cannot be empty.';
      });
      return;
    }

    setState(() {
      _errorMessage = null; // Clear previous errors
    });

    try {
      final String dummyUid = _uuid.v4();

      String? fcmToken = await _firebaseMessaging.getToken();
      debugPrint("FCM Token: $fcmToken");

      await _firestore.collection('users').doc(username).set({
        'username': username,
        'fcmToken': fcmToken,
        'uid': dummyUid,
        'lastActive': FieldValue.serverTimestamp(),
      });
      debugPrint('User registered (without Firebase Auth) and data saved to Firestore.');

      // SAVE USERNAME TO LOCAL STORAGE AFTER SUCCESSFUL REGISTRATION
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentUsername', username);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreenConnected(currentUsername: username),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error registering user: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // REMOVED: _isLoading check, as initial route is handled by main.dart
    // if (_isLoading) {
    //   return const Scaffold(
    //     body: Center(
    //       child: CircularProgressIndicator(color: Colors.tealAccent),
    //     ),
    //   );
    // }

    return Scaffold(
      appBar: AppBar(title: const Text('Register Username')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Enter your username',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _registerUser,
                icon: const Icon(Icons.login),
                label: const Text(
                  'Register and Connect',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}