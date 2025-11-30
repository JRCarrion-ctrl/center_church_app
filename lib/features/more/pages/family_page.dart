// file: lib/features/more/pages/family_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';

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
  final logger = Logger();

  List<Map<String, dynamic>> members = [];
  Map<String, String> userDefinedRelationships = {};
  String? familyCode;
  bool isLoading = true;
  String? error;
  String? currentUserId;

  String _generateFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentUserId = context.read<AppState>().profile?.id;
      if (currentUserId == null) {
        context.go('/landing');
        return;
      }
      if (widget.familyId != null) {
        _loadFamily();
      } else {
        setState(() => isLoading = false);
      }
    });
  }

  Future<void> _loadFamily() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final fid = widget.familyId;
    if (fid == null) {
      setState(() {
        isLoading = false;
        error = 'No family ID provided';
      });
      return;
    }

    try {
      final client = GraphQLProvider.of(context).value;

      const q = r'''
        query FamilyData($fid: uuid!, $viewer: String!) {
          families_by_pk(id: $fid) {
            family_code
          }
          family_members(where: { family_id: { _eq: $fid } }) {
            id
            family_id
            user_id
            relationship
            status
            is_child
            user: profile {
              id
              display_name
              photo_url
            }
            child: child_profile {
              id
              display_name
              photo_url
              birthday
              allergies
              notes
              emergency_contact
            }
          }
          user_family_relationships(
            where: {
              family_id: { _eq: $fid },
              viewer_id: { _eq: $viewer }
            }
          ) {
            related_user_id
            relationship
          }
        }
      ''';

      final res = await client.query(
        QueryOptions(
          document: gql(q),
          variables: {'fid': fid, 'viewer': currentUserId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        logger.e('FamilyData error', error: res.exception);
        setState(() {
          error = 'Failed to load family';
          isLoading = false;
        });
        return;
      }

      final data = res.data!;
      final fm = (data['family_members'] as List<dynamic>).cast<Map<String, dynamic>>();
      final rels = (data['user_family_relationships'] as List<dynamic>).cast<Map<String, dynamic>>();
      final code = data['families_by_pk']?['family_code'] as String?;

      setState(() {
        members = fm;
        userDefinedRelationships = {
          for (final r in rels)
            if (r['related_user_id'] != null && r['relationship'] != null)
              r['related_user_id'] as String: r['relationship'] as String
        };
        familyCode = code;
        isLoading = false;
      });
    } catch (e, stack) {
      logger.e('Failed to load family', error: e, stackTrace: stack);
      setState(() {
        error = 'Failed to load family';
        isLoading = false;
      });
    }
  }

  // --- UI BUILDERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }

  List<Widget> _buildSectionList(String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return [];
    return [
      _buildSectionHeader(title),
      ...items.map(_buildMemberTile),
    ];
  }

  List<Widget> _buildChildrenSectionList(List<Map<String, dynamic>> childrenItems) {
    // Always return the list so the "Add Child" button is visible
    return [
      _buildSectionHeader("key_280b".tr()), // "Children"
      
      ...childrenItems.map(_buildMemberTile),

      // The "Add Child" Button is essentially a list item at the end
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.add, color: Theme.of(context).primaryColor, size: 20),
        ),
        title: Text(
          "key_239".tr(), // "Add Child"
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: _addChild,
      ),
    ];
  }

  Widget _buildMemberTile(Map<String, dynamic> m) {
    final isChild = m['is_child'] == true;
    final user = m['user'];
    final child = m['child'];
    final userId = user?['id'] as String?;
    final name = user?['display_name'] ?? child?['display_name'] ?? 'Unnamed';
    final photo = user?['photo_url'] ?? child?['photo_url'];
    
    final relationship = userId != null ? (userDefinedRelationships[userId] ?? '') : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (photo != null && photo.toString().isNotEmpty) 
            ? NetworkImage(photo) 
            : null,
        child: (photo == null || photo.toString().isEmpty)
            ? Icon(isChild ? Icons.child_care : Icons.person)
            : null,
      ),
      title: Text(name),
      subtitle: (isChild || userId == null || userId == currentUserId) 
        ? null 
        : Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  relationship.isEmpty ? "key_281".tr() : relationship, 
                  style: TextStyle(
                    color: relationship.isEmpty 
                        ? Theme.of(context).hintColor 
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: relationship.isEmpty ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                backgroundColor: Theme.of(context).cardColor,
                side: BorderSide(color: Theme.of(context).dividerColor),
                onPressed: () => _showRelationshipPicker(userId, relationship),
              ),
            ),
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

  // --- LOGIC METHODS ---

  void _showRelationshipPicker(String userId, String currentRelationship) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "key_281".tr(), 
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: defaultRelationships.length,
                itemBuilder: (context, index) {
                  final rel = defaultRelationships[index];
                  final isSelected = rel == currentRelationship;
                  return ListTile(
                    title: Text(
                      rel,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    trailing: isSelected 
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) 
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext); 
                      _updateRelationship(userId, rel);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Future<void> _updateRelationship(String relatedUserId, String value) async {
    final fid = widget.familyId;
    if (fid == null || currentUserId == null) return;

    try {
      final client = GraphQLProvider.of(context).value;
      const m = r'''
        mutation UpsertRelationship(
          $viewer: String!,
          $related: String!,
          $fid: uuid!,
          $relationship: String!
        ) {
          insert_user_family_relationships_one(
            object: {
              viewer_id: $viewer,
              related_user_id: $related,
              family_id: $fid,
              relationship: $relationship
            },
            on_conflict: {
              constraint: unique_rel_viewer_related_family,
              update_columns: [relationship]
            }
          ) {
            viewer_id
          }
        }
      ''';

      final res = await client.mutate(
        MutationOptions(
          document: gql(m),
          variables: {
            'viewer': currentUserId,
            'related': relatedUserId,
            'fid': fid,
            'relationship': value,
          },
        ),
      );

      if (res.hasException) {
        logger.e('UpsertRelationship error', error: res.exception);
        _showSnackbar('Could not update relationship');
        return;
      }
      setState(() => userDefinedRelationships[relatedUserId] = value);
    } catch (e) {
      logger.e('Failed to update relationship', error: e);
      _showSnackbar('Could not update relationship');
    }
  }

  // --- SCAFFOLD BUILD ---

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (widget.familyId == null) {
      return Scaffold(
        appBar: AppBar(title: Text("key_275".tr())),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("key_276".tr()),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _createFamily, child: Text("key_277".tr())),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _showJoinFamilyDialog, child: Text("key_278".tr())),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    final self = members.where((m) => (m['user']?['id'] as String?) == currentUserId).toList();
    final children = members.where((m) => m['is_child'] == true).toList();
    final adults = members.where((m) => m['is_child'] != true && (m['user']?['id'] as String?) != currentUserId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("key_279".tr()),
        leading: BackButton(onPressed: () => context.go('/more')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFamily,
        child: Column(
          children: [
            if (familyCode != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("key_279a".tr(args: [familyCode ?? '']), style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 2.0
                      ),),
                  ],
                ),
              ),

            // --- REPLACED EXPANSION TILES WITH FLAT LIST ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 0), // Tiles have their own padding
                children: [
                  ..._buildSectionList("key_280a".tr(), self), // Me
                  
                  ..._buildChildrenSectionList(children), // Children + Add Button
                  
                  ..._buildSectionList("key_280c".tr(), adults), // Adults
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _leaveFamily,
                icon: const Icon(Icons.logout),
                label: Text("key_280".tr()),
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

  void _addChild() {
    if (widget.familyId != null) {
      context.pushNamed('add_child_profile', extra: widget.familyId);
    }
  }

  Future<void> _createFamily() async {
    final code = _generateFamilyCode();
    final uid = currentUserId;
    if (uid == null) return;

    final client = GraphQLProvider.of(context).value;

    const mCreate = r'''
      mutation CreateFamily($code: String!) {
        insert_families_one(object: { family_code: $code }) { id }
      }
    ''';
    const mAddSelf = r'''
      mutation AddSelf($fid: uuid!, $uid: String!) {
        insert_family_members_one(object: {
          family_id: $fid,
          user_id: $uid,
          relationship: "Self",
          status: "accepted"
        }) { id }
      }
    ''';

    try {
      final res1 = await client.mutate(
        MutationOptions(document: gql(mCreate), variables: {'code': code}),
      );
      if (res1.hasException) {
        logger.e('CreateFamily error', error: res1.exception);
        return;
      }
      final newId = res1.data?['insert_families_one']?['id'] as String;

      final res2 = await client.mutate(
        MutationOptions(document: gql(mAddSelf), variables: {'fid': newId, 'uid': uid}),
      );
      if (res2.hasException) {
        logger.e('AddSelf error', error: res2.exception);
        return;
      }

      if (mounted) context.go('/more/family', extra: {'familyId': newId});
    } catch (e) {
      logger.e('Create family failed', error: e);
    }
  }

  Future<void> _joinFamilyByCode(String code) async {
    final formatted = code.trim().toUpperCase();
    final uid = currentUserId;
    if (uid == null) return;

    final client = GraphQLProvider.of(context).value;

    const qByCode = r'''
      query FindFamilyByCode($code: String!) {
        families(where: { family_code: { _eq: $code } }, limit: 1) { id }
      }
    ''';
    const mJoin = r'''
      mutation JoinFamily($fid: uuid!, $uid: String!) {
        insert_family_members_one(object: {
          user_id: $uid,
          family_id: $fid,
          relationship: "Relative",
          status: "accepted"
        }) { id }
      }
    ''';

    final res1 = await client.query(
      QueryOptions(document: gql(qByCode), variables: {'code': formatted}),
    );
    if (res1.hasException) {
      _showSnackbar('Family code lookup failed.');
      return;
    }
    final families = (res1.data?['families'] as List<dynamic>? ?? []);
    if (families.isEmpty) {
      _showSnackbar('Family code not found.');
      return;
    }
    final fid = families.first['id'] as String;

    final res2 = await client.mutate(
      MutationOptions(document: gql(mJoin), variables: {'fid': fid, 'uid': uid}),
    );
    if (res2.hasException) {
      _showSnackbar('Could not join family.');
      return;
    }

    if (mounted) context.go('/more/family', extra: {'familyId': fid});
  }

  Future<void> _leaveFamily() async {
    if (currentUserId == null || widget.familyId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_282".tr()),
        content: Text("key_283".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("key_284".tr())),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("key_285".tr())),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final client = GraphQLProvider.of(context).value;
    const m = r'''
      mutation LeaveFamily($uid: String!, $fid: uuid!) {
        delete_family_members(
          where: { user_id: { _eq: $uid }, family_id: { _eq: $fid } }
        ) { affected_rows }
      }
    ''';

    final res = await client.mutate(
      MutationOptions(document: gql(m), variables: {'uid': currentUserId, 'fid': widget.familyId}),
    );
    if (res.hasException) {
      _showSnackbar('Unable to leave family.');
      return;
    }

    if (mounted) context.go('/more/family', extra: {'familyId': null});
  }

  void _showJoinFamilyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_286".tr()),
        content: TextField(
          controller: controller,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: "key_286a".tr()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("key_287".tr())),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinFamilyByCode(controller.text);
            },
            child: Text("key_288".tr()),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}