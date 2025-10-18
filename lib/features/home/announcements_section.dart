// File: lib/features/home/announcements_section.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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

  // ... (_loadData method remains unchanged)
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
    BuildContext context
  ) {
    final hasBody = (a['body'] ?? '') is String && (a['body'] as String).isNotEmpty;

    return InkWell(
      onTap: () {
        // Show full content dialog
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text((a['title'] ?? '') as String, style: textTheme.titleLarge),
            content: SingleChildScrollView(
              child: Text((a['body'] ?? '') as String, style: textTheme.bodyLarge),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text("key_178".tr()), // Close
              ),
            ],
          ),
        );
      },
      child: Padding(
        // Apply the standard horizontal margin here
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE (Bold, primary color)
            Text(
              (a['title'] ?? '') as String,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary, 
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // SUBTITLE (Body/Excerpt)
            if (hasBody)
              Text(
                a['body'] as String,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2, 
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // PUBLISHED DATE (Subtle label)
                Text(
                  _formatDate(a['published_at'] as String),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                // Read More Text Link
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
      height: 180, 
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groupAnnouncements.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final a = groupAnnouncements[index];
          
          return SizedBox(
            // Card width increased for better visibility
            width: 280, 
            child: Card(
              elevation: 0, 
              color: colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Show the full announcement content in a modern dialog
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text((a['title'] ?? '') as String, style: textTheme.titleLarge),
                      content: SingleChildScrollView(
                        child: Text((a['body'] ?? '') as String, style: textTheme.bodyLarge),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text("key_178".tr()), // Close
                        ),
                      ],
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.groups_2_outlined, color: colorScheme.tertiary, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        (a['title'] ?? '') as String,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(a['published_at'] as String),
                        style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                      ),
                      const Spacer(),
                      Text(
                        "key_read_more".tr(), 
                        style: textTheme.labelLarge?.copyWith(color: colorScheme.tertiary, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
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