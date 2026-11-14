import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _obscurePassword = true;

  @override
  void dispose() { _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppProvider>();
    final success = _registering
        ? await state.register(_name.text.trim(), _email.text.trim(), _password.text)
        : await state.login(_email.text.trim(), _password.text);
    if (!success && mounted && state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppProvider>();
    final color = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.error, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add_road, color: Colors.white, size: 20)), const SizedBox(width: 10), const Text('RESQDRIVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3)), const Spacer(), IconButton(tooltip: 'Toggle dark mode', onPressed: () => state.setDarkMode(!state.isDarkMode), icon: const Icon(Icons.dark_mode_outlined))]),
        const SizedBox(height: 27),
        Container(height: 190, decoration: BoxDecoration(color: color.errorContainer.withValues(alpha: .35), borderRadius: BorderRadius.circular(24)), child: Center(child: Container(width: 84, height: 84, decoration: BoxDecoration(color: color.error, borderRadius: BorderRadius.circular(26)), child: const Icon(Icons.add, color: Colors.white, size: 48)))),
        const SizedBox(height: 27), Text(_registering ? 'A safer start starts here.' : 'Every drive, looked after.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8), Text(_registering ? 'Create an account and add the people you trust.' : 'Your safety contacts are one tap away. Sign in to start a protected drive.', style: TextStyle(color: color.onSurfaceVariant, height: 1.45)),
        const SizedBox(height: 22), Form(key: _formKey, child: Column(children: [
          if (_registering) ...[
            TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Enter your name' : null),
            const SizedBox(height: 12),
          ],
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', border: OutlineInputBorder()), validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email' : null),
          const SizedBox(height: 12), TextFormField(controller: _password, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Password', border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: _obscurePassword ? 'Show password' : 'Hide password', onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (value) => value == null || value.length < 8 ? 'Use at least 8 characters' : null),
          const SizedBox(height: 16), SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: state.isLoading ? null : _submit, child: state.isLoading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_registering ? 'Create account' : 'Sign in'))),
        ])),
        TextButton(onPressed: () => setState(() => _registering = !_registering), child: Text(_registering ? 'Already have an account? Sign in' : 'New to RESQDRIVE? Create account')),
        OutlinedButton.icon(onPressed: state.continueDemo, icon: const Icon(Icons.explore_outlined), label: const Text('Explore demo')),
        const SizedBox(height: 11), Text('Prototype · Sign-in details are not stored in demo mode', textAlign: TextAlign.center, style: TextStyle(color: color.onSurfaceVariant, fontSize: 11)),
      ])),
    ))));
  }
}