// File: lib/features/nursery/pages/nursery_staff_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
          .filter('check_out_time', 'is', null)
          .order('check_in_time', ascending: false);

      setState(() => checkins = List<Map<String, dynamic>>.from(result));
    } catch (e) {
      debugPrint('Failed to load check-ins: $e');
      setState(() => error = 'Failed to load check-ins');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkOut(String checkinId) async {
    try {
      final response = await supabase
          .from('child_checkins')
          .update({'check_out_time': DateTime.now().toIso8601String()})
          .eq('id', checkinId);

      if (response.isEmpty) {
        _showSnackbar('Check-out failed — not permitted or already checked out.');
        return;
      }

      _showSnackbar('Child checked out.');
      _loadCheckins();
    } catch (e) {
      debugPrint('Check-out error: $e');
      _showSnackbar('An error occurred while checking out.');
    }
  }

  Future<void> _openOrCreateChat(Map<String, dynamic> checkin) async {
    final checkinId = checkin['id'];
    final childId = checkin['child']?['id'];
    if (checkinId == null || childId == null) {
      _showSnackbar('Missing check-in or child ID.');
      return;
    }

    try {
      // Step 1: Try to find an existing group
      final existing = await supabase
          .from('nursery_temp_groups')
          .select('group_id')
          .eq('checkin_id', checkinId)
          .maybeSingle();

      if (existing != null && existing['group_id'] != null && mounted) {
        context.push('/groups/${existing['group_id']}');
        return;
      }

      // Step 2: Create the group via RPC if none exists
      final response = await supabase
          .rpc('create_nursery_temp_group', params: {
            'p_checkin_id': checkinId,
            'p_child_id': childId,
          })
          .select()
          .maybeSingle();

      final groupId = response?['create_nursery_temp_group'];
      if (groupId != null && mounted) {
        context.push('/groups/$groupId');
      } else {
        _showSnackbar('Could not open group chat.');
      }
    } catch (e) {
      debugPrint('Open/Create nursery group error: $e');
      _showSnackbar('Failed to create or open chat.');
    }
  }


  void _viewChildProfile(Map<String, dynamic> child) {
    context.push('/nursery/child-profile', extra: child);
  }

  String _formatCheckinTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return isoString;
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildCheckinTile(Map<String, dynamic> item) {
    final child = item['child'];
    final checkInTime = _formatCheckinTime(item['check_in_time']);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: child['photo_url'] != null ? NetworkImage(child['photo_url']) : null,
        child: child['photo_url'] == null ? const Icon(Icons.child_care) : null,
      ),
      title: Text(child['display_name'] ?? 'Unnamed'),
      subtitle: Text('Checked in at: $checkInTime'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => _openOrCreateChat(item),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _checkOut(item['id']),
          ),
        ],
      ),
      onTap: () => _viewChildProfile(child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/more')),
        title: const Text('Nursery Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.push('/nursery/qr_checkin'),
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
                    itemBuilder: (context, index) => _buildCheckinTile(checkins[index]),
                  ),
                ),
    );
  }
}
