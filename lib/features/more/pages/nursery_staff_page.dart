// File: lib/features/nursery/pages/nursery_staff_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NurseryStaffPage extends StatefulWidget {
  const NurseryStaffPage({super.key});

  @override
  State<NurseryStaffPage> createState() => _NurseryStaffPageState();
}

class _NurseryStaffPageState extends State<NurseryStaffPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> checkins = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCheckins();
  }

  Future<void> _loadCheckins() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await supabase
          .from('child_checkins')
          .select('*, child:child_profiles(*)')
          .filter('checked_out_at', 'is', null)
          .order('checked_in_at', ascending: false);

      setState(() => checkins = List<Map<String, dynamic>>.from(result));
    } catch (e) {
      setState(() => error = 'Failed to load check-ins');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkOut(String checkinId) async {
    await supabase
        .from('child_checkins')
        .update({'checked_out_at': DateTime.now().toIso8601String()})
        .eq('id', checkinId);
    _loadCheckins();
  }

  Future<void> _openOrCreateChat(Map<String, dynamic> checkin) async {
    final checkinId = checkin['id'];
    final childId = checkin['child']?['id'];
    if (checkinId == null || childId == null) return;

    final response = await supabase
        .rpc('get_or_create_nursery_chat', params: {
          'checkin_id': checkinId,
          'child_id': childId,
        })
        .select()
        .maybeSingle();

    final chatId = response?['id'];
    if (chatId != null && mounted) {
      context.push('/nursery/chat/$chatId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nursery Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              context.push('/nursery/qr_checkin');
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : RefreshIndicator(
                  onRefresh: _loadCheckins,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: checkins.length,
                    itemBuilder: (context, index) {
                      final item = checkins[index];
                      final child = item['child'];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: child['photo_url'] != null
                              ? NetworkImage(child['photo_url'])
                              : null,
                          child: child['photo_url'] == null
                              ? const Icon(Icons.child_care)
                              : null,
                        ),
                        title: Text(child['display_name'] ?? 'Unnamed'),
                        subtitle: Text('Checked in at: ${item['checked_in_at']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          onPressed: () => _checkOut(item['id']),
                        ),
                        onTap: () => _openOrCreateChat(item),
                      );
                    },
                  ),
                ),
    );
  }
}
