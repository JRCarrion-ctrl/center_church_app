// File: lib/features/groups/pages/manage_announcements_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/graph_provider.dart';
import '../../../app_state.dart';
import '../models/group_announcement.dart';
import '../widgets/announcement_form_modal.dart';

// New widget to display the full-screen photo
class PhotoViewPage extends StatelessWidget {
  final String imageUrl;

  const PhotoViewPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white, size: 50),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ManageAnnouncementsPage extends StatefulWidget {
  final String groupId;

  const ManageAnnouncementsPage({super.key, required this.groupId});

  @override
  State<ManageAnnouncementsPage> createState() => _ManageAnnouncementsPageState();
}

class _ManageAnnouncementsPageState extends State<ManageAnnouncementsPage> {
  late GraphQLClient _gql;

  List<GroupAnnouncement> allAnnouncements = [];
  bool loading = true;
  String? _expandedAnnouncementId;

  bool _canManage = false;
  String filter = 'all';

  DateTime get _nowUtc => DateTime.now().toUtc();
  bool _inited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    _gql = GraphProvider.of(context);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => loading = true);
    try {
      await _loadPermissions();
      await _loadAnnouncements();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadPermissions() async {
    final uid = context.read<AppState>().profile?.id;
    if (uid == null || uid.isEmpty) {
      _canManage = false;
      return;
    }

    const q = r'''
      query MemberRole($gid: uuid!, $uid: String!) {
        group_memberships(
          where: { group_id: { _eq: $gid }, user_id: { _eq: $uid } }
          limit: 1
        ) { role }
      }
    ''';

    final res = await _gql.query(QueryOptions(
      document: gql(q),
      fetchPolicy: FetchPolicy.noCache,
      variables: {'gid': widget.groupId, 'uid': uid},
    ));
    if (res.hasException) {
      _canManage = false;
      return;
    }
    final rows = (res.data?['group_memberships'] as List?) ?? const [];
    final role = rows.isEmpty ? 'member' : (rows.first['role'] as String? ?? 'member');
    _canManage = const {'admin', 'leader', 'supervisor', 'owner'}.contains(role);
  }

  Future<void> _loadAnnouncements() async {
    setState(() => loading = true);
    try {
      if (_canManage) {
        const q = r'''
          query AnnAll($gid: uuid!) {
            group_announcements(
              where: { group_id: { _eq: $gid } }
              order_by: { published_at: asc }
            ) {
              id
              group_id
              title
              body
              image_url
              published_at
              created_at
              created_by
              profile { display_name }
            }
          }
        ''';
        final res = await _gql.query(QueryOptions(
          document: gql(q),
          fetchPolicy: FetchPolicy.noCache,
          variables: {'gid': widget.groupId},
        ));
        if (res.hasException) throw res.exception!;
        final list = ((res.data?['group_announcements'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(GroupAnnouncement.fromMap)
            .toList();
        allAnnouncements = list;
      } else {
        const q = r'''
          query AnnPublished($gid: uuid!, $now: timestamptz!) {
            group_announcements(
              where: {
                group_id: { _eq: $gid },
                published_at: { _lte: $now }
              }
              order_by: { published_at: asc }
            ) {
              id
              group_id
              title
              body
              image_url
              published_at
              created_at
              created_by
              profile { display_name }
            }
          }
        ''';
        final res = await _gql.query(QueryOptions(
          document: gql(q),
          fetchPolicy: FetchPolicy.noCache,
          variables: {'gid': widget.groupId, 'now': _nowUtc.toIso8601String()},
        ));
        if (res.hasException) throw res.exception!;
        final list = ((res.data?['group_announcements'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(GroupAnnouncement.fromMap)
            .toList();
        allAnnouncements = list;
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_125".tr())),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _openForm({GroupAnnouncement? existing}) async {
    if (!_canManage) return;
    final result = await showModalBottomSheet<GroupAnnouncement>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AnnouncementFormModal(
        groupId: widget.groupId,
        existing: existing,
      ),
    );

    if (result != null) {
      setState(() => loading = true);
      await _loadAnnouncements();
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _confirmAndDelete(String id) async {
    if (!_canManage) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_126".tr()),
        content: Text("key_127".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("key_128".tr())),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("key_129".tr())),
        ],
      ),
    );

    if (confirmed == true) {
      const m = r'''
        mutation DeleteAnn($id: uuid!) {
          delete_group_announcements_by_pk(id: $id) { id }
        }
      ''';
      try {
        final res = await _gql.mutate(MutationOptions(
          document: gql(m),
          variables: {'id': id},
        ));
        if (res.hasException) throw res.exception!;
        setState(() => loading = true);
        await _loadAnnouncements();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_125".tr())),
        );
      } finally {
        if (mounted) setState(() => loading = false);
      }
    }
  }

  List<GroupAnnouncement> get filteredAnnouncements {
    if (!_canManage) return allAnnouncements;
    return allAnnouncements.where((a) {
      if (filter == 'published') {
        return a.publishedAt != null && a.publishedAt!.isBefore(_nowUtc);
      } else if (filter == 'scheduled') {
        return a.publishedAt != null && a.publishedAt!.isAfter(_nowUtc);
      }
      return true;
    }).toList();
  }

  Widget _buildFilterButtons() {
    if (!_canManage) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment(value: 'all', label: Text("key_130".tr())),
          ButtonSegment(value: 'published', label: Text("key_131".tr())),
          ButtonSegment(value: 'scheduled', label: Text("key_132".tr())),
        ],
        selected: {filter},
        onSelectionChanged: (v) => setState(() => filter = v.first),
        showSelectedIcon: false,
      ),
    );
  }

  Widget _buildAnnouncementTile(GroupAnnouncement a) {
    final isExpanded = _expandedAnnouncementId == a.id;
    final isPublished = a.publishedAt?.isBefore(_nowUtc) ?? false;

    final adminStatus = a.publishedAt != null
        ? Text(
            '${isPublished ? "key_131".tr() : "key_132".tr()}: ${TimeService.formatUtcToLocal(a.publishedAt!, pattern: 'MMM d, y')}',
            style: TextStyle(fontSize: 12, color: isPublished ? Colors.green[700] : Colors.orange[700]),
          )
        : null;

    final createdBy = a.createdByName != null
        ? Text('Posted by ${a.createdByName!}', style: const TextStyle(fontSize: 12, color: Colors.grey))
        : null;

    final hasImage = a.imageUrl != null && a.imageUrl!.isNotEmpty;
    final hasBody = a.body != null && a.body!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(a.title, maxLines: isExpanded ? null : 1, overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasBody && !isExpanded)
                  Text(a.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (_canManage) ...[
                  if (adminStatus != null) adminStatus,
                  if (createdBy != null) createdBy,
                ] else ...[
                  if (a.publishedAt != null)
                    Text(
                      '${"key_131".tr()}: ${TimeService.formatUtcToLocal(a.publishedAt!, pattern: 'MMM d, y')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (createdBy != null) createdBy,
                ],
              ],
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedAnnouncementId = null;
                } else {
                  _expandedAnnouncementId = a.id;
                }
              });
            },
            trailing: _canManage
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openForm(existing: a),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmAndDelete(a.id),
                      ),
                    ],
                  )
                : (isExpanded ? const Icon(Icons.expand_less) : const Icon(Icons.expand_more)),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    GestureDetector( // Added GestureDetector to the image
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PhotoViewPage(imageUrl: a.imageUrl!),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: CachedNetworkImage(
                            imageUrl: a.imageUrl!,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ),
                  if (hasBody)
                    Text(a.body!),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = filteredAnnouncements;

    return Scaffold(
      appBar: AppBar(
        title: Text(_canManage ? "key_133".tr() : "key_131".tr()),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _bootstrap(),
              child: Column(
                children: [
                  _buildFilterButtons(),
                  Expanded(
                    child: list.isEmpty
                        ? Center(child: Text("key_134".tr()))
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: list.length,
                            itemBuilder: (context, i) => _buildAnnouncementTile(list[i]),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text("key_135".tr()),
            )
          : null,
    );
  }
}