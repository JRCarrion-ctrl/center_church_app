// File: lib/features/groups/pages/group_info_page.dart
import 'dart:io';
import 'package:ccf_app/app_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../core/graph_provider.dart';
import '../group_service.dart';
import '../models/group.dart';
import '../widgets/invite_user_modal.dart';

Future<File> _compressImage(File file) async {
  final targetPath = file.path.replaceFirst(
    RegExp(r'\.(jpg|jpeg|png|heic|webp)$', caseSensitive: false),
    '_compressed.jpg',
  );
  final compressedBytes = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: 600,
    minHeight: 600,
    quality: 80,
    format: CompressFormat.jpeg,
  );
  if (compressedBytes == null) return file;
  return File(targetPath)..writeAsBytesSync(compressedBytes);
}

class GroupInfoPage extends StatefulWidget {
  final String groupId;
  final bool isAdmin;
  final bool isOwner;

  const GroupInfoPage({
    super.key,
    required this.groupId,
    required this.isAdmin,
    required this.isOwner,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  Group? group;
  bool _isPageLoading = true;
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _descController;
  GroupService? _groups;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_groups == null) {
      final client = GraphProvider.of(context);
      _groups = GroupService(client);
      _loadGroup();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    setState(() => _isPageLoading = true);
    try {
      group = await _groups!.getGroupById(widget.groupId);
      if (group != null) {
        _nameController.text = group!.name;
        _descController.text = group!.description ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load group info: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPageLoading = false);
      }
    }
  }

