import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static Future<void> requestAllPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.notification,
    ].request();

    if (statuses[Permission.camera]!.isDenied ||
        statuses[Permission.microphone]!.isDenied ||
        statuses[Permission.notification]!.isDenied) {
      // You can show a dialog or redirect to app settings here if needed
      print('🚫 One or more permissions were denied');
    } else {
      print('✅ All permissions granted');
    }
  }
}
