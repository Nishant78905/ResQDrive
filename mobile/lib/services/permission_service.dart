import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  PermissionService._();

  static Future<bool> requestMonitoringPermissions() async {
    final locationWhenInUse = await Permission.locationWhenInUse.request();
    if (!locationWhenInUse.isGranted) return false;

    // Android requires foreground location to be granted before background location is requested.
    await Permission.locationAlways.request();
    await Permission.activityRecognition.request();
    await Permission.notification.request();

    if (Platform.isAndroid && !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    return true;
  }

  static Future<bool> get hasBackgroundLocation async => (await Permission.locationAlways.status).isGranted;

  static Future<void> openAppPermissionSettings() => openAppSettings();
}