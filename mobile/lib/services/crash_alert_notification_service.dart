import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../screens/crash_alert_screen.dart';

class CrashAlertNotificationService {
  CrashAlertNotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static VoidCallback? _alertHandler;

  static Future<void> initialize() async {
    if (_initialized) return;
    await _notifications.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_launcher')),
      onDidReceiveNotificationResponse: (_) => openAlert(),
    );
    _initialized = true;
  }

  static Future<void> requestAndroidPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestFullScreenIntentPermission();
  }

  static Future<void> showCrashAlert() async {
    await initialize();
    await _notifications.show(
      id: 410,
      title: 'Possible crash detected',
      body: 'Tap to confirm you are safe. Your emergency alert is counting down.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'resqdrive_crash_alerts',
          'Crash alerts',
          channelDescription: 'Urgent crash confirmation alerts',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 800]),
        ),
      ),
      payload: 'crash-alert',
    );
  }

  static void openAlert() {
    if (_alertHandler != null) {
      _alertHandler!();
      return;
    }
    final navigator = AppNavigator.key.currentState;
    if (navigator == null) return;
    navigator.push(MaterialPageRoute<void>(builder: (_) => const CrashAlertScreen(countdownSeconds: 15)));
  }

  static void setAlertHandler(VoidCallback? handler) => _alertHandler = handler;

  static Future<void> dismiss() => _notifications.cancel(id: 410);
}