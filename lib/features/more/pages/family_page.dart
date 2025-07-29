// file: lib/features/more/pages/family_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../more/models/invite_modal.dart';

const defaultRelationships = [
  'Parent', 'Child', 'Sibling', 'Spouse', 'Cousin', 'Uncle', 'Aunt',
  'Grandparent', 'Grandchild', 'Relative', 'Friend'
];

class FamilyPage extends StatefulWidget {
  final String? familyId;

  const FamilyPage({super.key, required this.familyId});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  final supabase = Supabase.instance.client;
  final logger = Logger();
  List<Map<String, dynamic>> members = [];
  Map<String, String> userDefinedRelationships = {};
  String? familyCode;
  bool isLoading = true;
  String? error;
  late final String currentUserId;

  String _generateFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    if (user == null) {
      context.go('/landing');
      return;
    }
    currentUserId = user.id;
    if (widget.familyId != null) {
      _loadFamily();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadFamily() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final familyId = widget.familyId;
    if (familyId == null) {
      setState(() {
        isLoading = false;
        error = 'No family ID provided';
      });
      return;
    }

    try {
      final membersResult = await supabase
          .from('family_members')
          .select('*, user:profiles!family_members_user_id_fkey(*), inviter:profiles!family_members_invited_by_fkey(*), child:child_profiles(*)')
          .eq('family_id', familyId);

      final relationshipsResult = await supabase
          .from('user_family_relationships')
          .select()
          .eq('viewer_id', currentUserId)
          .eq('family_id', familyId);

      final familyResult = await supabase
          .from('families')
          .select('family_code')
          .eq('id', familyId)
          .maybeSingle();

      setState(() {
        members = List<Map<String, dynamic>>.from(membersResult);
        userDefinedRelationships = {
          for (var r in relationshipsResult)
            if (r['related_user_id'] != null && r['relationship'] != null)
              r['related_user_id']: r['relationship']
        };
        familyCode = familyResult?['family_code'];
      });
    } catch (e, stack) {
      logger.e('Failed to load family', error: e, stackTrace: stack);
      setState(() => error = 'Failed to load family');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateRelationship(String relatedUserId, String value) async {
    final familyId = widget.familyId;
    if (familyId == null) return;

    try {
      await supabase
        .from('user_family_relationships')
        .upsert({
          'viewer_id': currentUserId,
          'related_user_id': relatedUserId,
          'family_id': familyId,
          'relationship': value,
        }, onConflict: 'viewer_id,related_user_id,family_id');

      setState(() => userDefinedRelationships[relatedUserId] = value);
    } catch (e) {
      logger.e('Failed to update relationship', error: e);
      _showSnackbar('Could not update relationship');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (widget.familyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Your Family")),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("You are not in a family yet."),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _createFamily, child: const Text("Create Family")),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _showJoinFamilyDialog, child: const Text("Join Family")),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    final self = members.where((m) => m['user']?['id'] == currentUserId).toList();
    final children = members.where((m) => m['is_child'] == true).toList();
    final adults = members.where((m) => m['is_child'] != true && m['user']?['id'] != currentUserId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Family"),
        leading: BackButton(onPressed: () => context.go('/more')),
        actions: [
          IconButton(icon: const Icon(Icons.child_care), onPressed: _addChild),
          IconButton(icon: const Icon(Icons.person_add), onPressed: _inviteUser),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFamily,
        child: Column(
          children: [
            if (familyCode != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Family Code: $familyCode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  if (self.isNotEmpty) _buildSection("You", self),
                  if (children.isNotEmpty) _buildSection("Children", children),
                  if (adults.isNotEmpty) _buildSection("Family Members", adults),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _leaveFamily,
                icon: const Icon(Icons.logout),
                label: const Text('Leave Family'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.red.shade100,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> items) {
    return ExpansionTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: items.map(_buildMemberTile).toList(),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> m) {
    final isChild = m['is_child'] == true;
    final user = m['user'];
    final child = m['child'];
    final userId = user?['id'];
    final memberUserId = user?['id'];
    final name = user?['display_name'] ?? child?['display_name'] ?? 'Unnamed';
    final photo = user?['photo_url'] ?? child?['photo_url'];
    final relationship = userId != null ? userDefinedRelationships[userId] ?? '' : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
        child: (photo == null || photo.isEmpty)
            ? Icon(isChild ? Icons.child_care : Icons.person)
            : null,
      ),
      title: Text(name),
      subtitle: Wrap(
        spacing: 6,
        children: [
          if (!isChild && userId != null && memberUserId != userId)
            DropdownButton<String>(
              value: relationship.isEmpty ? null : relationship,
              hint: const Text('Set Relationship'),
              items: defaultRelationships
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (value) {
                if (value != null) _updateRelationship(userId, value);
              },
            ),
        ],
      ),
      onTap: () {
        if (isChild && child != null) {
          context.pushNamed('view_child_profile', extra: child['id']);
        } else if (user != null) {
          context.push('/profile/${user['id']}');
        }
      },
    );
  }

  void _inviteUser() {
    if (widget.familyId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => InviteExistingUserModal(
        familyId: widget.familyId!,
        invitedBy: currentUserId,
      ),
    );
  }

  void _addChild() {
    if (widget.familyId != null) {
      context.pushNamed('add_child_profile', extra: widget.familyId);
    }
  }

  Future<void> _createFamily() async {
    final code = _generateFamilyCode();
    final res = await supabase.from('families').insert({'family_code': code}).select('id').single();
    final newId = res['id'];
    await supabase.from('family_members').insert({
      'user_id': currentUserId,
      'family_id': newId,
      'relationship': 'Self',
      'is_child': false,
      'status': 'accepted',
    });
    if (mounted) context.go('/more/family', extra: {'familyId': newId});
  }

  Future<void> _joinFamilyByCode(String code) async {
    final formatted = code.trim().toUpperCase();
    final result = await supabase
        .from('families')
        .select('id')
        .eq('family_code', formatted)
        .maybeSingle();
    if (result == null) {
      _showSnackbar('Family code not found.');
      return;
    }
    await supabase.from('family_members').insert({
      'user_id': currentUserId,
      'family_id': result['id'],
      'relationship': 'Relative',
      'is_child': false,
      'status': 'accepted',
    });
    if (mounted) context.go('/more/family', extra: {'familyId': result['id']});
  }

  Future<void> _leaveFamily() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Family'),
        content: const Text('Are you sure you want to leave this family?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirm != true) return;

    await supabase
        .from('family_members')
        .delete()
        .eq('user_id', currentUserId)
        .eq('family_id', widget.familyId!);

    if (mounted) context.go('/more/family', extra: {'familyId': null});
  }

  void _showJoinFamilyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Family'),
        content: TextField(
          controller: controller,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Enter Family Code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinFamilyByCode(controller.text);
            },
            child: const Text('Join Family'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
