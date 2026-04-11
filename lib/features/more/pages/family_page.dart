// file: lib/features/more/pages/family_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  
  // 💡 NEW: Local state variable to track the active family
  String? _activeFamilyId;

  String _generateFamilyCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    _activeFamilyId = widget.familyId; // Initialize with URL param if it exists
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentUserId = context.read<AppState>().profile?.id;
      if (currentUserId == null) {
        context.go('/landing');
        return;
      }
      _checkExistingFamilyOrLoad();
    });
  }

  // 💡 NEW: Checks if the user is already in a family before showing the "Join" screen
  Future<void> _checkExistingFamilyOrLoad() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    if (_activeFamilyId != null) {
      await _loadFamily();
      return;
    }

    try {
      final client = GraphQLProvider.of(context).value;
      const q = r'''
        query GetMyFamily($uid: String!) {
          family_members(where: {user_id: {_eq: $uid}}, limit: 1) {
            family_id
          }
        }
      ''';
      
      final res = await client.query(QueryOptions(
        document: gql(q),
        variables: {'uid': currentUserId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (res.hasException) throw res.exception!;

      final famMembers = res.data?['family_members'] as List?;
      if (famMembers != null && famMembers.isNotEmpty) {
        // User IS in a family, set the ID and load it
        _activeFamilyId = famMembers[0]['family_id'];
        await _loadFamily();
      } else {
        // User is NOT in a family, show the empty state
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e, stack) {
      logger.e('Failed to check existing family', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          error = 'Failed to load family data';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFamily() async {
    if (_activeFamilyId == null) {
      setState(() => isLoading = false);
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
          variables: {'fid': _activeFamilyId, 'viewer': currentUserId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) {
        logger.e('FamilyData error', error: res.exception);
        if (mounted) {
          setState(() {
            error = 'Failed to load family';
            isLoading = false;
          });
        }
        return;
      }

      final data = res.data!;
      final fm = (data['family_members'] as List<dynamic>).cast<Map<String, dynamic>>();
      final rels = (data['user_family_relationships'] as List<dynamic>).cast<Map<String, dynamic>>();
      final code = data['families_by_pk']?['family_code'] as String?;

      if (mounted) {
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
      }
    } catch (e, stack) {
      logger.e('Failed to load family', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          error = 'Failed to load family';
          isLoading = false;
        });
      }
    }
  }

  // --- UI BUILDERS ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return [
      _buildSectionHeader("key_280b".tr()), 
      ...childrenItems.map(_buildMemberTile),
      
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.2 : 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _addChild,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "key_239".tr(), 
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildMemberTile(Map<String, dynamic> m) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final isChild = m['is_child'] == true;
    final user = m['user'];
    final child = m['child'];
    final userId = user?['id'] as String?;
    final name = user?['display_name'] ?? child?['display_name'] ?? 'Unnamed';
    final photo = user?['photo_url'] ?? child?['photo_url'];
    
    final relationship = userId != null ? (userDefinedRelationships[userId] ?? '') : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2), width: 2),
          ),
          child: ClipOval(
            child: (photo != null && photo.toString().isNotEmpty)
                ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
                : Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(isChild ? Icons.child_care : Icons.person, color: theme.colorScheme.primary),
                  ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: (isChild || userId == null || userId == currentUserId) 
          ? null 
          : Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showRelationshipPicker(userId, relationship),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: relationship.isEmpty 
                          ? theme.colorScheme.surfaceContainerHighest 
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      relationship.isEmpty ? "key_281".tr() : relationship, 
                      style: TextStyle(
                        fontSize: 12,
                        color: relationship.isEmpty 
                            ? theme.colorScheme.onSurfaceVariant 
                            : theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          if (isChild && child != null) {
            context.push('/more/family/view_child?childId=${child['id']}');
          } else if (user != null) {
            context.push('/profile/${user['id']}');
          }
        },
      ),
    );
  }

  // --- LOGIC METHODS ---

  void _showRelationshipPicker(String userId, String currentRelationship) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "key_281".tr(), 
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) 
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext); 
                      _updateRelationship(userId, rel);
                    },
                  );
                },
              ),
            ),
            SafeArea(child: const SizedBox(height: 10)),
          ],
        );
      },
    );
  }

  Future<void> _updateRelationship(String relatedUserId, String value) async {
    if (_activeFamilyId == null || currentUserId == null) return;

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
            'fid': _activeFamilyId,
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
    final theme = Theme.of(context);

    if (isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text("key_279".tr(), style: const TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    // 💡 CHECK LOCAL STATE INSTEAD OF WIDGET PARAMETER
    if (_activeFamilyId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text("key_275".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.family_restroom, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                const SizedBox(height: 24),
                Text(
                  "key_276".tr(),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a new family to manage children, or join an existing family using a code.",
                  style: TextStyle(color: theme.colorScheme.outline),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: _createFamily, 
                  icon: const Icon(Icons.add),
                  label: Text("key_277".tr()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _showJoinFamilyDialog, 
                  icon: const Icon(Icons.group_add),
                  label: Text("key_278".tr()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("key_279".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/more');
          }
        }),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFamily,
        color: theme.colorScheme.primary,
        child: Column(
          children: [
            if (familyCode != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.tag, color: theme.colorScheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Family Code", 
                            style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            familyCode!, 
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900, 
                              letterSpacing: 4.0,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: theme.colorScheme.onPrimaryContainer),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: familyCode!));
                        _showSnackbar("Family code copied to clipboard");
                      },
                      tooltip: "Copy Code",
                    ),
                  ],
                ),
              ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                children: [
                  ..._buildSectionList("key_280a".tr(), self),
                  ..._buildChildrenSectionList(children),
                  ..._buildSectionList("key_280c".tr(), adults),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: OutlinedButton.icon(
                onPressed: _leaveFamily,
                icon: const Icon(Icons.logout),
                label: Text("key_280".tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addChild() {
    if (_activeFamilyId != null) {
      context.push('/more/family/add_child?familyId=$_activeFamilyId');
    }
  }

  Future<void> _createFamily() async {
    final code = _generateFamilyCode();
    final uid = currentUserId;
    if (uid == null) return;

    setState(() => isLoading = true); // Start Loading UI
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
      if (res1.hasException) throw res1.exception!;
      
      final newId = res1.data?['insert_families_one']?['id'] as String;

      final res2 = await client.mutate(
        MutationOptions(document: gql(mAddSelf), variables: {'fid': newId, 'uid': uid}),
      );
      if (res2.hasException) throw res2.exception!;

      // 💡 NEW: Update local state and fetch data instantly
      if (mounted) {
        setState(() => _activeFamilyId = newId);
        await _loadFamily();
      }
    } catch (e) {
      logger.e('Create family failed', error: e);
      if (mounted) setState(() => isLoading = false);
      _showSnackbar("Failed to create family");
    }
  }

  Future<void> _joinFamilyByCode(String code) async {
    final formatted = code.trim().toUpperCase();
    final uid = currentUserId;
    if (uid == null) return;

    setState(() => isLoading = true); // Start Loading UI
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

    try {
      final res1 = await client.query(
        QueryOptions(document: gql(qByCode), variables: {'code': formatted}),
      );
      if (res1.hasException) throw Exception('Lookup failed');
      
      final families = (res1.data?['families'] as List<dynamic>? ?? []);
      if (families.isEmpty) {
        _showSnackbar('Family code not found.');
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final fid = families.first['id'] as String;

      final res2 = await client.mutate(
        MutationOptions(document: gql(mJoin), variables: {'fid': fid, 'uid': uid}),
      );
      if (res2.hasException) throw Exception('Join failed');

      // 💡 NEW: Update local state and fetch data instantly
      if (mounted) {
        setState(() => _activeFamilyId = fid);
        await _loadFamily();
      }
    } catch (e) {
      _showSnackbar('Could not join family.');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _leaveFamily() async {
    if (currentUserId == null || _activeFamilyId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_282".tr()),
        content: Text("key_283".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("key_284".tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true), 
            child: Text("key_285".tr())
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => isLoading = true);
    if (!mounted) return;
    final client = GraphQLProvider.of(context).value;
    const m = r'''
      mutation LeaveFamily($uid: String!, $fid: uuid!) {
        delete_family_members(
          where: { user_id: { _eq: $uid }, family_id: { _eq: $fid } }
        ) { affected_rows }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(document: gql(m), variables: {'uid': currentUserId, 'fid': _activeFamilyId}),
      );
      if (res.hasException) throw Exception('Leave failed');

      // 💡 NEW: Instantly drop the user back to the empty state screen
      if (mounted) {
        setState(() {
          _activeFamilyId = null;
          isLoading = false;
        });
      }
    } catch (e) {
      _showSnackbar('Unable to leave family.');
      if (mounted) setState(() => isLoading = false);
    }
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
          decoration: InputDecoration(
            hintText: "key_286a".tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("key_287".tr())),
          FilledButton(
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }
}