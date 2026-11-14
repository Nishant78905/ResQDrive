import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import 'app_navigator.dart';
import 'providers/app_provider.dart';
import 'services/crash_alert_notification_service.dart';
import 'services/monitoring_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  MonitoringService.initialize();
  await CrashAlertNotificationService.initialize();
  runApp(ChangeNotifierProvider(create: (_) => AppProvider()..restoreSession(), child: const ResqDriveApp()));
}

class ResqDriveApp extends StatelessWidget {
  const ResqDriveApp({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppProvider>(
        builder: (context, state, _) => MaterialApp(
          title: 'RESQDRIVE',
          navigatorKey: AppNavigator.key,
          debugShowCheckedModeBanner: false,
          themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935), surface: const Color(0xFFF6F5F2)),
            scaffoldBackgroundColor: const Color(0xFFF6F5F2),
            cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935), brightness: Brightness.dark),
          ),
            home: state.isInitializing
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : state.isAuthenticated
                ? const MainShell()
                : const AuthScreen(),
        ),
      );
}