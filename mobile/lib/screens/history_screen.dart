import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppProvider>().history;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppProvider>().loadRemoteData(),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Text('Recorded incidents from your account.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
          const SizedBox(height: 8),
          if (history.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No incidents recorded.'))),
          ...history.map((item) => Card(child: ListTile(
                leading: const Icon(Icons.circle, color: Color(0xFFE53935), size: 12),
                title: Text(item.displayDate, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Incident ${item.id} · ${item.location}'),
                trailing: Text(item.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              ))),
        ]),
      ),
    );
  }
}
