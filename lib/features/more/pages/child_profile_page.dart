// File: lib/features/nursery/pages/child_profile_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ChildProfilePage extends StatelessWidget {
  final Map<String, dynamic> child;

  const ChildProfilePage({super.key, required this.child});

  // Utility to format the date string (as YYYY-MM-DD) into a user-friendly format
  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return "N/A";
    try {
      // DateFormat.yMMMd() formats to "Oct 27, 2024"
      return DateFormat.yMMMd().format(DateTime.parse(iso));
    } catch (_) {
      return iso; // fall back to raw string if parse fails
    }
  }

  // Utility to replace null or empty strings with a fallback
  String _ifBlank(String? s, String fallback) {
    final v = s?.trim();
    return (v == null || v.isEmpty) ? fallback : v;
  }

  // A simple widget to display a profile detail field
  Widget _buildDetailRow(BuildContext context, String titleKey, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleKey.tr(), // e.g., "Birthday", "Allergies"
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _ifBlank(child['display_name'] as String?, 'Child Profile');
    final photoUrl    = child['photo_url'] as String?;
    // Data retrieval remains the same, assuming 'birthday' is YYYY-MM-DD string
    final birthdayLabel = _formatDate(child['birthday'] as String?);
    final allergies     = _ifBlank(child['allergies'] as String?, 'key_253_none'.tr()); // Custom fallback key suggestion
    final notes         = _ifBlank(child['notes'] as String?, 'key_254_none'.tr());
    final emergency     = _ifBlank(child['emergency_contact'] as String?, 'key_255_none'.tr());
    final isCheckedIn   = child['is_checked_in'] == true;
    
    // Family ID is often needed for navigation/permissions, though not displayed
    // final familyId    = child['family_id'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Photo/Avatar Section
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
          const Divider(),

          // Birthday
          _buildDetailRow(context, "key_252_title".tr(), birthdayLabel), // "Born" changed to a title key

          // Allergies
          _buildDetailRow(context, "key_238c".tr(), allergies), // key_238c = "Allergies"

          // Notes
          _buildDetailRow(context, "key_238d".tr(), notes), // key_238d = "Notes"

          // Emergency Contact
          _buildDetailRow(context, "key_238e".tr(), emergency), // key_238e = "Emergency Contact"

          // Check-in Status
          if (isCheckedIn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Chip(
                avatar: const Icon(Icons.check_circle, color: Colors.green),
                label: Text("key_256".tr()),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}