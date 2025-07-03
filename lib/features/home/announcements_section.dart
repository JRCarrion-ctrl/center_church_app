// File: lib/features/home/announcements_section.dart
import 'package:flutter/material.dart';

class AnnouncementsSection extends StatelessWidget {
  const AnnouncementsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace these with actual announcement data
    final mainAnnouncements = ['Main Announcement 1', 'Main Announcement 2'];
    final groupAnnouncements = ['Group A', 'Group B', 'Group C'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Announcements',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...mainAnnouncements.map((text) => _buildAnnouncementCard(text)),
        const SizedBox(height: 20),
        const Text(
          'Group Announcements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groupAnnouncements.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildGroupCard(groupAnnouncements[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(String text) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text),
      ),
    );
  }

  Widget _buildGroupCard(String group) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue[50],
      ),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(group, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}
