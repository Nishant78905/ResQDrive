import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'profile_screen.dart';
import 'notification_history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.onBack});
  final VoidCallback? onBack;

  Future<void> _editNumber(BuildContext context, AppProvider state, {required bool police}) async {
    final controller = TextEditingController(text: police ? state.policePhone : state.ambulancePhone);
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Text('${police ? 'Police' : 'Ambulance'} number'), content: TextField(controller: controller, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+91...')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save'))]));
    controller.dispose();
    if (value == null) return;
    if (police) { state.policePhone = value; } else { state.ambulancePhone = value; }
    await state.saveEmergencySettings();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppProvider>();
    return Scaffold(appBar: AppBar(title: const Text('Settings'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)), body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      const Text('CRASH DETECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)), const SizedBox(height: 8), Card(child: Column(children: [ListTile(title: const Text('Sensitivity'), subtitle: const Text('Impact detection threshold'), trailing: SegmentedButton<String>(segments: const [ButtonSegment(value: 'Low', label: Text('Low')), ButtonSegment(value: 'Med', label: Text('Med')), ButtonSegment(value: 'High', label: Text('High'))], selected: {state.sensitivity}, onSelectionChanged: (value) => state.setSensitivity(value.first))), const Divider(height: 1), ListTile(title: const Text('Alert countdown'), subtitle: Slider(value: state.countdownSeconds.toDouble(), min: 10, max: 15, divisions: 5, label: '${state.countdownSeconds} sec', onChanged: (value) => state.setCountdown(value.round())), trailing: Text('${state.countdownSeconds}s')), const Divider(height: 1), SwitchListTile(title: const Text('Background monitoring'), subtitle: const Text('Sensor service status'), value: state.monitoringActive, onChanged: state.setMonitoring)])),
      const SizedBox(height: 20), const Text('EMERGENCY COMMUNICATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)), const SizedBox(height: 8), Card(child: Column(children: [ListTile(title: const Text('Police number'), subtitle: Text(state.policePhone.isEmpty ? 'Not configured' : state.policePhone), trailing: TextButton(onPressed: () => _editNumber(context, state, police: true), child: const Text('Edit'))), SwitchListTile(title: const Text('Police SMS'), value: state.policeEnabled, onChanged: (value) async { state.policeEnabled = value; await state.saveEmergencySettings(); }), const Divider(height: 1), ListTile(title: const Text('Ambulance number'), subtitle: Text(state.ambulancePhone.isEmpty ? 'Not configured' : state.ambulancePhone), trailing: TextButton(onPressed: () => _editNumber(context, state, police: false), child: const Text('Edit'))), SwitchListTile(title: const Text('Ambulance SMS'), value: state.ambulanceEnabled, onChanged: (value) async { state.ambulanceEnabled = value; await state.saveEmergencySettings(); })])),
      const SizedBox(height: 20), const Text('PERMISSIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)), const SizedBox(height: 8), Card(child: Column(children: [ListTile(title: const Text('Location'), subtitle: const Text('For emergency coordinates'), trailing: Text(state.locationStatus)), const Divider(height: 1), const ListTile(title: Text('Motion sensors'), subtitle: Text('For crash detection'), trailing: Text('Managed')), const Divider(height: 1), const ListTile(title: Text('Notifications'), subtitle: Text('For urgent safety alerts'), trailing: Text('Managed')), const Divider(height: 1), const ListTile(title: Text('Battery optimization'), subtitle: Text('May affect background monitoring'), trailing: Text('Review'))])),
      const SizedBox(height: 20), Card(child: SwitchListTile(title: const Text('Dark mode'), subtitle: const Text('Reduce brightness at night'), value: state.isDarkMode, onChanged: state.setDarkMode)), const SizedBox(height: 18), OutlinedButton.icon(onPressed: () => state.logout(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
      const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())), icon: const Icon(Icons.person_outline), label: const Text('User profile')), const SizedBox(height: 8), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationHistoryScreen())), icon: const Icon(Icons.history), label: const Text('Emergency notification history')),
    ]));
  }
}
