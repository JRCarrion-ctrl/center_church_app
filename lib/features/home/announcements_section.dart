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
  GraphQLClient? _gql;
  String? _userId;

  List<Map<String, dynamic>> mainAnnouncements = [];
  List<Map<String, dynamic>> groupAnnouncements = [];
  bool loading = true;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    // actual loading is triggered after inherited widgets are available
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    // init GraphQL + user id once
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
          groups = (groupsRes.data?['announcements'] as List<dynamic>? ?? [])
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

    final hasMain = mainAnnouncements.isNotEmpty;
    final hasGroup = groupAnnouncements.isNotEmpty;

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            if (!hasMain && !hasGroup)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text("key_175".tr()),
                    if (_userId == null)
                      Text(
                        "key_175a".tr(),
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            if (hasMain)
              ...mainAnnouncements.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildAnnouncementCard(a),
                ),
              ),
            if (showGroupAnnouncements && hasGroup) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "key_175b".tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () => GoRouter.of(context).push('/group-announcements'),
                    child: Text("key_176".tr()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildGroupList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "key_112c".tr(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (isAdmin)
          TextButton(
            onPressed: () => GoRouter.of(context).push('/manage-app-announcements'),
            child: Text("key_177".tr()),
          ),
      ],
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> a) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          (a['title'] ?? '') as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if ((a['body'] ?? '') is String && (a['body'] as String).isNotEmpty)
            Text(a['body'] as String),
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    return Center(
      child: SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: groupAnnouncements.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final a = groupAnnouncements[index];
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final backgroundColor = isDark ? Colors.blueGrey[900] : Colors.blue[50];

            return Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showDialog(
                      context: context,
                      useRootNavigator: false,
                      builder: (dialogContext) => AlertDialog(
                        title: Text((a['title'] ?? '') as String),
                        content: Text((a['body'] ?? '') as String),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text("key_178".tr()),
                          ),
                        ],
                      ),
                    );
                  });
                },
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (a['title'] ?? '') as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      if ((a['body'] ?? '') is String && (a['body'] as String).isNotEmpty)
                        Text(
                          a['body'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
