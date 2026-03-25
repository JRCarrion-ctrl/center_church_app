// File: lib/features/more/pages/bible_studies_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/core/widgets/ccf_query.dart';

const String _getStudiesQuery = r'''
  query LoadBibleStudies($uid: String!, $langs: [String!]!) {
    profiles_by_pk(id: $uid) { role }
    bible_studies(
      where: { target_audiences: { _contained_in: $langs } },
      order_by: {date: desc}
    ) {
      id
      title
      date
      youtube_url
      notes_url
    }
    bible_study_access_requests(where: {user_id: {_eq: $uid}}) {
      bible_study_id
      status
    }
  }
''';

const String _requestAccessMutation = r'''
  mutation RequestAccess($studyId: uuid!, $uid: String!, $reason: String) {
    insert_bible_study_access_requests_one(object: {
      bible_study_id: $studyId,
      user_id: $uid,
      reason: $reason
    }) {
      id
    }
  }
''';

class BibleStudiesPage extends StatelessWidget {
  const BibleStudiesPage({super.key});

  Future<void> _submitAccessRequest(
    BuildContext context, 
    String studyId, 
    String userId, 
    VoidCallback refetch
  ) async {
    final reasonController = TextEditingController();
    
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("key_240".tr()),
        content: TextField(
          controller: reasonController, 
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Why would you like to join?",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("key_241".tr())),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: Text("key_242".tr()),
          ),
        ],
      ),
    );

    if (reason == null || !context.mounted) return;

    final client = GraphQLProvider.of(context).value;

    try {
      final res = await client.mutate(
        MutationOptions(
          document: gql(_requestAccessMutation),
          variables: {'studyId': studyId, 'uid': userId, 'reason': reason},
        ),
      );
      
      if (res.hasException) {
        debugPrint('RequestAccess error: ${res.exception}');
        return;
      }

      // Automatically refresh the Query widget!
      refetch();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_243".tr())),
      );
    } catch (e) {
      debugPrint('RequestAccess exception: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>(); // Access AppState
    final userId = appState.profile?.id;
    final userLangs = appState.databaseServiceFilter; // Get the language filter

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text("key_245".tr())),
        body: const Center(child: Text("User not logged in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("key_245".tr()),
      ),
      body: CCFQuery(
        options: QueryOptions(
          document: gql(_getStudiesQuery),
          variables: {
            'uid': userId,
            'langs': userLangs, // Pass the languages to Hasura
          },
          fetchPolicy: FetchPolicy.networkOnly,
        ),
        onData: (data, refetch) {
          
          // 2. Parse Data directly (no isLoading checks needed!)
          final role = (data['profiles_by_pk']?['role'] as String?) ?? 'member';
          final canCreate = role == 'owner' || role == 'group_admin';
          
          final studies = (data['bible_studies'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final accessRows = (data['bible_study_access_requests'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          
          final accessStatus = {
            for (final r in accessRows)
              r['bible_study_id'] as String: (r['status'] as String?) ?? 'pending'
          };

          // 3. Use a nested transparent Scaffold to inject the FAB!
          return Scaffold(
            backgroundColor: Colors.transparent, // Ensures it matches your app theme
            
            // ✨ Moved the "Add" button here! It only renders if they have permission.
            floatingActionButton: canCreate 
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/more/study/edit'), // Path-based navigation
                  icon: const Icon(Icons.add),
                  label: const Text("New Study"),
                )
              : null,
                
            body: studies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book, size: 64, color: theme.disabledColor),
                        const SizedBox(height: 16),
                        Text("No Bible studies available.", style: TextStyle(color: theme.disabledColor)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => refetch(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 80), // Added bottom padding so the FAB doesn't block the last card
                      itemCount: studies.length,
                      itemBuilder: (context, index) {
                        final study = studies[index];
                        final studyId = study['id'] as String;
                        final title = study['title'] as String;
                        
                        final dateIso = study['date'] as String;
                        final formattedDate = DateFormat('MMM d, yyyy').format(DateTime.parse(dateIso));

                        final status = accessStatus[studyId];
                        final hasAccess = status == 'approved' || role == 'admin' || role == 'owner';

                        final youtubeUrl = (study['youtube_url'] as String?) ?? '';
                        final notesUrl = (study['notes_url'] as String?) ?? '';

                        return Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(formattedDate, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                                        ],
                                      ),
                                    ),
                                    if (canCreate)
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Edit Study',
                                        onPressed: () => context.push('/more/study/edit?studyId=${study['id']}'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                OverflowBar(
                                  spacing: 8,
                                  alignment: MainAxisAlignment.end,
                                  children: [
                                    if (hasAccess) ...[
                                      if (notesUrl.isNotEmpty)
                                        TextButton.icon(
                                          icon: const Icon(Icons.description_outlined, size: 18),
                                          label: Text("key_247".tr()),
                                          onPressed: () => context.push('/more/study/notes_viewer?url=${Uri.encodeComponent(notesUrl)}'),
                                        ),
                                      if (youtubeUrl.isNotEmpty)
                                        FilledButton.icon(
                                          icon: const Icon(Icons.play_circle_outline, size: 18),
                                          label: Text("key_246".tr()),
                                          onPressed: () async {
                                            final u = Uri.tryParse(youtubeUrl);
                                            if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
                                          },
                                        ),
                                    ] else if (status == 'pending') ...[
                                      Chip(
                                        avatar: const Icon(Icons.schedule, size: 16),
                                        label: Text("key_249".tr()),
                                        backgroundColor: Colors.orange.shade100,
                                        side: BorderSide.none,
                                      )
                                    ] else ...[
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.lock_outline, size: 18),
                                        label: Text("key_248".tr()),
                                        onPressed: () => _submitAccessRequest(context, studyId, userId, refetch),
                                      )
                                    ]
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          );
        },
      ),
    );
  }
}