// File: lib/features/nursery/pages/child_profile_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ChildProfilePage extends StatelessWidget {
  final Map<String, dynamic> child;

  const ChildProfilePage({super.key, required this.child});

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return "N/A";
    try {
      return DateFormat.yMMMd().format(DateTime.parse(iso));
    } catch (_) {
      return iso; // fall back to raw string if parse fails
    }
  }

  String _ifBlank(String? s, String fallback) {
    final v = s?.trim();
    return (v == null || v.isEmpty) ? fallback : v;
  }

  @override
  Widget build(BuildContext context) {
    final displayName   = _ifBlank(child['display_name'] as String?, 'Child Profile');
    final photoUrl      = child['photo_url'] as String?;
    final birthdayLabel = _formatDate(child['birthday'] as String?);
    final allergies     = _ifBlank(child['allergies'] as String?, 'None');
    final notes         = _ifBlank(child['notes'] as String?, 'None');
    final emergency     = _ifBlank(child['emergency_contact'] as String?, 'N/A');
    final isCheckedIn   = child['is_checked_in'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 60,
              foregroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? const Icon(Icons.child_care, size: 48)
                  : null,
            ),
          ),
          const SizedBox(height: 20),

          // “Born: <date>”
          Text("key_252".tr(args: [birthdayLabel]),
              style: Theme.of(context).textTheme.bodyLarge),

          const SizedBox(height: 10),
          Text("key_253".tr(args: [allergies])),
          const SizedBox(height: 10),
          Text("key_254".tr(args: [notes])),
          const SizedBox(height: 10),
          Text("key_255".tr(args: [emergency])),

          if (isCheckedIn)
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
