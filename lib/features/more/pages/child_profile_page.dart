// File: lib/features/nursery/pages/child_profile_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ChildProfilePage extends StatelessWidget {
  final Map<String, dynamic> child;

  const ChildProfilePage({super.key, required this.child});

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      return DateFormat.yMMMd().format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = child['display_name'] ?? 'Child Profile';
    final photoUrl = child['photo_url'];
    final birthday = _formatDate(child['birthday']);
    final allergies = (child['allergies']?.toString().trim().isNotEmpty ?? false)
        ? child['allergies']
        : 'None';
    final notes = (child['notes']?.toString().trim().isNotEmpty ?? false)
        ? child['notes']
        : 'None';
    final emergencyContact = child['emergency_contact'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? const Icon(Icons.child_care, size: 48)
                : null,
          ),
          const SizedBox(height: 20),
          Text("key_252".tr(args: [birthday])),
          const SizedBox(height: 10),
          Text("key_253".tr(args: [allergies])),
          const SizedBox(height: 10),
          Text("key_254".tr(args: [notes])),
          const SizedBox(height: 10),
          Text("key_255".tr(args: [emergencyContact])),
          if (child['is_checked_in'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.green),
                label: Text("key_256".tr()),
              ),
            ),
        ],
      ),
    );
  }
}