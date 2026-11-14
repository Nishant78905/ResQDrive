import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onSimulateCrash, required this.onOpenSettings, required this.onOpenHistory});
  final VoidCallback onSimulateCrash;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppProvider>();
    final vehicle = state.vehicles.where((item) => item.selected).firstOrNull;
    return Scaffold(
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 26), children: [
        Row(children: [const Text('RESQDRIVE', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.2)), const Spacer(), IconButton(tooltip: 'Settings', onPressed: onOpenSettings, icon: const Icon(Icons.settings_outlined))]),
        const SizedBox(height: 20),
        Text('Good morning, ${state.profileName}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text('Your safety is being watched over.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        Card(
          color: const Color(0xFF202725),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Expanded(child: Text(state.monitoringActive ? 'Protection on' : 'Protection off', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
              Switch(value: state.monitoringActive, onChanged: state.setMonitoring),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        const Text('CURRENT VEHICLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
        Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.directions_car_outlined)), title: Text(vehicle?.model ?? 'No vehicle selected'), subtitle: Text(vehicle == null ? 'Add a vehicle to associate it with incidents.' : '${vehicle.plateNumber} · ${vehicle.color}'))),
        const SizedBox(height: 16),
        const Text('LOCATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
        Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.location_on_outlined)), title: Text(state.locationStatus), subtitle: Text(state.currentPosition == null ? 'Tap refresh to request the device location.' : '${state.currentPosition!.latitude.toStringAsFixed(6)}, ${state.currentPosition!.longitude.toStringAsFixed(6)}'), trailing: IconButton(onPressed: state.refreshLocation, icon: const Icon(Icons.refresh)))),
        const SizedBox(height: 16),
        Row(children: [const Text('RECENT INCIDENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)), const Spacer(), TextButton(onPressed: onOpenHistory, child: const Text('See history'))]),
        if (state.history.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No incidents recorded.' ))),
        ...state.history.take(3).map((item) => Card(child: ListTile(title: Text(item.displayDate), subtitle: Text(item.location), trailing: Text(item.status, style: const TextStyle(fontSize: 10))))),
        if (state.isDemo) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: onSimulateCrash, icon: const Icon(Icons.warning_amber_rounded), label: const Text('Simulate crash'))],
      ])),
    );
  }
}
