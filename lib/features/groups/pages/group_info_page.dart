// File: lib/features/groups/pages/group_info_page.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';


import '../group_service.dart';
import '../models/group.dart';
import '../widgets/invite_user_modal.dart';

Future<File> _compressImage(File file) async {
  final targetPath = file.path.replaceFirst(RegExp(r'\.(jpg|jpeg|png|heic|webp)$'), '_compressed.jpg');
  final compressedBytes = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: 600, // or your preferred size
    minHeight: 600,
    quality: 80,    // adjust as needed
    format: CompressFormat.jpeg,
  );
  return File(targetPath)..writeAsBytesSync(compressedBytes!);
}

class GroupInfoPage extends StatefulWidget {
  final String groupId;
  final bool isAdmin;
  final bool isOwner;

  const GroupInfoPage({super.key, required this.groupId, required this.isAdmin, required this.isOwner});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  Group? group;
  bool isLoading = true;
  bool isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  void _openInviteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => InviteUserModal(groupId: widget.groupId),
    );
  }

  Future<void> _loadGroup() async {
    group = await GroupService().getGroupById(widget.groupId);
    _nameController = TextEditingController(text: group?.name ?? '');
    _descController = TextEditingController(text: group?.description ?? '');
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await GroupService().leaveGroup(widget.groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You left the group')),
      );
      context.go('/groups'); // Or wherever you want to redirect
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: $e')),
        );
      }
    }
  }

  
  Future<void> _saveGroupEdits() async {
    setState(() => isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await GroupService().updateGroup(
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
      );
      await _loadGroup();
      setState(() => isEditing = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Group info updated')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (group == null) return Scaffold(body: Center(child: Text('Group not found')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        actions: [
          if (widget.isAdmin && !isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => isEditing = true),
            ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveGroupEdits,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGroupHeader(context),
          const SizedBox(height: 24),
          _buildSectionHeader('Pinned Messages'),
          _buildPinnedMessages(context),
          const SizedBox(height: 24),
          _buildSectionHeader('Events'),
          _buildGroupEvents(context),
          const SizedBox(height: 24),
          _buildSectionHeader('Announcements'),
          _buildGroupAnnouncements(context),
          const SizedBox(height: 24),
          _buildSectionHeader('Media'),
          _buildGroupMedia(context),
          const SizedBox(height: 24),
          _buildSectionHeader('Members'),
          _buildGroupMembers(context),
          if (!widget.isAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton.icon(
                onPressed: _leaveGroup,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Leave Group'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),
          if (widget.isOwner)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final goes = context.go('/groups');
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Group'),
                      content: const Text('Are you sure you want to delete this group? This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  
                  try {
                    await GroupService().deleteGroup(widget.groupId);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Group deleted successfully')),
                      );
                      goes;
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to delete group: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.delete),
                label: const Text('Delete Group'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: widget.isAdmin ? () => _changeGroupPhoto(context) : null,
          child: CircleAvatar(
            radius: 40,
            child: (group?.photoUrl?.isNotEmpty ?? false)
                ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: group!.photoUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error, size: 40)
                  ),
                )
                : const Icon(Icons.group, size: 40)
          ),
        ),
        const SizedBox(height: 12),
        if (isEditing && widget.isAdmin)
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Group Name'),
          )
        else
          Text(group?.name ?? '', style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        if (isEditing && widget.isAdmin)
          TextFormField(
            controller: _descController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Description'),
          )
        else
          Text(group?.description ?? ''),
      ],
    );
  }

  Widget _buildSectionHeader(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildPinnedMessages(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: GroupService().getPinnedMessage(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No pinned messages.'),
            ),
          );
        }
        final data = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📌 “${data['content']}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Posted by ${data['sender']} • ${_formatRelativeTime(data['created_at'])}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper for relative time
  String _formatRelativeTime(String isoString) {
    final date = DateTime.parse(isoString).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 1) return '${diff.inDays} day${diff.inDays > 1 ? "s" : ""} ago';
    if (diff.inHours >= 1) return '${diff.inHours} hour${diff.inHours > 1 ? "s" : ""} ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} minute${diff.inMinutes > 1 ? "s" : ""} ago';
    return 'Just now';
  }

  Widget _buildGroupEvents(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: GroupService().getGroupEvents(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          );
        }
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column (
              children: [const Text('No upcoming events.'),
                if (widget.isAdmin)
                  TextButton.icon(
                    label: const Text('Create An Event'),
                    onPressed: () => context.push('/groups/${widget.groupId}/events'),
                  ),])
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...events.map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          event['title'] ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatEventDate(event['event_date']),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/groups/${widget.groupId}/events'),
                      child: const Text('View All Events'),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper for formatting event date
  String _formatEventDate(dynamic isoString) {
    if (isoString == null) return '';
    final date = DateTime.parse(isoString).toLocal();
    // e.g., Jul 14, 2025  7:00 PM
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, "0")}';
  }

  Widget _buildGroupAnnouncements(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: GroupService().getGroupAnnouncements(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          );
        }
        final announcements = snapshot.data ?? [];
        if (announcements.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column (
              children: [const Text('No Announcements Yet.'),
                if (widget.isAdmin)
                  TextButton.icon(
                    label: const Text('Create An Announcement'),
                    onPressed: () => context.push('/groups/${widget.groupId}/announcements'),
                  ),])
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...announcements.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (a['image_url'] != null && (a['image_url'] as String).isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(a['image_url'], height: 100, fit: BoxFit.cover),
                        ),
                      if (a['title'] != null)
                        Text(
                          a['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      if (a['body'] != null && (a['body'] as String).trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            a['body'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        _formatAnnouncementDate(a['published_at'] ?? a['created_at']),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/groups/${widget.groupId}/announcements'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper for formatting announcement date
  String _formatAnnouncementDate(dynamic isoString) {
    if (isoString == null) return '';
    final date = DateTime.parse(isoString).toLocal();
    return '${date.month}/${date.day}/${date.year}';
  }


  Widget _buildGroupMedia(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: GroupService().getRecentGroupMedia(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          );
        }
        final images = snapshot.data ?? [];
        if (images.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No recent group media.'),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...images.map((img) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            img['file_url'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/groups/${widget.groupId}/media'),
                      child: const Text('View All'),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildGroupMembers(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: GroupService().getGroupMembers(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          );
        }
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No members in this group.'),
            ),
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...members.map((member) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(member['display_name'], style: Theme.of(context).textTheme.bodyMedium),
                      Text(member['role'], style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                )),
                if (widget.isAdmin)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openInviteModal,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Invite Member'),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/groups/${widget.groupId}/members'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  /// Opens modal to pick new group photo: camera, gallery, or file
  Future<void> _changeGroupPhoto(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
                  if (picked != null) {
                    File file = File(picked.path);
                    file = await _compressImage(file);
                    await _uploadAndSetPhoto(file);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pick from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
                  if (picked != null) {
                    File file = File(picked.path);
                    file = await _compressImage(file);
                    await _uploadAndSetPhoto(file);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Pick File'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(type: FileType.image);
                  if (result != null && result.files.single.path != null) {
                    File file = File(result.files.single.path!);
                    file = await _compressImage(file);
                    await _uploadAndSetPhoto(file);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Uploads image to Supabase Storage and updates DB
  Future<void> _uploadAndSetPhoto(File file) async {
    setState(() => isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fileExt = file.path.split('.').last;
      final fileName = 'group_photos/${widget.groupId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final backendEndpoint = 'https://vhzcbqgehlpemdkvmzvy.supabase.co/functions/v1/generate-presigned-url';

      final res = await http.post(
        Uri.parse(backendEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'filename': fileName, 'contentType': 'image/$fileExt'}),
      );

      if (res.statusCode != 200) throw 'Could not get presigned URL';
      final presigned = jsonDecode(res.body);
      final uploadUrl = presigned['url'] as String;
      final publicUrl = presigned['publicUrl'] as String;

      final uploadRes = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': 'image/$fileExt',
        },
        body: file.readAsBytesSync(),
      );
      if (uploadRes.statusCode != 200) throw 'Failed to upload to S3';

      await GroupService().updateGroup(
        groupId: widget.groupId,
        photoUrl: publicUrl,
      );
      await _loadGroup();
      messenger.showSnackBar(const SnackBar(content: Text('Group photo updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
    }
    setState(() => isLoading = false);
  }
}
