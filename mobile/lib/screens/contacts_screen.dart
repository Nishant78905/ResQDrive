import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/emergency_contact.dart';
import '../providers/app_provider.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  Future<void> _edit(BuildContext context, {EmergencyContact? contact}) async {
    final name = TextEditingController(text: contact?.fullName ?? '');
    final relation = TextEditingController(text: contact?.relationship ?? '');
    final phone = TextEditingController(text: contact?.phone ?? '');
    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact == null ? 'Add contact' : 'Edit contact'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          TextField(controller: relation, decoration: const InputDecoration(labelText: 'Relationship')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, EmergencyContact(id: contact?.id ?? '', fullName: name.text.trim(), relationship: relation.text.trim(), phone: phone.text.trim(), priority: contact?.priority ?? 1, notificationEnabled: contact?.notificationEnabled ?? false)), child: const Text('Save')),
        ],
      ),
    );
    name.dispose(); relation.dispose(); phone.dispose();
    if (result == null || !context.mounted) return;
    final state = context.read<AppProvider>();
    try {
      if (contact == null) { await state.addContact(result); } else { await state.updateContact(contact.id, result); }
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contact could not be saved: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts'), actions: [IconButton(onPressed: () => _edit(context), icon: const Icon(Icons.add))]),
      body: RefreshIndicator(onRefresh: () => context.read<AppProvider>().loadRemoteData(), child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('People RESQDRIVE can reach if you need help.'),
          const SizedBox(height: 16),
          ...state.contacts.map((contact) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(contact.fullName.isEmpty ? '?' : contact.fullName[0].toUpperCase())),
              title: Text(contact.fullName),
              subtitle: Text('${contact.relationship} · ${contact.phone}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(value: contact.notificationEnabled, onChanged: (enabled) => state.updateContact(contact.id, EmergencyContact(id: contact.id, fullName: contact.fullName, relationship: contact.relationship, phone: contact.phone, email: contact.email, preferredChannel: contact.preferredChannel, priority: contact.priority, notificationEnabled: enabled))),
                PopupMenuButton<String>(onSelected: (action) { if (action == 'edit') _edit(context, contact: contact); if (action == 'delete') state.removeContact(contact.id); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))]),
              ]),
            ),
          )),
          if (state.contacts.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No contacts added yet.'))),
        ],
      )),
    );
  }
}
