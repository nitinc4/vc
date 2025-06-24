import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static Future<void> requestAllPermissions() async {
    print('DEBUG: Requesting all necessary permissions...');
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.notification,
      Permission.phone, // Added phone permission for CallKit on Android 12+
    ].request();

    bool allGranted = true;

    if (statuses[Permission.camera] != PermissionStatus.granted) {
      print('DEBUG: Camera permission denied.');
      allGranted = false;
    }
    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      print('DEBUG: Microphone permission denied.');
      allGranted = false;
    }
    if (statuses[Permission.notification] != PermissionStatus.granted) {
      print('DEBUG: Notification permission denied.');
      allGranted = false;
    }
    // phone permission is mainly for Android 12+ for displaying calls
    if (statuses[Permission.phone] != null && statuses[Permission.phone] != PermissionStatus.granted) {
      print('DEBUG: Phone permission denied.');
      allGranted = false;
    }

    if (!allGranted) {
      print('❌ One or more permissions were denied. Please grant them in app settings for full functionality.');
      // Optional: open app settings if permissions are crucial for the app's core function
      // If you want to force user to settings:
      // await openAppSettings();
    } else {
      print('✅ All necessary permissions granted.');
    }
  }
}