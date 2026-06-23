import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Requests all required permissions for the customer app.
  /// Returns true if all critical permissions (location) are granted.
  static Future<bool> requestAllPermissions() async {
    final permissions = <Permission>[
      Permission.location,
      Permission.camera,
      Permission.notification,
      Permission.phone,
      if (Platform.isAndroid) Permission.storage,
      if (Platform.isIOS) Permission.photos,
    ];

    final statuses = await permissions.request();

    // Location is critical for ride booking
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;
    return locationGranted;
  }

  /// Shows a dialog directing the user to app settings if a permission
  /// was permanently denied.
  static Future<void> showSettingsDialog(BuildContext context, String permissionName) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
          '$permissionName permission is required for the app to work properly. '
          'Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
