// File: lib/features/nursery/pages/child_profile_page.dart
import 'package:flutter/material.dart';

class ChildProfilePage extends StatelessWidget {
  final Map<String, dynamic> child;

  const ChildProfilePage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(child['display_name'] ?? 'Child Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: child['photo_url'] != null
                ? NetworkImage(child['photo_url'])
                : null,
            child: child['photo_url'] == null
                ? const Icon(Icons.child_care, size: 48)
                : null,
          ),
          const SizedBox(height: 20),
          Text('Birthday: ${child['birthday'] ?? 'N/A'}'),
          const SizedBox(height: 10),
          Text('Allergies: ${child['allergies'] ?? 'None'}'),
          const SizedBox(height: 10),
          Text('Emergency Contact: ${child['emergency_contact'] ?? 'N/A'}'),
        ],
      ),
    );
  }
}
