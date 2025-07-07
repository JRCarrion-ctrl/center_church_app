import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class GroupDeletionRequestsPage extends StatefulWidget {
  const GroupDeletionRequestsPage({super.key});

  @override
  State<GroupDeletionRequestsPage> createState() => _GroupDeletionRequestsPageState();
}

class _GroupDeletionRequestsPageState extends State<GroupDeletionRequestsPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> requests = [];
  String? currentUserId;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    currentUserId = supabase.auth.currentUser?.id;
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    if (currentUserId == null) return;

    final res = await supabase
        .from('profiles')
        .select('role')
        .eq('id', currentUserId!)
        .maybeSingle();

    setState(() {
      currentUserRole = res?['role'] as String?;
    });

    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => isLoading = true);
    final res = await supabase
        .from('group_deletion_requests')
        .select('id, reason, created_at, group_id, user_id, status, profiles(display_name), groups(name)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        requests = List<Map<String, dynamic>>.from(res);
        isLoading = false;
      });
    }
  }

  Future<void> _approveGroup(String groupId) async {
    final messenger = ScaffoldMessenger.of(context);

    if (currentUserId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    try {
      final response = await supabase.rpc('approve_group_deletion', params: {
        'p_group_id': groupId,
        'p_user_id': currentUserId!, // use bang (!) safely after null check
      });

      messenger.showSnackBar(SnackBar(content: Text(response.data.toString())));
      _loadRequests();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Approval failed: $e')));
    }
  }


  Future<Map<String, int>> _getSupervisorApprovalStats(String groupId) async {
    // Count all global supervisors
    final totalRes = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'supervisor');
    final total = (totalRes as List).length;

    // Get all approvals for this group
    final approvedRes = await supabase
        .from('group_deletion_approvals')
        .select('user_id')
        .eq('group_id', groupId);

    // Fetch roles for each approved user in parallel
    final roleChecks = await Future.wait(
      (approvedRes as List).map((a) async {
        final uid = a['user_id'];
        final roleRes = await supabase
            .from('profiles')
            .select('role')
            .eq('id', uid)
            .maybeSingle();
        return roleRes?['role'] == 'supervisor';
      }),
    );

    final approved = roleChecks.where((isSupervisor) => isSupervisor).length;

    return {'approved': approved, 'total': total};
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group Deletion Requests')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text('No pending requests'))
              : ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final groupName = req['groups']['name'] ?? 'Unknown';
                    final requestedBy = req['profiles']['display_name'] ?? 'User';
                    final reason = req['reason'] ?? '(no reason provided)';
                    final groupId = req['group_id'];

                    return FutureBuilder<Map<String, int>>(
                      future: _getSupervisorApprovalStats(groupId),
                      builder: (context, snapshot) {
                        final approvalStatus = snapshot.data;
                        final approved = approvalStatus?['approved'] ?? 0;
                        final total = approvalStatus?['total'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.all(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Group: $groupName', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Requested by: $requestedBy'),
                                const SizedBox(height: 4),
                                Text('Reason: $reason'),
                                if (currentUserRole == 'supervisor' || currentUserRole == 'owner')
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),
                                      Text('Supervisor Approvals: $approved of $total'),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: () => _approveGroup(groupId),
                                        child: const Text('Approve Group Deletion'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
