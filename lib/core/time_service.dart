import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class TimeService {
  /// Format a UTC DateTime into a readable local time string.
  static String formatUtcToLocal(DateTime utcTime, {String pattern = 'MMM d, yyyy • h:mm a'}) {
    final localTime = utcTime.toLocal();
    return DateFormat(pattern).format(localTime);
  }

  /// Format a UTC DateTime into a short local date string.
  static String formatUtcToLocalDate(DateTime utcTime) {
    return DateFormat.yMd().format(utcTime.toLocal());
  }

  /// Format a UTC DateTime into a local time only string.
  static String formatUtcToLocalTime(DateTime utcTime) {
    return DateFormat.jm().format(utcTime.toLocal());
  }

  /// Combine a user-selected local date and time, convert it to UTC for storage.
  static DateTime combineLocalDateAndTimeToUtc(DateTime date, TimeOfDay time) {
    final localDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return localDateTime.toUtc();
  }

  /// Returns how much time remains until a UTC event, in local time.
  static Duration timeUntil(DateTime utcEventTime) {
    return utcEventTime.toLocal().difference(DateTime.now());
  }

  /// Returns true if the UTC time has already passed, in local time.
  static bool hasPassed(DateTime utcTime) {
    return utcTime.toLocal().isBefore(DateTime.now());
  }

  /// Formats a countdown like "2 Days, 3 Hours"
  static String formatCountdown(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days Day${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('$hours Hour${hours > 1 ? 's' : ''}');
    if (minutes > 0 && parts.isEmpty) parts.add('$minutes Minute${minutes > 1 ? 's' : ''}');

    return parts.join(', ');
  }

  /// Smart chat-style timestamp like "Today, 3:40 PM"
  static String formatSmartTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(local.year, local.month, local.day);
    final timePart = DateFormat.jm().format(local);

    if (messageDay == today) return 'Today, $timePart';
    if (messageDay == today.subtract(const Duration(days: 1))) return 'Yesterday, $timePart';
    return DateFormat('MMMM d, y – h:mm a').format(local);
  }

  /// Relative timestamp for notifications: "5m ago", "2h ago", "Jul 15"
  static String formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    return DateFormat('MMM d').format(local); // fallback
  }
}
