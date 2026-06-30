import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Requests all required permissions for the driver app.
  /// Returns true if all critical permissions (location) are granted.
  static Future<bool> requestAllPermissions() async {
    // NOTE: Notification permission is intentionally NOT requested here —
    // FCMNotificationService.initialize() already requests it via Firebase
    // Messaging. Requesting it here too would prompt the user twice.
    final permissions = <Permission>[
      Permission.location,
      Permission.camera,
      Permission.phone,
      if (Platform.isAndroid) Permission.storage,
      if (Platform.isIOS) Permission.photos,
    ];

    final statuses = await permissions.request();

    // Location is critical for drivers
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;

    // Request background location separately (Android requires foreground first)
    if (locationGranted) {
      final bgStatus = await Permission.locationAlways.request();
      // Background location is important but not blocking
      debugPrint('[Permissions] Background location: $bgStatus');
    }

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
