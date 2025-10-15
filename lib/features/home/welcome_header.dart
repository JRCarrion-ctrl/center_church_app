// File: lib/features/home/welcome_header.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({super.key});

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
  DateTime _getNextServiceTime({required DateTime now, required int hour, required int minute}) {
    const sunday = DateTime.sunday;
    final currentDay = now.weekday;
    final daysUntilSunday = (sunday - currentDay + 7) % 7;
    
    var serviceDate = now.add(Duration(days: daysUntilSunday));
    var serviceTime = DateTime(serviceDate.year, serviceDate.month, serviceDate.day, hour, minute);

    if (serviceTime.isBefore(now)) {
      serviceTime = serviceTime.add(const Duration(days: 7));
    }
    
    return serviceTime;
  }

  @override
  Widget build(BuildContext context) {
    final nextEnglish = _getNextServiceTime(now: _currentTime, hour: 9, minute: 30);
    final nextSpanish = _getNextServiceTime(now: _currentTime, hour: 11, minute: 30);

    return NextServiceCard(
      nextEnglishService: nextEnglish,
      nextSpanishService: nextSpanish,
      currentTime: _currentTime,
    );
  }
}

class NextServiceCard extends StatelessWidget {
  final DateTime nextEnglishService;
  final DateTime nextSpanishService;
  final DateTime currentTime;

  const NextServiceCard({
    super.key,
    required this.nextEnglishService,
    required this.nextSpanishService,
    required this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        // ✨ CHANGE: The border now has more contrast for a sharper look.
        border: Border.all(color: colorScheme.outline, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            "key_420".tr(), // "Join Us"
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "key_421".tr(), // "this sunday"
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),
          _ServiceTimeRow(
            title: "key_422".tr(), // "English Service"
            time: DateFormat.jm().format(nextEnglishService),
          ),
          const SizedBox(height: 16),
          _ServiceTimeRow(
            title: "key_423".tr(), // "Spanish Service"
            time: DateFormat.jm().format(nextSpanishService),
          ),
        ],
      ),
    );
  }
}

class _ServiceTimeRow extends StatelessWidget {
  final String title;
  final String time;

  const _ServiceTimeRow({
    required this.title,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(title, style: textTheme.titleMedium),
        const Spacer(),
        Text(
          time,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}