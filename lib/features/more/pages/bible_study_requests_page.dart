import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class BibleStudyRequestsPage extends StatefulWidget {
  const BibleStudyRequestsPage({super.key});

  @override
  State<BibleStudyRequestsPage> createState() => _BibleStudyRequestsPageState();
}

class _BibleStudyRequestsPageState extends State<BibleStudyRequestsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> requests = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await supabase
          .from('bible_study_access_requests')
          .select('*, user:profiles!bible_study_access_requests_user_id_fkey(display_name), study:bible_studies!bible_study_access_requests_bible_study_id_fkey(title)')
          .order('created_at', ascending: false);

      setState(() {
        requests = List<Map<String, dynamic>>.from(result);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load requests';
        isLoading = false;
      });
    }
  }

  Future<void> _respondToRequest(String id, bool approve) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('bible_study_access_requests').update({
      'status': approve ? 'approved' : 'denied',
      'reviewed_by': userId,
    }).eq('id', id);

    _loadRequests();

    if (!context.mounted) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(approve ? "key_249a".tr() : "key_249b".tr()),
    ));
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
                  : ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final req = requests[index];
                        final user = req['user'];
                        final study = req['study'];
                        final status = req['status'];

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
                                        onPressed: () => _respondToRequest(req['id'], true),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        onPressed: () => _respondToRequest(req['id'], false),
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
    );
  }
}
