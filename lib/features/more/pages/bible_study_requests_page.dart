// File: lib/features/more/pages/bible_study_requests_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/widgets/ccf_query.dart';

const String _getRequestsQuery = r'''
  query ListBibleStudyRequests {
    bible_study_access_requests(order_by: {created_at: desc}) {
      id
      status
      created_at
      reason
      user_id
      reviewed_by
      user { display_name }
      study { title }
    }
  }
''';

const String _respondMutation = r'''
  mutation RespondToRequest($id: uuid!, $status: String!, $reviewedBy: String!) {
    update_bible_study_access_requests_by_pk(
      pk_columns: {id: $id},
      _set: { status: $status, reviewed_by: $reviewedBy }
    ) { id }
  }
''';

// Transitioned back to StatefulWidget to hold the Search query
class BibleStudyRequestsPage extends StatefulWidget {
  const BibleStudyRequestsPage({super.key});

  @override
  State<BibleStudyRequestsPage> createState() => _BibleStudyRequestsPageState();
}

class _BibleStudyRequestsPageState extends State<BibleStudyRequestsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _respondToRequest(String id, bool approve, VoidCallback refetch) async {
    final client = GraphQLProvider.of(context).value;
    final reviewerId = context.read<AppState>().profile?.id;
    if (reviewerId == null) return;

    try {
      final res = await client.mutate(
        MutationOptions(
          document: gql(_respondMutation),
          variables: {
            'id': id,
            'status': approve ? 'approved' : 'denied',
            'reviewedBy': reviewerId,
          },
        ),
      );

      if (res.hasException) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${res.exception}')),
        );
        return;
      }

      refetch(); 

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? "key_249a".tr() : "key_249b".tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  void _showContextMenu(BuildContext context, LongPressStartDetails details, Map<String, dynamic> req, VoidCallback refetch) async {
    final status = req['status'] as String? ?? 'pending';
    final id = req['id'] as String;

    // Get the exact coordinates of the user's finger/mouse
    final offset = details.globalPosition;

    // Show the menu and wait for a selection
    final selectedValue = await showMenu<bool>(
      context: context,
      // Position the menu exactly where the press occurred
      position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx, offset.dy),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      items: [
        PopupMenuItem(
          value: true,
          enabled: status != 'approved',
          child: Row(
            children: [
              Icon(Icons.check_circle, color: status != 'approved' ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              const Text('Change to Approved'),
            ],
          ),
        ),
        PopupMenuItem(
          value: false,
          enabled: status != 'denied',
          child: Row(
            children: [
              Icon(Icons.cancel, color: status != 'denied' ? Colors.red : Colors.grey),
              const SizedBox(width: 8),
              const Text('Change to Denied'),
            ],
          ),
        ),
      ],
    );

    // If they tapped an option (and didn't just tap away to dismiss), run the mutation
    if (selectedValue != null) {
      _respondToRequest(id, selectedValue, refetch);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("key_249".tr()),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Pending"),
              Tab(text: "Reviewed"),
            ],
          ),
        ),
        body: CCFQuery(
          options: QueryOptions(
            document: gql(_getRequestsQuery),
            fetchPolicy: FetchPolicy.networkOnly,
          ),
          onData: (data, refetch) {
            
            // 1. Instantly parse your data (no loading/error checks!)
            final rows = (data['bible_study_access_requests'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();

            // 2. Filter rows globally based on the search query
            final filteredRows = rows.where((r) {
              if (_searchQuery.isEmpty) return true;
              final user = r['user'] as Map<String, dynamic>?;
              final name = (user?['display_name'] as String? ?? '').toLowerCase();
              return name.contains(_searchQuery.toLowerCase());
            }).toList();

            final pendingRows = filteredRows.where((r) => r['status'] == 'pending' || r['status'] == null).toList();
            final reviewedRows = filteredRows.where((r) => r['status'] == 'approved' || r['status'] == 'denied').toList();

            return Column(
              children: [
                // 3. Global Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search by name...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ) 
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                
                // 4. The Tabs Content
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildGroupedList(pendingRows, refetch, isReviewedTab: false),
                      _buildGroupedList(reviewedRows, refetch, isReviewedTab: true),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupedList(List<Map<String, dynamic>> requests, VoidCallback refetch, {required bool isReviewedTab}) {
    final theme = Theme.of(context);

    if (requests.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? "No users found matching '$_searchQuery'." : "key_250".tr(),
          style: TextStyle(color: theme.disabledColor, fontSize: 16),
        ),
      );
    }

    final Map<String, List<Map<String, dynamic>>> groupedRequests = {};
    for (final req in requests) {
      final study = req['study'] as Map<String, dynamic>?;
      final studyTitle = study?['title'] as String? ?? 'Other/Unknown';
      groupedRequests.putIfAbsent(studyTitle, () => []).add(req);
    }

    return RefreshIndicator(
      onRefresh: () async => refetch(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: groupedRequests.length + (isReviewedTab ? 1 : 0),
        itemBuilder: (context, index) {
          
          // ✨ Added: A small hint at the top of the "Reviewed" tab
          if (isReviewedTab && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Center(
                child: Text(
                  "Long-press a request to change its status",
                  style: TextStyle(fontSize: 12, color: theme.disabledColor, fontStyle: FontStyle.italic),
                ),
              ),
            );
          }

          final actualIndex = isReviewedTab ? index - 1 : index;
          final studyTitle = groupedRequests.keys.elementAt(actualIndex);
          final studyRequests = groupedRequests[studyTitle]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  studyTitle, 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary, letterSpacing: 1.2),
                ).tr(),
              ),
              ...studyRequests.map((req) => _buildRequestCard(req, refetch)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, VoidCallback refetch) {
    final theme = Theme.of(context);
    final user = req['user'] as Map<String, dynamic>?;
    
    final status = (req['status'] as String?) ?? 'pending';
    final userName = user?['display_name'] as String? ?? 'Unknown';
    final reason = req['reason'] as String?;
    
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: GestureDetector(
        // ✨ This captures the exact X/Y coordinates of the press
        onLongPressStart: status != 'pending' 
            ? (details) => _showContextMenu(context, details, req, refetch) 
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: reason != null && reason.trim().isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '"$reason"', 
                      style: TextStyle(fontStyle: FontStyle.italic, color: theme.textTheme.bodySmall?.color),
                    ),
                  )
                : null,
            trailing: status == 'pending'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: Colors.red.shade400,
                        style: IconButton.styleFrom(backgroundColor: Colors.red.shade50),
                        onPressed: () => _respondToRequest(req['id'] as String, false, refetch),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.check),
                        color: Colors.green.shade600,
                        style: IconButton.styleFrom(backgroundColor: Colors.green.shade50),
                        onPressed: () => _respondToRequest(req['id'] as String, true, refetch),
                      ),
                    ],
                  )
                : Chip(
                    label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    backgroundColor: status == 'approved' ? Colors.green.shade100 : Colors.red.shade100,
                    side: BorderSide.none,
                  ),
          ),
        ),
      ),
    );
  }
}