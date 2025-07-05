// File: lib/features/groups/widgets/group_info_preview.dart
import 'package:flutter/material.dart';

class GroupInfoPreview extends StatelessWidget {
  final String groupId;
  final bool isAdmin;

  const GroupInfoPreview({super.key, required this.groupId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          context,
          title: 'Pinned Messages',
          onTap: () => Navigator.of(context).pushNamed('/group/$groupId/pins'),
          trailing: const Icon(Icons.push_pin_outlined),
        ),
        _buildSection(
          context,
          title: 'Events',
          onTap: () => Navigator.of(context).pushNamed('/group/$groupId/events'),
          trailing: const Icon(Icons.calendar_today_outlined),
        ),
        _buildSection(
          context,
          title: 'Media',
          onTap: () => Navigator.of(context).pushNamed('/group/$groupId/media'),
          trailing: const Icon(Icons.perm_media_outlined),
        ),
        if (isAdmin)
          _buildSection(
            context,
            title: 'Admin Tools',
            onTap: () => Navigator.of(context).pushNamed('/group/$groupId/admin'),
            trailing: const Icon(Icons.admin_panel_settings_outlined),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(BuildContext context,
      {required String title, required VoidCallback onTap, Widget? trailing}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
