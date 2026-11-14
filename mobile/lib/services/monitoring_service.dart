import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'crash_alert_notification_service.dart';
import 'crash_detection_service.dart';

@pragma('vm:entry-point')
void startMonitoringCallback() {
  FlutterForegroundTask.setTaskHandler(ResqDriveTaskHandler());
}

class MonitoringService {
  MonitoringService._();

  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'resqdrive_monitoring',
        channelName: 'RESQDRIVE protection',
        channelDescription: 'Keeps crash detection active during a drive',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 410,
      notificationTitle: 'RESQDRIVE protection is active',
      notificationText: 'Crash detection is monitoring your drive',
      notificationInitialRoute: '/',
      callback: startMonitoringCallback,
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
  }
}

class ResqDriveTaskHandler extends TaskHandler {
  CrashDetectionService? _detector;
  StreamSubscription<CrashDetectionResult>? _crashSubscription;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await CrashAlertNotificationService.initialize();
    _detector = CrashDetectionService();
    final sensitivity = await FlutterForegroundTask.getData(key: 'crash_sensitivity') as String?;
    if (sensitivity != null) _detector!.setSensitivity(sensitivity);
    _crashSubscription = _detector!.crashEvents.listen((result) async {
      FlutterForegroundTask.sendDataToMain({
        'type': 'crash',
        'detectedAt': result.detectedAt.toIso8601String(),
        'peakG': result.peakGForce,
        'gyroX': result.gyroscope.x,
        'gyroY': result.gyroscope.y,
        'gyroZ': result.gyroscope.z,
      });
      await CrashAlertNotificationService.showCrashAlert();
    });
    await _detector!.start();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.updateService(
      notificationTitle: 'RESQDRIVE protection is active',
      notificationText: 'Crash detection is monitoring your drive',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _crashSubscription?.cancel();
    await _detector?.dispose();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map && data['type'] == 'sensitivity' && data['value'] is String) {
      _detector?.setSensitivity(data['value'] as String);
    }
  }
}