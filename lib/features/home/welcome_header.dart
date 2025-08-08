// File: lib/features/home/welcome_header.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/app_state.dart';
import 'package:easy_localization/easy_localization.dart';

class WelcomeHeader extends StatefulWidget {
  const WelcomeHeader({super.key});

  @override
  State<WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<WelcomeHeader> {
  late Timer _timer;
  late DateTime _nextEnglish;
  late DateTime _nextSpanish;
  Duration _untilEnglish = Duration.zero;
  Duration _untilSpanish = Duration.zero;

  @override
  void initState() {
    super.initState();
    _nextEnglish = _getNextServiceTime(hour: 9, minute: 30);
    _nextSpanish = _getNextServiceTime(hour: 11, minute: 30);
    _updateCountdowns();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateCountdowns());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateCountdowns() {
    final now = DateTime.now();
    setState(() {
      _untilEnglish = _nextEnglish.difference(now);
      _untilSpanish = _nextSpanish.difference(now);
    });
  }

  DateTime _getNextServiceTime({required int hour, required int minute}) {
    final now = DateTime.now();
    final sundayOffset = (DateTime.sunday - now.weekday + 7) % 7;
    final nextSunday = now.add(Duration(days: sundayOffset));
    var serviceTime = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, hour, minute);

    if (serviceTime.isBefore(now)) {
      serviceTime = serviceTime.add(const Duration(days: 7));
    }

    return serviceTime;
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    return '${days}d ${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final color = brightness == Brightness.dark ? Colors.white : Colors.black;
    final showCountdown = context.watch<AppState>().showCountdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "key_189a".tr(),
          style: theme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "key_189b".tr(),
          style: theme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (showCountdown)
          Text(
            ' ${_formatDuration(_untilEnglish)}',
            style: theme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        const SizedBox(height: 12),
        Text(
          "key_189c".tr(),
          style: theme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (showCountdown)
          Text(
            ' ${_formatDuration(_untilSpanish)}',
            style: theme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
      ],
    );
  }
}
