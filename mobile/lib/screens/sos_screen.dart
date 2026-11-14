import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key, this.queued = false, this.simulated = false});
  final bool queued;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<AppProvider>().contacts;
    final position = context.watch<AppProvider>().currentPosition;
    final title = simulated ? 'SOS simulated' : queued ? 'SOS queued locally' : 'SOS submitted';
    final description = simulated ? 'Demo complete. No emergency contacts were contacted.' : queued ? 'The incident will be submitted when a connection is available.' : 'The backend accepted the incident. SMS delivery is still being verified.';
    return Scaffold(appBar: AppBar(title: const Text('RESQDRIVE'), automaticallyImplyLeading: false), body: ListView(padding: const EdgeInsets.all(20), children: [
      Card(color: const Color(0xFFE8F5EE), child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [const CircleAvatar(backgroundColor: Color(0xFF188B5A), child: Icon(Icons.check, color: Colors.white)), const SizedBox(height: 10), Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: const Color(0xFF116B45), fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text(description, textAlign: TextAlign.center)]))),
      const SizedBox(height: 22), const Text('INCIDENT LOCATION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)), const SizedBox(height: 10), Container(height: 190, decoration: BoxDecoration(color: const Color(0xFFE7E9E4), borderRadius: BorderRadius.circular(16)), child: const Center(child: Icon(Icons.location_on, color: Color(0xFFE53935), size: 42))),
      Card(child: ListTile(title: const Text('GPS coordinates'), trailing: Text(position == null ? 'Not available' : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.w700)))), const SizedBox(height: 18), const Text('EMERGENCY CONTACTS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)), const SizedBox(height: 9),
      ...contacts.take(2).map((contact) => Card(child: ListTile(leading: Icon(queued ? Icons.schedule : Icons.check_circle, color: queued ? const Color(0xFFBF7821) : const Color(0xFF188B5A)), title: Text(contact.fullName), subtitle: Text('${contact.phone} · ${queued ? 'Queued for retry' : simulated ? 'Demo only' : 'Alert sent'}')))), const SizedBox(height: 18), FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Return to dashboard')),
    ]));
  }
}
