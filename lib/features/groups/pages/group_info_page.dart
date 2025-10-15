// File: lib/features/groups/pages/group_info_page.dart
import 'dart:io';
import 'package:ccf_app/app_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  late Future<GroupInfoData> _pageDataFuture;
  late final GroupService _groupService;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      final client = GraphProvider.of(context);
      _groupService = GroupService(client);
      _pageDataFuture = _groupService.getGroupInfoData(widget.groupId);
    }
  }

  Future<void> _refreshData() {
    setState(() {
      _pageDataFuture = _groupService.getGroupInfoData(widget.groupId);
    });
    return _pageDataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GroupInfoData>(
      future: _pageDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("key_086".tr()),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _refreshData, child: Text("Retry".tr())),
                ],
              ),
            ),
          );
        }

        final pageData = snapshot.data!;
        return _GroupInfoView(
          key: ValueKey(widget.groupId),
          pageData: pageData,
          isAdmin: widget.isAdmin,
          isOwner: widget.isOwner,
          onDataChange: _refreshData,
        );
      },
    );
  }
}

class _GroupInfoView extends StatefulWidget {
  final GroupInfoData pageData;
  final bool isAdmin;
  final bool isOwner;
  final Future<void> Function() onDataChange;

  const _GroupInfoView({
    super.key,
    required this.pageData,
    required this.isAdmin,
    required this.isOwner,
    required this.onDataChange,
  });

  @override
  State<_GroupInfoView> createState() => _GroupInfoViewState();
}

class _GroupInfoViewState extends State<_GroupInfoView> {
  bool _isEditing = false;
  bool _isSaving = false;
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final GroupService _groupService;
  bool _isInitialized = false; // Flag to ensure one-time initialization

