import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageMembersPage extends StatefulWidget {
  final String groupId;

  const ManageMembersPage({super.key, required this.groupId});

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> {
  final supabase = Supabase.instance.client;
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> allMembers = [];
  List<Map<String, dynamic>> allPending = [];
  List<Map<String, dynamic>> filteredMembers = [];
  List<Map<String, dynamic>> filteredPending = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.headers['ccf_group_id'] = widget.groupId;
    _loadData();

    _searchController.addListener(() {
      _filterResults(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);

    try {
      final response = await supabase
          .from('group_memberships')
          .select('*, profiles(display_name, email)')
          .eq('group_id', widget.groupId);

      final result = (response as List).cast<Map<String, dynamic>>();
      allMembers = result.where((e) => e['status'] == 'approved').toList();
      allPending = result.where((e) => e['status'] == 'pending').toList();

      _filterResults(_searchController.text);
    } catch (e, stack) {
      debugPrint('Error loading group members: $e\n$stack');
      // Wait until the first frame is drawn before using context
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading members: $e')),
          );
        }
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _filterResults(String query) {
    final q = query.toLowerCase();

    filteredMembers = allMembers.where((e) {
      final profile = e['profiles'] ?? {};
      final name = (profile['display_name'] ?? '').toString().toLowerCase();
      final email = (profile['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    filteredPending = allPending.where((e) {
      final profile = e['profiles'] ?? {};
      final name = (profile['display_name'] ?? '').toString().toLowerCase();
      final email = (profile['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    setState(() {});
  }

  Future<void> _approveRequest(String userId) async {
    await supabase.from('group_memberships')
        .update({'status': 'approved'})
        .eq('group_id', widget.groupId)
        .eq('user_id', userId);
    _loadData();
  }

  Future<void> _denyRequest(String userId) async {
    await supabase.from('group_memberships')
        .delete()
        .eq('group_id', widget.groupId)
        .eq('user_id', userId);
    _loadData();
  }

  Future<void> _updateRole(String userId, String newRole) async {
    await supabase.from('group_memberships')
        .update({'role': newRole})
        .eq('group_id', widget.groupId)
        .eq('user_id', userId);
    _loadData();
  }

  Future<void> _removeMember(String userId) async {
    await supabase.from('group_memberships')
        .delete()
        .eq('group_id', widget.groupId)
        .eq('user_id', userId);
    _loadData();
  }

  Widget _buildUserRow(Map<String, dynamic> member, {bool isPending = false}) {
    final profile = member['profiles'] ?? {};
    final name = profile['display_name'] ?? 'Unnamed';
    final email = profile['email'] ?? 'No email';
    final role = member['role'] ?? 'member';
    final userId = member['user_id'];

    return ListTile(
      title: Text(name),
      subtitle: Text(isPending ? 'Pending Request' : '$email – Role: $role'),
      trailing: isPending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  tooltip: 'Approve',
                  onPressed: () => _approveRequest(userId),
                ),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  tooltip: 'Deny',
                  onPressed: () => _denyRequest(userId),
                ),
              ],
            )
          : userId == currentUserId
              ? const Text('You', style: TextStyle(fontWeight: FontWeight.bold))
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'admin':
                      case 'member':
                        _updateRole(userId, value);
                        break;
                      case 'remove':
                        _removeMember(userId);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (role != 'admin')
                      const PopupMenuItem(
                          value: 'admin', child: Text('Promote to Admin')),
                    if (role == 'admin')
                      const PopupMenuItem(
                          value: 'member', child: Text('Demote to Member')),
                    const PopupMenuItem(
                        value: 'remove', child: Text('Remove Member')),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Members')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (filteredPending.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Pending Requests',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ...filteredPending.map((e) =>
                            _buildUserRow(e, isPending: true)),

                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Current Members',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        ...filteredMembers.map(_buildUserRow),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