  void _openInviteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => InviteUserModal(groupId: widget.groupId),
    );
  }

  Future<void> _leaveGroup() async {
    final uid = context.read<AppState>().profile?.id;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("key_078".tr()),
        content: Text("key_079".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("key_080".tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("key_081".tr())),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _groups!.leaveGroup(groupId: widget.groupId, userId: uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_082".tr())));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      context.go('/groups');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave group: $e')),
      );
    }
  }

  Future<void> _saveGroupEdits() async {
    setState(() => _isPageLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _groups!.updateGroup(
        groupId: widget.groupId,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
      );
      await _loadGroup(); // Re-fetch to ensure UI is in sync
      setState(() => _isEditing = false);
      messenger.showSnackBar(SnackBar(content: Text("key_084".tr())));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) setState(() => _isPageLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPageLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (group == null) {
      return Scaffold(body: Center(child: Text("key_086".tr())));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("key_087".tr()),
        actions: [
          if (widget.isAdmin && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveGroupEdits,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadGroup,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGroupHeader(context),
            const SizedBox(height: 24),
            _buildSectionHeader("key_112a".tr()),
            _buildPinnedMessages(context),
            const SizedBox(height: 24),
            _buildSectionHeader("key_112b".tr()),
            _buildGroupEvents(context),
            const SizedBox(height: 24),
            _buildSectionHeader("key_112c".tr()),
            _buildGroupAnnouncements(context),
            const SizedBox(height: 24),
            _buildSectionHeader("key_112d".tr()),
            _buildGroupMedia(context),
            const SizedBox(height: 24),
            _buildSectionHeader("key_112e".tr()),
            _buildGroupMembers(context),
            if (!widget.isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: TextButton.icon(
                  onPressed: _leaveGroup,
                  icon: const Icon(Icons.exit_to_app),
                  label: Text("key_088".tr()),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            if (widget.isOwner)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text("key_089".tr()),
                        content: Text("key_090".tr()),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("key_091".tr())),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("key_092".tr())),
                        ],
                      ),
                    );
                    if (confirmed != true) return;

                    try {
                      await _groups!.deleteGroup(widget.groupId);
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text("key_093".tr())));
                      if (context.mounted) context.go('/groups');
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text('Failed to delete group: $e')));
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: Text("key_095".tr()),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: widget.isAdmin ? () => _changeGroupPhoto(context) : null,
          child: CircleAvatar(
            radius: 80,
            child: (group?.photoUrl?.isNotEmpty ?? false)
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: group!.photoUrl!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      errorWidget: (context, url, error) => const Icon(Icons.error, size: 40),
                    ),
                  )
                : const Icon(Icons.group, size: 80),
          ),
        ),
        const SizedBox(height: 12),
        if (_isEditing && widget.isAdmin)
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: "key_068a".tr()),
          )
        else
          Text(group?.name ?? '', style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        if (_isEditing && widget.isAdmin)
          TextFormField(
            controller: _descController,
            maxLines: 2,
            decoration: InputDecoration(labelText: "key_068c".tr()),
          )
        else
          Text(group?.description ?? ''),
      ],
    );
  }

  Widget _buildSectionHeader(String title) =>
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildPinnedMessages(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _groups!.getPinnedMessage(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Text("key_096".tr())));
        }
        final data = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📌 “${data['content']}”', maxLines: 2, overflow: TextOverflow.ellipsis),
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
      future: _groups!.getGroupEvents(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()));
        }
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text("key_097".tr()),
                if (widget.isAdmin)
                  TextButton.icon(
                    label: Text("key_098".tr()),
                    onPressed: () => context.push('/groups/${widget.groupId}/events'),
                    icon: const Icon(Icons.event),
                  ),
              ]),
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
                      child: Text("key_099".tr()),
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

  String _formatEventDate(dynamic isoString) {
    if (isoString == null) return '';
    final date = DateTime.parse(isoString).toLocal();
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, "0")}';
  }

  Widget _buildGroupAnnouncements(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _groups!.getGroupAnnouncements(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()));
        }
        final announcements = snapshot.data ?? [];
        if (announcements.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text("key_100".tr()),
                if (widget.isAdmin)
                  TextButton.icon(
                    label: Text("key_101".tr()),
                    onPressed: () => context.push('/groups/${widget.groupId}/announcements'),
                    icon: const Icon(Icons.campaign),
                  ),
              ]),
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
                            Text(a['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (a['body'] != null && (a['body'] as String).trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(a['body'], maxLines: 2, overflow: TextOverflow.ellipsis),
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
                      child: Text("key_102".tr()),
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

  String _formatAnnouncementDate(dynamic isoString) {
    if (isoString == null) return '';
    final date = DateTime.parse(isoString).toLocal();
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildGroupMedia(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _groups!.getRecentGroupMedia(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()));
        }
        final images = snapshot.data ?? [];
        if (images.isEmpty) {
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Text("key_103".tr())));
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
                      child: Text("key_104".tr()),
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
      future: _groups!.getGroupMembers(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(child: Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()));
        }
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Text("key_105".tr())));
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
                          Text(
                            member['role'],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    )),
                if (widget.isAdmin)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openInviteModal,
                      icon: const Icon(Icons.person_add),
                      label: Text("key_106".tr()),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/groups/${widget.groupId}/members'),
                      child: Text("key_107".tr()),
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

  Future<({String uploadUrl, String finalUrl})> _presignViaHasura({
    required GraphQLClient client,
    required String objectKey,
    required String contentType,
  }) async {
    const q = r'''
      query Presign($path: String!, $contentType: String!) {
        get_presigned_upload(path: $path, contentType: $contentType) {
          uploadUrl
          finalUrl
          expiresAt
        }
      }
    ''';
    final res = await client.query(
      QueryOptions(
        document: gql(q),
        fetchPolicy: FetchPolicy.noCache,
        variables: {'path': objectKey, 'contentType': contentType},
      ),
    );
    if (res.hasException) {
      throw res.exception!;
    }
    final data = res.data?['get_presigned_upload'];
    if (data == null || data['uploadUrl'] == null || data['finalUrl'] == null) {
      throw Exception('Invalid presign response');
    }
    return (uploadUrl: data['uploadUrl'] as String, finalUrl: data['finalUrl'] as String);
  }

  Future<void> _changeGroupPhoto(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text("key_108".tr()),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
                  if (picked != null) {
                    final file = await _compressImage(File(picked.path));
                    await _uploadAndSetPhoto(file);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text("key_109".tr()),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
                  if (picked != null) {
                    final file = await _compressImage(File(picked.path));
                    await _uploadAndSetPhoto(file);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text("key_110".tr()),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(type: FileType.image);
                  if (result != null && result.files.single.path != null) {
                    final file = await _compressImage(File(result.files.single.path!));
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

  Future<void> _uploadAndSetPhoto(File file) async {
    setState(() => _isPageLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final normalizedExt = (ext == 'jpg') ? 'jpeg' : ext;
      final contentType = 'image/$normalizedExt';
      final objectKey = 'group_photos/${widget.groupId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final client = GraphProvider.of(context);
      final presigned = await _presignViaHasura(
        client: client,
        objectKey: objectKey,
        contentType: contentType,
      );

      final bytes = await file.readAsBytes();
      final uploadRes = await http.put(
        Uri.parse(presigned.uploadUrl),
        headers: {'Content-Type': contentType},
        body: bytes,
      );

      if (uploadRes.statusCode < 200 || uploadRes.statusCode >= 300) {
        throw Exception('Failed to upload (${uploadRes.statusCode})');
      }

      await _groups!.updateGroup(
        groupId: widget.groupId,
        photoUrl: presigned.finalUrl,
      );

      await _loadGroup();
      messenger.showSnackBar(SnackBar(content: Text("key_111".tr())));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("key_112".tr())));
    } finally {
      if (mounted) setState(() => _isPageLoading = false);
    }
  }
}