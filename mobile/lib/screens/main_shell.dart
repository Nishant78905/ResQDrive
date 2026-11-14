import 'dart:async';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/crash_alert_notification_service.dart';
import 'contacts_screen.dart';
import 'crash_alert_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'sos_screen.dart';
import 'vehicles_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _alertInProgress = false;
  bool _backDialogOpen = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppProvider>();
    state.refreshLocation();
    if (state.monitoringActive) state.startCrashDetection();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    CrashAlertNotificationService.setAlertHandler(() => _startDemoAlert());
    if (state.activeIncidentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startDemoAlert(detectedAt: state.activeIncidentStartedAt);
      });
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    CrashAlertNotificationService.setAlertHandler(null);
    super.dispose();
  }

  void _onTaskData(Object data) {
    if (data is Map && data['type'] == 'crash' && mounted) {
      final gyroData = <String, double>{
        'x': (data['gyroX'] as num?)?.toDouble() ?? 0,
        'y': (data['gyroY'] as num?)?.toDouble() ?? 0,
        'z': (data['gyroZ'] as num?)?.toDouble() ?? 0,
      };
      _startDemoAlert(
        peakG: (data['peakG'] as num?)?.toDouble() ?? 4.25,
        gyroData: gyroData,
        detectedAt: DateTime.tryParse('${data['detectedAt'] ?? ''}')?.toLocal(),
      );
    }
  }

  Future<void> _startDemoAlert({double peakG = 4.25, Map<String, double> gyroData = const {'x': 0.31, 'y': 4.12, 'z': 0.18}, DateTime? detectedAt}) async {
    if (_alertInProgress) return;
    _alertInProgress = true;
    try {
    final state = context.read<AppProvider>();
    final countdown = state.countdownSeconds;
    final simulated = state.isDemo;
    final incidentTime = detectedAt ?? DateTime.now();
    final draftFuture = simulated
      ? Future<String?>.value(null)
      : state.activeIncidentId != null
        ? Future<String?>.value(state.activeIncidentId)
            : state.createIncidentDraft(peakG: peakG, gyroData: gyroData, timestamp: incidentTime);
    final sendSos = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => CrashAlertScreen(countdownSeconds: countdown, startedAt: incidentTime),
      fullscreenDialog: true,
    ));
    await CrashAlertNotificationService.dismiss();
    final incidentId = await draftFuture;
    if (sendSos == true && mounted) {
      final queued = simulated
          ? false
          : incidentId != null
              ? !await state.escalateIncidentDraft(incidentId)
              : await state.submitIncident(peakG: peakG, gyroData: gyroData, timestamp: incidentTime);
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SosScreen(queued: queued, simulated: simulated)));
    } else if (incidentId != null) {
      await state.cancelIncidentDraft(incidentId);
    }
    } finally {
      _alertInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(onSimulateCrash: _startDemoAlert, onOpenSettings: () => setState(() => _index = 4), onOpenHistory: () => setState(() => _index = 3)),
      const ContactsScreen(),
      const VehiclesScreen(),
      const HistoryScreen(),
      SettingsScreen(onBack: () => setState(() => _index = 0)),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !mounted) return;
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        if (_backDialogOpen) return;
        _backDialogOpen = true;
        final exit = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Exit RESQDRIVE?'), content: const Text('The app will close, but your account will remain signed in.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Exit'))]));
        _backDialogOpen = false;
        if (exit == true) await SystemNavigator.pop();
      },
      child: Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index == 4 ? 0 : _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Vehicles'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
      ),
    );
  }
}
