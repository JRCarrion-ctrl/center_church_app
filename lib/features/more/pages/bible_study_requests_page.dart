// File: lib/features/more/pages/bible_study_requests_page.dart
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';

class BibleStudyRequestsPage extends StatefulWidget {
  const BibleStudyRequestsPage({super.key});

  @override
  State<BibleStudyRequestsPage> createState() => _BibleStudyRequestsPageState();
}

class _BibleStudyRequestsPageState extends State<BibleStudyRequestsPage> {
  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;
  String? error;
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Call _loadRequests() only on the very first time
    if (!_didInitialLoad) {
      _loadRequests();
      _didInitialLoad = true;
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final client = GraphQLProvider.of(context).value;

    // Assumes object relationships:
    //   bible_study_access_requests.user -> profiles (by user_id)
    //   bible_study_access_requests.study -> bible_studies (by bible_study_id)
    const q = r'''
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

    try {
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (res.hasException) {
        setState(() {
          error = 'Failed to load requests';
          isLoading = false;
        });
        return;
      }

      final rows =
          (res.data?['bible_study_access_requests'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

      setState(() {
        requests = rows;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        error = 'Failed to load requests';
        isLoading = false;
      });
    }
  }

  Future<void> _respondToRequest(String id, bool approve) async {
    final client = GraphQLProvider.of(context).value;
    final reviewerId = context.read<AppState>().profile?.id;
    if (reviewerId == null) return;

    const m = r'''
      mutation RespondToRequest($id: uuid!, $status: String!, $reviewedBy: String!) {
        update_bible_study_access_requests_by_pk(
          pk_columns: {id: $id},
          _set: { status: $status, reviewed_by: $reviewedBy }
        ) { id }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(
          document: gql(m),
          variables: {
            'id': id,
            'status': approve ? 'approved' : 'denied',
            'reviewedBy': reviewerId,
          },
        ),
      );
      if (res.hasException) {
        // Soft-fail and show a toast
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${res.exception}')),
        );
        return;
      }

      await _loadRequests();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_249".tr())),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : requests.isEmpty
                  ? Center(child: Text("key_250".tr()))
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final req = requests[index];
                          final user = req['user'] as Map<String, dynamic>?;
                          final study = req['study'] as Map<String, dynamic>?;
                          final status = (req['status'] as String?) ?? 'pending';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text('${user?['display_name'] ?? 'Unknown'} → ${study?['title'] ?? 'Untitled'}'),
                              trailing: status == 'pending'
                                  ? Wrap(
                                      spacing: 8,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.check, color: Colors.green),
                                          onPressed: () => _respondToRequest(req['id'] as String, true),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.red),
                                          onPressed: () => _respondToRequest(req['id'] as String, false),
                                        ),
                                      ],
                                    )
                                  : Chip(
                                      label: Text(status),
                                      backgroundColor: status == 'approved'
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
