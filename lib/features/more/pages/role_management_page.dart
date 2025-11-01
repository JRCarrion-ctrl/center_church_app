import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/app_state.dart';
import 'package:ccf_app/shared/user_roles.dart';

// --- GRAPHQL OPERATIONS ---
const String fetchAllProfilesWithRoles = r'''
  query FetchAllProfilesWithRoles {
    profiles(order_by: {display_name: asc}) {
      id
      display_name
      email
      role
    }
  }
''';

const String updateUserRole = r'''
  mutation UpdateUserRole($userId: String!, $newRole: String!) {
    update_profiles_by_pk(
      pk_columns: {id: $userId}, 
      _set: {role: $newRole}
    ) {
      id
      role
    }
  }
''';
// ----------------------------

// --- DATA STRUCTURE (Maps GraphQL response to an object) ---
class ProfileUser {
  final String id;
  final String displayName;
  final String email;
  String role; // Non-final because we update it locally
  
  ProfileUser({required this.id, required this.displayName, required this.email, required this.role});

  // Factory constructor to convert GraphQL Map into a ProfileUser object
  factory ProfileUser.fromMap(Map<String, dynamic> map) {
    return ProfileUser(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
    );
  }
}
// -----------------------------------------------------------

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  // Removed UserService and replaced it with direct GraphQL operations
  List<ProfileUser> _users = [];
  bool _isLoading = true;
  bool _isSaving = false;
  
  final TextEditingController _searchController = TextEditingController();
  
  // Define the hierarchy of roles for display order
  final List<String> _roleOrder = const [
    'owner', 
    'group_admin', 
    'supervisor', 
    'leader', 
    'nursery_staff', 
    'member',
  ];

  // List of valid roles for the dropdown
  final List<String> _availableRoles = const [
    'member',
    'group_admin', 
    'nursery_staff', 
    'leader', 
    'supervisor', 
    'owner'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    setState(() {});
  }

  // Filter logic based on current search text
  List<ProfileUser> get _filteredUsers {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _users;
    }
    return _users.where((user) {
      return user.displayName.toLowerCase().contains(query) ||
             user.email.toLowerCase().contains(query);
    }).toList();
  }

  // Group the filtered users into a Map by role, ordered by _roleOrder
  Map<String, List<ProfileUser>> get _groupedUsersByRole {
    final Map<String, List<ProfileUser>> grouped = {};
    for (var role in _roleOrder) {
      grouped[role] = [];
    }

    for (var user in _filteredUsers) {
      if (grouped.containsKey(user.role)) {
        grouped[user.role]!.add(user);
      } 
    }

    final filteredGroups = grouped.entries.where((entry) => entry.value.isNotEmpty).toList();
    
    // Sort based on the index in the predefined _roleOrder
    filteredGroups.sort((a, b) {
      final indexA = _roleOrder.indexOf(a.key);
      final indexB = _roleOrder.indexOf(b.key);
      return indexA.compareTo(indexB);
    });

    return Map.fromEntries(filteredGroups);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      // Initialize GraphQL client implicitly via context
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    
    final client = GraphQLProvider.of(context).value;

    try {
      final result = await client.query(
        QueryOptions(document: gql(fetchAllProfilesWithRoles)),
      );

      if (result.hasException) {
        throw result.exception!;
      }
      
      final List<dynamic> profilesData = result.data?['profiles'] ?? [];
      final List<ProfileUser> fetchedUsers = profilesData
          .map((map) => ProfileUser.fromMap(map as Map<String, dynamic>))
          .toList();
          
      if (mounted) {
        fetchedUsers.sort((a, b) => a.displayName.compareTo(b.displayName));
        setState(() {
          _users = fetchedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user list: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateUserRole(ProfileUser user, String newRole) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    
    if (user.role == newRole) {
      setState(() => _isSaving = false);
      return;
    }

    final client = GraphQLProvider.of(context).value;

    try {
      final result = await client.mutate(
        MutationOptions(
          document: gql(updateUserRole),
          variables: {
            'userId': user.id,
            'newRole': newRole,
          },
        ),
      );

      if (result.hasException) {
        throw result.exception!;
      }
      
      // Update the local state
      final updatedUserIndex = _users.indexWhere((u) => u.id == user.id);
      if (updatedUserIndex != -1) {
        setState(() {
          _users[updatedUserIndex].role = newRole;
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Role updated to $newRole for ${user.displayName}')),
        );
      }
    } catch (e) {
      debugPrint('Error updating role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update role: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  void _showRoleChangeDialog(ProfileUser user) {
    final isSelf = user.id == context.read<AppState>().profile?.id;

    if (isSelf) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot change your own role.')),
      );
      return;
    }

    showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('key_change_role_prompt'.tr(args: [user.displayName])),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableRoles.map((role) {
              final isCurrent = user.role == role;
              final displayRole = role.replaceAll('_', ' ').toUpperCase();

              return ListTile(
                title: Text(displayRole),
                trailing: isCurrent ? const Icon(Icons.check_circle, color: Colors.green) : null,
                onTap: () {
                  Navigator.pop(dialogContext, role); // Return the selected role
                },
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('key_cancel'.tr()),
            ),
          ],
        );
      },
    ).then((selectedRole) {
      if (selectedRole != null) {
        _updateUserRole(user, selectedRole);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final currentUserRole = context.select<AppState, UserRole?>((s) => s.userRole);
    final isOwner = currentUserRole == UserRole.owner;
    final currentUserId = context.select<AppState, String?>((s) => s.profile?.id);


    return Scaffold(
      appBar: AppBar(
        title: Text('key_admin_role_management_title'.tr()),
      ),
      body: !isOwner
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'key_admin_unauthorized_message'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    children: [
                      // Search Bar (remains at the top for filtering all users)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'key_search_users'.tr(),
                            hintText: 'key_search_name_email'.tr(),
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10.0)),
                            ),
                          ),
                        ),
                      ),
                      
                      // Display users grouped by role using ExpansionTiles
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadUsers,
                          child: ListView(
                            padding: const EdgeInsets.all(8.0),
                            children: _groupedUsersByRole.entries.map((entry) {
                              final role = entry.key;
                              final userList = entry.value;
                              final displayRole = role.replaceAll('_', ' ').toUpperCase();
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Card(
                                  elevation: 2,
                                  child: ExpansionTile(
                                    // Expand 'owner' list by default for quick access
                                    initiallyExpanded: role == 'owner', 
                                    title: Text('$displayRole (${userList.length})', 
                                        style: Theme.of(context).textTheme.titleMedium),
                                    
                                    children: userList.map((user) {
                                      final isSelf = user.id == currentUserId; 
                                      
                                      return ListTile(
                                        leading: CircleAvatar(child: Text(user.displayName[0])), // Placeholder for avatar
                                        title: Text(user.displayName),
                                        subtitle: Text(user.email),
                                        
                                        // Use onTap to trigger the dialog
                                        onTap: _isSaving ? null : () => _showRoleChangeDialog(user), 

                                        trailing: isSelf 
                                            ? Padding(
                                                padding: const EdgeInsets.only(right: 8.0),
                                                child: Icon(Icons.lock, color: Colors.grey[400]),
                                              )
                                            : Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(displayRole, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                                                  Text('key_change_role'.tr(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                                                ],
                                              ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
