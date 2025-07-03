// File: lib/features/groups/pages/group_info_page.dart
import 'package:flutter/material.dart';

class GroupInfoPage extends StatelessWidget {
  final String groupId;
  final bool isAdmin;

  const GroupInfoPage({super.key, required this.groupId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGroupHeader(context),
          const SizedBox(height: 24),
          _buildSectionHeader('Pinned Messages'),
          _buildPinnedMessages(),
          const SizedBox(height: 24),
          _buildSectionHeader('Events'),
          _buildGroupEvents(),
          const SizedBox(height: 24),
          _buildSectionHeader('Announcements'),
          _buildGroupAnnouncements(),
          const SizedBox(height: 24),
          _buildSectionHeader('Media'),
          _buildGroupMedia(),
          const SizedBox(height: 24),
          _buildSectionHeader('Members'),
          _buildGroupMembers(),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isAdmin ? () => _changeGroupPhoto(context) : null,
          child: CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage('https://via.placeholder.com/150'), // TODO: Replace with actual photo
          ),
        ),
        const SizedBox(height: 12),
        isAdmin ? _editableGroupName(context) : const Text('Group Name', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        isAdmin ? _editableGroupDescription(context) : const Text('Group description goes here.')
      ],
    );
  }

  Widget _editableGroupName(BuildContext context) {
    return TextFormField(
      initialValue: 'Group Name',
      decoration: const InputDecoration(labelText: 'Group Name'),
      onFieldSubmitted: (value) {
        // TODO: Save to Supabase
      },
    );
  }

  Widget _editableGroupDescription(BuildContext context) {
    return TextFormField(
      initialValue: 'Group description goes here.',
      maxLines: 2,
      decoration: const InputDecoration(labelText: 'Description'),
      onFieldSubmitted: (value) {
        // TODO: Save to Supabase
      },
    );
  }

  Widget _buildSectionHeader(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildPinnedMessages() => const Placeholder(fallbackHeight: 80);
  Widget _buildGroupEvents() => const Placeholder(fallbackHeight: 80);
  Widget _buildGroupAnnouncements() => const Placeholder(fallbackHeight: 80);
  Widget _buildGroupMedia() => const Placeholder(fallbackHeight: 80);
  Widget _buildGroupMembers() => const Placeholder(fallbackHeight: 80);

  void _changeGroupPhoto(BuildContext context) {
    // TODO: Implement file picker and upload logic
  }
}
