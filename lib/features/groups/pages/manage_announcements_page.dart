// File: lib/features/groups/pages/manage_announcements_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/core/time_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

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
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => context.pop(),
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
              order_by: { published_at: desc }
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
              order_by: { published_at: desc }
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
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      // 1. Make the modal background transparent so the blur shows through
      backgroundColor: Colors.transparent, 
      // 2. Make the dimming effect very subtle
      barrierColor: Colors.black.withValues(alpha: 0.2), 
      builder: (context) => BackdropFilter(
        // 3. This blurs the content ALREADY on the screen (the list behind the form)
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnnouncementFormModal(
          groupId: widget.groupId,
          existing: existing,
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("key_126".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text("key_127".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("key_128".tr())),
          FilledButton(
            onPressed: () => Navigator.pop(context, true), 
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text("key_129".tr()),
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'all', label: Text("key_130".tr())),
            ButtonSegment(value: 'published', label: Text("key_131".tr())),
            ButtonSegment(value: 'scheduled', label: Text("key_132".tr())),
          ],
          selected: {filter},
          onSelectionChanged: (v) => setState(() => filter = v.first),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementTile(GroupAnnouncement a) {
    final isExpanded = _expandedAnnouncementId == a.id;
    final isPublished = a.publishedAt?.isBefore(_nowUtc) ?? false;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasImage = a.imageUrl != null && a.imageUrl!.isNotEmpty;
    final hasBody = a.body != null && a.body!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      child: ClipRRect( // ✨ 2. Clip the blur to the card's border radius
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter( // ✨ 3. Add the frosting effect
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              // ✨ 4. Ensure these colors stay semi-transparent (alpha < 1.0)
              color: isDark 
                ? Colors.black.withValues(alpha: 0.2) 
                : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), 
                width: 1.5
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _expandedAnnouncementId = isExpanded ? null : a.id;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Header Row ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and Badges
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (a.publishedAt != null)
                                  Row(
                                    children: [
                                      // Dynamic Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPublished ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isPublished ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          isPublished ? "key_131".tr().toUpperCase() : "key_132".tr().toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isPublished ? Colors.green[700] : Colors.orange[700],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        TimeService.formatUtcToLocal(a.publishedAt!, pattern: 'MMM d, y'),
                                        style: TextStyle(fontSize: 12, color: colorScheme.outline),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          // Expand/Collapse Icon
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: colorScheme.outline,
                          ),
                        ],
                      ),
                      
                      // --- Body Preview (Collapsed) ---
                      if (hasBody && !isExpanded) ...[
                        const SizedBox(height: 12),
                        Text(
                          a.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],

                      // --- Expanded Content ---
                      if (isExpanded) ...[
                        const SizedBox(height: 16),
                        if (hasImage)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PhotoViewPage(imageUrl: a.imageUrl!),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16.0),
                                child: CachedNetworkImage(
                                  imageUrl: a.imageUrl!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 150,
                                    color: colorScheme.surfaceContainerHighest,
                                    child: const Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 150,
                                    color: colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (hasBody)
                          SelectableLinkify(
                            text: a.body!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                            linkStyle: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            onOpen: (link) async {
                              final Uri url = Uri.parse(link.url);
                              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Error opening link")),
                                  );
                                }
                              }
                            },
                          ),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(height: 1),
                        ),
                        
                        // --- Footer Row (Author & Admin Actions) ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (a.createdByName != null)
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 14, color: colorScheme.outline),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'By ${a.createdByName!}', 
                                        style: TextStyle(fontSize: 12, color: colorScheme.outline),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_canManage)
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    icon: const Icon(Icons.edit, size: 18),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                    onPressed: () => _openForm(existing: a),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(8),
                                    onPressed: () => _confirmAndDelete(a.id),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = filteredAnnouncements;
    final canPop = GoRouter.of(context).canPop();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_canManage ? "key_133".tr() : "key_131".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: canPop
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/'),
              ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : RefreshIndicator(
              onRefresh: () async => _bootstrap(),
              child: Column(
                children: [
                  _buildFilterButtons(),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.campaign_outlined, size: 48, color: colorScheme.outline),
                                const SizedBox(height: 16),
                                Text("key_134".tr(), style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                          )
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