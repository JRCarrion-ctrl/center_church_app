import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

class BibleStudiesPage extends StatefulWidget {
  const BibleStudiesPage({super.key});

  @override
  State<BibleStudiesPage> createState() => _BibleStudiesPageState();
}

class _BibleStudiesPageState extends State<BibleStudiesPage> {
  final supabase = Supabase.instance.client;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> studies = [];
  Map<String, String> accessStatus = {};
  String userRole = 'member';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => isLoading = true);

    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    final role = profile?['role'] ?? 'member';

    final result = await supabase
        .from('bible_studies')
        .select('*')
        .order('date', ascending: false);

    final access = await supabase
        .from('bible_study_access_requests')
        .select('bible_study_id, status')
        .eq('user_id', userId);

    final statusMap = {
      for (var row in access) row['bible_study_id'] as String: row['status'] as String
    };

    setState(() {
      userRole = role;
      studies = List<Map<String, dynamic>>.from(result);
      accessStatus = statusMap;
      isLoading = false;
    });
  }

  Future<void> _submitAccessRequest(String studyId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text("key_240".tr()),
          content: TextField(
            controller: controller,
            maxLines: 3,
          ),
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

    if (reason == null || reason.isEmpty) return;

    await supabase.from('bible_study_access_requests').insert({
      'bible_study_id': studyId,
      'user_id': userId,
      'reason': reason,
    });

    _loadPage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("key_243".tr())),
    );
  }

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
    } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text("key_245".tr()),
        actions: [
          if (userRole == 'owner')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                context.pushNamed('edit_bible_study');
              },
            )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: studies.length,
              itemBuilder: (context, index) {
                final study = studies[index];
                final formattedDate =
                    DateFormat('MMM d, yyyy').format(DateTime.parse(study['date']));
                final status = accessStatus[study['id']];
                final hasAccess = status == 'approved' || userRole == 'admin';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(study['title']),
                    subtitle: Text(formattedDate),
                    trailing: hasAccess
                        ? Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () {
                                  final url = study['youtube_url'];
                                  if (url != null && url.isNotEmpty) {
                                    launchUrl(Uri.parse(url));
                                  }
                                },
                                child: Text("key_246".tr()),
                              ),
                              if (study['notes_url'] != null &&
                                  study['notes_url'].toString().isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    final url = study['notes_url'];
                                    if (url != null && url.isNotEmpty) {
                                      context.push('/notes_viewer', extra: url);
                                    }
                                  },
                                  child: Text("key_247".tr()),
                                ),
                              if (userRole == 'owner')
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit Study',
                                  onPressed: () {
                                    context.pushNamed('edit_bible_study', extra: study);
                                  },
                                ),
                            ],
                          )
                        : status == 'pending'
                            ? const Text('Pending', style: TextStyle(color: Colors.orange))
                            : TextButton(
                                onPressed: () => _submitAccessRequest(study['id']),
                                child: Text("key_248".tr()),
                              ),
                  ),
                );
              },
            ),
    );
  }
}
