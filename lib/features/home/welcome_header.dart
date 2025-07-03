// File: lib/features/home/welcome_header.dart
import 'dart:async';
import 'package:flutter/material.dart';

class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({super.key});

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  late Timer _timer;
  late DateTime _nextService;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _nextService = _calculateNextService();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    setState(() {
      _remaining = _nextService.difference(now);
    });
  }

  DateTime _calculateNextService() {
    final now = DateTime.now();
    DateTime sunday = now.add(Duration(days: (7 - now.weekday) % 7));
    return DateTime(sunday.year, sunday.month, sunday.day, 10); // Sunday at 10 AM
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'WELCOME',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Time Until Next Service: $days Days, $hours Hours',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
