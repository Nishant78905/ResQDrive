import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vehicle.dart';
import '../providers/app_provider.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  Future<void> _addVehicle(BuildContext context) async {
    final plate = TextEditingController(), model = TextEditingController(), color = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Vehicle>(context: context, builder: (context) => AlertDialog(title: const Text('Add vehicle'), content: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [TextFormField(controller: plate, decoration: const InputDecoration(labelText: 'Plate number'), validator: requiredField), TextFormField(controller: model, decoration: const InputDecoration(labelText: 'Make and model'), validator: requiredField), TextFormField(controller: color, decoration: const InputDecoration(labelText: 'Color'), validator: requiredField)])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(context, Vehicle(id: DateTime.now().microsecondsSinceEpoch.toString(), plateNumber: plate.text.trim(), model: model.text.trim(), color: color.text.trim())); }, child: const Text('Save'))]));
    plate.dispose(); model.dispose(); color.dispose();
    if (result != null && context.mounted) context.read<AppProvider>().addVehicle(result);
  }

  static String? requiredField(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppProvider>();
    return Scaffold(appBar: AppBar(title: const Text('Vehicles'), actions: [IconButton(tooltip: 'Add vehicle', onPressed: () => _addVehicle(context), icon: const Icon(Icons.add))]), body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [Text('Choose the vehicle you are driving for each trip.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 18), Text('YOUR VEHICLES · ${state.vehicles.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)), const SizedBox(height: 8), if (state.vehicles.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No vehicles added yet.'))), ...state.vehicles.map((vehicle) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.directions_car_outlined)), title: Text(vehicle.model), subtitle: Text('${vehicle.plateNumber} · ${vehicle.color}${vehicle.selected ? ' · Selected' : ''}'), trailing: PopupMenuButton<String>(onSelected: (action) { if (action == 'select') state.selectVehicle(vehicle.id); if (action == 'delete') state.removeVehicle(vehicle.id); }, itemBuilder: (_) => const [PopupMenuItem(value: 'select', child: Text('Select vehicle')), PopupMenuItem(value: 'delete', child: Text('Delete'))]))))]));
  }
}