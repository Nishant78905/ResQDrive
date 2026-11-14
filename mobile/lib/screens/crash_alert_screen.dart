import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CrashAlertScreen extends StatefulWidget {
  const CrashAlertScreen({super.key, required this.countdownSeconds, this.startedAt});
  final int countdownSeconds;
  final DateTime? startedAt;

  @override
  State<CrashAlertScreen> createState() => _CrashAlertScreenState();
}

class _CrashAlertScreenState extends State<CrashAlertScreen> {
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    final elapsed = widget.startedAt == null ? 0 : DateTime.now().difference(widget.startedAt!).inSeconds;
    _remaining = (widget.countdownSeconds - elapsed).clamp(0, widget.countdownSeconds).toInt();
    if (_remaining == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      if (_remaining <= 1) {
        _timer?.cancel();
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / widget.countdownSeconds;
    return Scaffold(backgroundColor: const Color(0xFFE53935), body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 24), child: Column(children: [
      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('RESQDRIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)), Text('⚠  POSSIBLE IMPACT', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11))]),
      const Spacer(), const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 48), const SizedBox(height: 20), const Text('WE DETECTED A SUDDEN IMPACT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)), const SizedBox(height: 9), const Text('Are you okay?', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)), const SizedBox(height: 9), const Text('Your emergency contacts will be notified when the timer ends. Tap below if you are safe.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.4)),
      const SizedBox(height: 26), SizedBox(width: 178, height: 178, child: Stack(alignment: Alignment.center, children: [SizedBox.expand(child: CircularProgressIndicator(value: progress, strokeWidth: 6, backgroundColor: Colors.white30, valueColor: const AlwaysStoppedAnimation(Colors.white))), Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$_remaining', style: const TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w800)), const Text('SECONDS LEFT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700))])])),
      const Spacer(), SizedBox(width: double.infinity, height: 64, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF16764D)), onPressed: () { _timer?.cancel(); Navigator.of(context).pop(false); }, icon: const Icon(Icons.check_circle_outline), label: const Text("I'M SAFE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)))), const SizedBox(height: 12), SizedBox(width: double.infinity, height: 52, child: OutlinedButton(onPressed: () { _timer?.cancel(); Navigator.of(context).pop(true); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)), child: const Text('Send SOS now', style: TextStyle(fontWeight: FontWeight.w800)))), const SizedBox(height: 15), const Text('Your location will be shared with your emergency contacts.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 10)),
    ]))));
  }
}