  // ✅ FIX: Initialization moved from initState to here.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _groupService = GroupService(GraphProvider.of(context));
    }
  }

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Service initialization is removed from here.
    _nameController = TextEditingController(text: widget.pageData.group.name);
    _descController = TextEditingController(text: widget.pageData.group.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveGroupEdits() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _groupService.updateGroup(
        groupId: widget.pageData.group.id,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
      );
      await widget.onDataChange();
      if (mounted) setState(() => _isEditing = false);
      messenger.showSnackBar(SnackBar(content: Text("key_084".tr())));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openInviteModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => InviteUserModal(groupId: widget.pageData.group.id),
    );
  }

  Future<void> _leaveGroup() async {
    final uid = context.read<AppState>().profile?.id;
    if (uid == null) return;

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
      await _groupService.leaveGroup(groupId: widget.pageData.group.id, userId: uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_082".tr())));
      context.go('/groups');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to leave group: $e')),
      );
    }
  }

  Future<void> _deleteGroup() async {
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
      await _groupService.deleteGroup(widget.pageData.group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_093".tr())));
      context.go('/groups');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete group: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
              onPressed: _isSaving ? null : _saveGroupEdits,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onDataChange,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GroupHeader(
              group: widget.pageData.group,
              isAdmin: widget.isAdmin,
              onPhotoChanged: widget.onDataChange,
            ),
            const SizedBox(height: 12),
            _buildEditableGroupInfo(),
            const SizedBox(height: 24),
            _SectionCard(title: "key_112a".tr(), child: _buildPinnedMessages(widget.pageData.pinnedMessage)),
            const SizedBox(height: 24),
            _SectionCard(title: "key_112b".tr(), child: _buildGroupEvents(widget.pageData.events)),
            const SizedBox(height: 24),
            _SectionCard(title: "key_112c".tr(), child: _buildGroupAnnouncements(widget.pageData.announcements)),
            const SizedBox(height: 24),
            _SectionCard(title: "key_112d".tr(), child: _buildGroupMedia(widget.pageData.media)),
            const SizedBox(height: 24),
            _SectionCard(title: "key_112e".tr(), child: _buildGroupMembers(widget.pageData.memberships)),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableGroupInfo() {
    return Column(
      children: [
        if (_isEditing)
          TextFormField(
            controller: _nameController,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(labelText: "key_068a".tr(), border: const UnderlineInputBorder()),
          )
        else
          Text(widget.pageData.group.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_isEditing)
          TextFormField(
            controller: _descController,
            maxLines: null,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(labelText: "key_068c".tr(), border: const UnderlineInputBorder()),
          )
        else
          Text(widget.pageData.group.description ?? '', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildPinnedMessages(Map<String, dynamic>? message) {
    if (message == null) return Text("key_096".tr());
    final sender = message['sender']?['display_name'] ?? 'Someone';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📌 “${message['content']}”', maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(
          'Posted by $sender • ${message['created_at']}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildGroupEvents(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      return Column(
        children: [
          Text("key_097".tr()),
          if (widget.isAdmin)
            TextButton.icon(
              label: Text("key_098".tr()),
              onPressed: () => context.push('/groups/${widget.pageData.group.id}/events'),
              icon: const Icon(Icons.event),
            ),
        ],
      );
    }
    return Column(
      children: [
        ...events.map((event) => Text(event['title'] ?? '')),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/groups/${widget.pageData.group.id}/events'),
            child: Text("See All".tr()),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupAnnouncements(List<Map<String, dynamic>> announcements) {
    if (announcements.isEmpty) {
      return Column(
        children: [
          Text("key_100".tr()),
          if (widget.isAdmin)
            TextButton.icon(
              label: Text("key_101".tr()),
              onPressed: () => context.push('/groups/${widget.pageData.group.id}/announcements'),
              icon: const Icon(Icons.campaign),
            ),
        ],
      );
    }
    return Column(
      children: [
        ...announcements.map((a) => Text(a['title'] ?? '')),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/groups/${widget.pageData.group.id}/announcements'),
            child: Text("See All".tr()),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupMedia(List<Map<String, dynamic>> media) {
    // Filter out messages that don't have a file URL or aren't easily previewable as images
    final imageMedia = media.where((msg) {
      final fileUrl = msg['file_url'] as String?;
      if (fileUrl == null) return false;
      // Simple check for common image extensions (adjust as needed for your backend)
      final ext = fileUrl.split('?').first.split('.').last.toLowerCase();
      return const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(ext);
    }).toList();

    if (imageMedia.isEmpty) {
      return Column(
        children: [
          Text("key_102".tr()), // e.g., "No media has been shared yet."
        ],
      );
    }

    final displayMedia = imageMedia.take(6).toList();

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: displayMedia.length,
          itemBuilder: (context, index) {
            final fileUrl = displayMedia[index]['file_url'] as String;

            return GestureDetector(
              onTap: () {
                // TODO: Implement a function to view the full image/media
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Viewing media is coming soon!')),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: CachedNetworkImage(
                  imageUrl: fileUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 40),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/groups/${widget.pageData.group.id}/media'),
            child: Text("key_104".tr()), // e.g., "See All Media"
          ),
        ),
      ],
    );
  }

  Widget _buildGroupMembers(List<Map<String, dynamic>> members) {
    if (members.isEmpty) return Text("key_105".tr());
    return Column(
      children: [
        ...members.map((member) => Text(member['display_name'] ?? 'Unknown')),
        if (widget.isAdmin || widget.isOwner)
          TextButton.icon(
            onPressed: _openInviteModal,
            icon: const Icon(Icons.person_add),
            label: Text("key_106".tr()),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/groups/${widget.pageData.group.id}/members'),
            child: Text("key_107".tr()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (!widget.isAdmin)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: TextButton.icon(
              onPressed: _leaveGroup,
              icon: const Icon(Icons.exit_to_app),
              label: Text("key_088".tr()),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ),
        if (widget.isOwner)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: _deleteGroup,
              icon: const Icon(Icons.delete),
              label: Text("key_095".tr()),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _GroupHeader extends StatefulWidget {
  final Group group;
  final bool isAdmin;
  final VoidCallback onPhotoChanged;

  const _GroupHeader({required this.group, required this.isAdmin, required this.onPhotoChanged});

  @override
  State<_GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<_GroupHeader> {
  bool _isUploading = false;

  Future<void> _uploadAndSetPhoto(File file) async {
    final messenger = ScaffoldMessenger.of(context);
    final groupService = GroupService(GraphProvider.of(context));

    setState(() => _isUploading = true);
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final contentType = 'image/${(ext == 'jpg') ? 'jpeg' : ext}';
      final objectKey = 'group_photos/${widget.group.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      final client = GraphProvider.of(context);
      final presigned = await _presignViaHasura(client, objectKey, contentType);

      final uploadRes = await http.put(
        Uri.parse(presigned.uploadUrl),
        headers: {'Content-Type': contentType},
        body: await file.readAsBytes(),
      );

      if (uploadRes.statusCode >= 300) throw Exception('Upload failed with status code ${uploadRes.statusCode}');

      await groupService.updateGroup(groupId: widget.group.id, photoUrl: presigned.finalUrl);
      
      widget.onPhotoChanged();
      messenger.showSnackBar(SnackBar(content: Text("key_111".tr())));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<({String uploadUrl, String finalUrl})> _presignViaHasura(GraphQLClient client, String objectKey, String contentType) async {
    const q = r'''
      query Presign($path: String!, $contentType: String!) {
        get_presigned_upload(path: $path, contentType: $contentType) {
          uploadUrl
          finalUrl
        }
      }
    ''';
    final res = await client.query(QueryOptions(document: gql(q), variables: {'path': objectKey, 'contentType': contentType}));
    if (res.hasException) throw res.exception!;
    
    final data = res.data?['get_presigned_upload'];
    if (data == null || data['uploadUrl'] == null || data['finalUrl'] == null) {
      throw Exception('Invalid presign response from server');
    }
    return (
      uploadUrl: data['uploadUrl'] as String,
      finalUrl: data['finalUrl'] as String,
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text("key_108".tr()),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                if (picked != null) {
                  final compressed = await _compressImage(File(picked.path));
                  await _uploadAndSetPhoto(compressed);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text("key_109".tr()),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (picked != null) {
                   final compressed = await _compressImage(File(picked.path));
                  await _uploadAndSetPhoto(compressed);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isAdmin && !_isUploading ? _showImagePicker : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 80,
            backgroundImage: (widget.group.photoUrl?.isNotEmpty ?? false)
                ? CachedNetworkImageProvider(widget.group.photoUrl!)
                : null,
            child: (widget.group.photoUrl?.isEmpty ?? true)
                ? const Icon(Icons.group, size: 80)
                : null,
          ),
          if (_isUploading) const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}