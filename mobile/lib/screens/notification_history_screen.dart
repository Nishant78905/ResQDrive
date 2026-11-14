import 'package:flutter/material.dart';

import '../services/api_service.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency history')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ApiService().notificationHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final events = snapshot.data!;
          if (events.isEmpty) return const Center(child: Text('No emergency notifications yet.'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final event in events)
                Card(
                  child: ListTile(
                    leading: Icon(
                      event['event_status'] == 'COMPLETED' ? Icons.check_circle : Icons.warning_amber,
                      color: event['event_status'] == 'COMPLETED' ? Colors.green : Colors.orange,
                    ),
                    title: Text('${event['event_type']} · ${event['event_status']}'),
                    subtitle: Text('${event['created_at']}\n${(event['notifications'] as List<dynamic>? ?? []).length} notification(s)'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
