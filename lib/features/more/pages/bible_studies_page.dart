// File: lib/features/more/pages/bible_studies_page.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';

class BibleStudiesPage extends StatefulWidget {
  const BibleStudiesPage({super.key});

  @override
  State<BibleStudiesPage> createState() => _BibleStudiesPageState();
}

class _BibleStudiesPageState extends State<BibleStudiesPage> {
  List<Map<String, dynamic>> studies = [];
  Map<String, String> accessStatus = {};
  String userRole = 'member';
  bool isLoading = true;
  // Flag to ensure _loadPage is only run once on initial dependency change
  bool _isDataLoaded = false; 

  @override
  void initState() {
    super.initState();
    // initState is now clean and only calls super.
  }

  // --- START REFACTOR CHANGE ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This is the correct place to access inherited widgets (like GraphQLProvider)
    // and initiate data loading logic that depends on the context.
    if (!_isDataLoaded) {
      _loadPage();
      _isDataLoaded = true;
    }
  }
  // --- END REFACTOR CHANGE ---

  Future<void> _loadPage() async {
    // The context is now guaranteed to be safe for inherited widget lookups
    // when this async function is first called from didChangeDependencies.
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    // We already set isLoading = true in the initial state, 
    // but good practice to reset if calling this again (e.g., after an action)
    if (!isLoading) setState(() => isLoading = true); 

    // Accessing the InheritedWidget (GraphQLProvider) is now safe!
    final client = GraphQLProvider.of(context).value;

    // One round-trip: role + all studies + my access statuses
    const q = r'''
      query LoadBibleStudies($uid: String!) {
        profiles_by_pk(id: $uid) { role }
        bible_studies(order_by: {date: desc}) {
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

    try {
      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'uid': userId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        debugPrint('LoadBibleStudies error: ${res.exception}');
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final role = (res.data?['profiles_by_pk']?['role'] as String?) ?? 'member';

      final rows = (res.data?['bible_studies'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final accessRows = (res.data?['bible_study_access_requests'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      final statusMap = {
        for (final r in accessRows)
          r['bible_study_id'] as String: (r['status'] as String?) ?? 'pending'
      };

      if (!mounted) return;
      setState(() {
        userRole = role;
        studies = rows;
        accessStatus = statusMap;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('LoadBibleStudies exception: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _submitAccessRequest(String studyId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text("key_240".tr()),
          content: TextField(controller: controller, maxLines: 3),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("key_241".tr())),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text("key_242".tr()),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    // Access is safe here as this is called by an event handler long after initState
    final client = GraphQLProvider.of(context).value;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;

    const m = r'''
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

    try {
      final res = await client.mutate(
        MutationOptions(
          document: gql(m),
          variables: {'studyId': studyId, 'uid': userId, 'reason': reason},
        ),
      );
      if (res.hasException) {
        debugPrint('RequestAccess error: ${res.exception}');
      }

      // Reloading data after the mutation
      // We set _isDataLoaded to false temporarily so _loadPage can run
      _isDataLoaded = false; 
      await _loadPage();
      _isDataLoaded = true; // Set back to true after load

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_243".tr())),
      );
    } catch (e) {
      debugPrint('RequestAccess exception: $e');
    }
  }

  // (downloadAndCacheFile and openNotes are unchanged and context-independent)
  Future<File?> downloadAndCacheFile(String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filename = url.split('/').last;
      final filePath = '${dir.path}/$filename';
      final file = File(filePath);

      if (await file.exists()) {
        return file; // Use cached
      }

      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final savedFile = await file.writeAsBytes(response.data!);
      return savedFile;
    } catch (_) {
      return null;
    }
  }

  void openNotes(String url) async {
    final file = await downloadAndCacheFile(url);
    if (file != null) {
      await OpenFilex.open(file.path);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_244".tr())),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final canCreate = userRole == 'owner' || userRole == 'group_admin';

    return Scaffold(
      appBar: AppBar(
        title: Text("key_245".tr()),
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.pushNamed('edit_bible_study'),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: studies.length,
              itemBuilder: (context, index) {
                final study = studies[index];
                final dateIso = study['date'] as String;
                final formattedDate = DateFormat('MMM d, yyyy').format(DateTime.parse(dateIso));

                final status = accessStatus[study['id'] as String];
                // Access is granted if status is 'approved' or if user is an 'admin' or 'owner'
                final hasAccess = status == 'approved' || userRole == 'admin' || userRole == 'owner';

                final youtubeUrl = (study['youtube_url'] as String?) ?? '';
                final notesUrl = (study['notes_url'] as String?) ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(study['title'] as String),
                    subtitle: Text(formattedDate),
                    trailing: hasAccess
                        ? Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  if (youtubeUrl.isNotEmpty) {
                                    final u = Uri.tryParse(youtubeUrl);
                                    if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: Text("key_246".tr()), // "Watch"
                              ),
                              if (notesUrl.isNotEmpty)
                                TextButton(
                                  // Navigating to a separate notes viewer page
                                  onPressed: () => context.push('/more/study/notes_viewer', extra: notesUrl),
                                  child: Text("key_247".tr()), // "Notes"
                                ),
                              if (canCreate)
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit Study',
                                  onPressed: () => context.pushNamed('edit_bible_study', extra: study),
                                ),
                            ],
                          )
                        : status == 'pending'
                            ? Text("key_249".tr(), style: const TextStyle(color: Colors.orange)) // "Pending"
                            : TextButton(
                                onPressed: () => _submitAccessRequest(study['id'] as String),
                                child: Text("key_248".tr()), // "Request Access"
                              ),
                  ),
                );
              },
            ),
    );
  }
}