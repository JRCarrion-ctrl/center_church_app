// File: lib/features/home/announcements_section.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/routes/router_observer.dart';

class AnnouncementsSection extends StatefulWidget {
  const AnnouncementsSection({super.key});

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends State<AnnouncementsSection> with RouteAware {
  // ... (State variables remain unchanged)
  GraphQLClient? _gql;
  String? _userId;

  List<Map<String, dynamic>> mainAnnouncements = [];
  List<Map<String, dynamic>> groupAnnouncements = [];
  bool loading = true;
  bool isAdmin = false;
  // ...

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    _gql ??= GraphQLProvider.of(context).value;
    _userId ??= context.read<AppState>().profile?.id;

    _loadData();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  Future<void> _loadData() async {
    final client = _gql;
    if (client == null) return;

    setState(() => loading = true);
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    String? role;
    List<String> groupIds = [];

    try {
      // Global announcements (published_at <= now)
      const qGlobal = r'''
        query GlobalAnnouncements($now: timestamptz!) {
          app_announcements(
            where: { published_at: { _lte: $now } }
            order_by: { published_at: desc }
          ) {
            id
            title
            body
            image_url
            published_at
          }
        }
      ''';
      final globalRes = await client.query(
        QueryOptions(
          document: gql(qGlobal),
          variables: {'now': nowUtc},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (globalRes.hasException) throw globalRes.exception!;
      final globalRows =
          (globalRes.data?['app_announcements'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

      // If logged in, get role & memberships → group announcements
      if (_userId != null) {
        const qProfileAndMemberships = r'''
          query ProfileAndMemberships($uid: String!) {
            profiles_by_pk(id: $uid) { role }
            group_memberships(
              where: { user_id: { _eq: $uid }, status: { _eq: "approved" } }
            ) { group_id }
          }
        ''';

        final pmRes = await client.query(
          QueryOptions(
            document: gql(qProfileAndMemberships),
            variables: {'uid': _userId},
            fetchPolicy: FetchPolicy.networkOnly,
          ),
        );
        if (pmRes.hasException) throw pmRes.exception!;

        role = pmRes.data?['profiles_by_pk']?['role'] as String?;
        final memberships = (pmRes.data?['group_memberships'] as List<dynamic>? ?? []);
        groupIds = memberships
            .map((e) => e as Map<String, dynamic>) // Cast to Map
            .where((e) => e.containsKey('group_id') && e['group_id'] is String) // Filter for valid keys and types
            .map((e) => e['group_id'] as String) // Safely map to String
            .toList();

        // Group announcements (published_at <= now, for the user’s groups)
        List<Map<String, dynamic>> groups = [];
        if (groupIds.isNotEmpty) {
          // ✅ CHANGED: Added 'group { name }' to query
          const qGroupAnnouncements = r'''
            query GroupAnnouncements($groupIds: [uuid!]!, $now: timestamptz!) {
              group_announcements(
                where: { group_id: { _in: $groupIds }, published_at: { _lte: $now } }
                order_by: { published_at: desc }
              ) {
                id
                group_id
                title
                body
                image_url
                published_at
                group { name }
              }
            }
          ''';
          final groupsRes = await client.query(
            QueryOptions(
              document: gql(qGroupAnnouncements),
              variables: {'groupIds': groupIds, 'now': nowUtc},
              fetchPolicy: FetchPolicy.networkOnly,
            ),
          );
          if (groupsRes.hasException) throw groupsRes.exception!;
          groups = (groupsRes.data?['group_announcements'] as List<dynamic>? ?? []) 
              .cast<Map<String, dynamic>>();
        }

        if (mounted) {
          setState(() {
            isAdmin = role == 'supervisor' || role == 'owner';
            mainAnnouncements = List<Map<String, dynamic>>.from(globalRows);
            groupAnnouncements = groups;
            loading = false;
          });
        }
      } else {
        // not logged in → only global announcements
        if (mounted) {
          setState(() {
            isAdmin = false;
            mainAnnouncements = List<Map<String, dynamic>>.from(globalRows);
            groupAnnouncements = const [];
            loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  void _showAnnouncementDialog(
    BuildContext context, 
    Map<String, dynamic> a, 
    TextTheme textTheme
  ) {
    final imageUrl = a['image_url'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    // ✅ EXTRACT GROUP NAME
    final groupName = a['group']?['name'] as String?;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER IMAGE IN DIALOG
              if (hasImage)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator.adaptive()),
                    ),
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ SHOW GROUP NAME IN DIALOG
                    if (groupName != null) ...[
                      Chip(
                        label: Text(
                          groupName,
                          style: TextStyle(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: colorScheme.secondaryContainer,
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(height: 8),
                    ],

                    Text((a['title'] ?? '') as String, style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(a['published_at'] as String),
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      child: Text((a['body'] ?? '') as String, style: textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text("key_178".tr()), // Close
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final showGroupAnnouncements = appState.showGroupAnnouncements;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final hasMain = mainAnnouncements.isNotEmpty;
    final hasGroup = groupAnnouncements.isNotEmpty;

    if (loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    // === REFACTOR: Use Center and ConstrainedBox to match ChurchInfoCard's max width ===
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface, // White background
            border: Border.all(
              color: colorScheme.outlineVariant, // Subtle outline color
              width: 1.0,
            ),
            // Apply rounded corners to match the ChurchInfoCard style
            borderRadius: BorderRadius.circular(16), 
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- HEADER BLOCK (Announcements Title + Manage Button) ---
                _buildHeader(context),
                
                const SizedBox(height: 8),

                // --- EMPTY STATE ---
                if (!hasMain && !hasGroup)
                  _buildEmptyState(context),

                // --- GLOBAL ANNOUNCEMENTS LIST ---
                if (hasMain)
                  _buildAnnouncementList(
                    context: context,
                    announcements: mainAnnouncements,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),

                // --- GROUP ANNOUNCEMENTS ---
                if (showGroupAnnouncements && hasGroup) ...[
                  const SizedBox(height: 24),
                    
                  // Group Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "key_175b".tr(), // Group Announcements
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Horizontal list
                  Padding(
                    padding: const EdgeInsets.only(left: 16), // Padding on left for starting item
                    child: _buildGroupList(textTheme, colorScheme),
                  ),
                  const SizedBox(height: 8), // Extra space at the bottom of the container
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 36, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            "key_175".tr(), // No current announcements
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_userId == null) ...[
            const SizedBox(height: 8),
            Text(
              "key_175a".tr(), // Log in to see group announcements
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isAdmin ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
            children: [
              Text(
                "key_112c".tr(), // Announcements
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
              if (isAdmin)
                TextButton.icon(
                  onPressed: () => GoRouter.of(context).push('/manage-app-announcements'),
                  icon: const Icon(Icons.edit_note_outlined, size: 20),
                  label: Text("key_177".tr()), // Manage Announcements
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementList({
    required BuildContext context,
    required List<Map<String, dynamic>> announcements,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Horizontal padding removed to allow content to stretch up to the 16.0 margin of the list item
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0), 
      itemCount: announcements.length,
      separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1),
      itemBuilder: (context, index) {
        final a = announcements[index];
        return _buildAnnouncementListItem(a, textTheme, colorScheme, context);
      },
    );
  }

  Widget _buildAnnouncementListItem(
    Map<String, dynamic> a,
    TextTheme textTheme,
    ColorScheme colorScheme,
    BuildContext context,
  ) {
    final hasBody = (a['body'] ?? '') is String && (a['body'] as String).isNotEmpty;
    final imageUrl = a['image_url'] as String?;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return InkWell(
      onTap: () => _showAnnouncementDialog(context, a, textTheme),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE
            Text(
              (a['title'] ?? '') as String,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // IMAGE (Cached)
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 160,
                      color: colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // BODY
            if (hasBody)
              Text(
                a['body'] as String,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),

            // FOOTER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(a['published_at'] as String),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "key_read_more".tr(),
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupList(TextTheme textTheme, ColorScheme colorScheme) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groupAnnouncements.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final a = groupAnnouncements[index];
          final imageUrl = a['image_url'] as String?;
          final hasImage = imageUrl != null && imageUrl.isNotEmpty;
          // ✅ EXTRACT GROUP NAME
          final groupName = a['group']?['name'] as String?;

          return SizedBox(
            width: 280,
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => _showAnnouncementDialog(context, a, textTheme),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE OR ICON HEADER
                    if (hasImage)
                      SizedBox(
                        height: 100,
                        width: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image_outlined, color: colorScheme.outline),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Icon(Icons.groups_2_outlined, color: colorScheme.tertiary, size: 28),
                      ),

                    // CONTENT
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ DISPLAY GROUP NAME
                            if (groupName != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  groupName.toUpperCase(),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.tertiary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                            Text(
                              (a['title'] ?? '') as String,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDate(a['published_at'] as String),
                                  style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                                ),
                                if (!hasImage)
                                  Text(
                                    "key_read_more".tr(),
                                    style: textTheme.labelLarge?.copyWith(
                                        color: colorScheme.tertiary, fontWeight: FontWeight.bold),
                                  )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return '${"Today".tr()} ${DateFormat.jm().format(dateTime)}';
      } else if (difference.inDays == 1) {
        return '${"Yesterday".tr()} ${DateFormat.jm().format(dateTime)}';
      }
      return DateFormat('MMM d, yyyy').format(dateTime);
    } catch (_) {
      return '';
    }
  }
}