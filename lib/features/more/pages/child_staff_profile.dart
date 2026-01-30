// File: lib/features/more/pages/child_staff_profile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart'; 

class ChildStaffProfilePage extends StatelessWidget {
  final String childId;
  const ChildStaffProfilePage({super.key, required this.childId});

  static const String _childQuery = r'''
    query ChildProfileForStaff($id: uuid!) {
      child_profiles_by_pk(id: $id) {
        id
        display_name
        birthday
        photo_url
        allergies
        notes
        emergency_contact
        profiles { 
          id
          display_name
          phone
        }
      }
    }
  ''';

  String _formatBirthday(String iso) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _nonEmptyOr(String? value, String fallback) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? fallback : v;
  }
  
  String formatUSPhone(String input) {
    return input;
  }

  void _showFullScreenPhoto(BuildContext context, String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.topLeft,
            children: [
              Center(
                child: CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- UPDATED HELPER: Now accepts 'trailing' widget ---
  Widget _buildInfoTile(
    BuildContext context, 
    String title, 
    IconData icon, 
    String? content,
    {
      bool isPhone = false, 
      VoidCallback? onTap, 
      bool isThreeLine = false,
      Widget? trailing, // <--- Added this parameter
    }) 
  {
    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }
  
    final displayContent = isPhone ? formatUSPhone(content) : content;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(displayContent),
      subtitle: Text(title),
      isThreeLine: isThreeLine,
      dense: !isThreeLine,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), 
      trailing: trailing, // <--- Used here
    );
  }

  // --- MAIN PROFILE BUILDER ---

  Widget _buildProfileBody(BuildContext context, Map<String, dynamic> child) {
    final name = (child['display_name'] ?? 'Unnamed') as String;
    final birthday = child['birthday'] as String; 
    final formattedBirthday = _formatBirthday(birthday);
    final photoUrl = child['photo_url'] as String?;
    final allergies = child['allergies'] as String?;
    final notes = child['notes'] as String?;
    final emergency = child['emergency_contact'] as String?;

    final familyMember = child['profiles'] as Map<String, dynamic>?;

    final parentName = familyMember?['display_name'] as String?;
    final parentPhone = familyMember?['phone'] as String?;
    final parentId = familyMember?['id'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text("key_237a".tr()),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Add refresh logic if needed
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () => _showFullScreenPhoto(context, photoUrl),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              child: (photoUrl != null && photoUrl.isNotEmpty)
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: photoUrl,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.person, size: 50),
                                      ),
                                    )
                                  : const Icon(Icons.person, size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          "key_320".tr(args: [formattedBirthday]),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                
                  const Divider(height: 1, thickness: 1),

                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        // Allergies
                        _buildInfoTile(
                          context,
                          "key_321".tr(), // "Allergies"
                          Icons.medication,
                          _nonEmptyOr(allergies, "None".tr()),
                          isThreeLine: true,
                        ),
                        // Notes
                        _buildInfoTile(
                          context,
                          "key_322".tr(), // "Notes"
                          Icons.sticky_note_2_outlined,
                          _nonEmptyOr(notes, "None".tr()),
                          isThreeLine: true,
                        ),
                        
                        // Emergency Contact (UPDATED WITH CALL BUTTON)
                        _buildInfoTile(
                          context,
                          "key_323".tr(), // "Emergency Contact"
                          Icons.contact_phone,
                          _nonEmptyOr(emergency, "None".tr()),
                          isPhone: true,
                          // Add the call button if data exists
                          trailing: (emergency != null && emergency.isNotEmpty) 
                            ? IconButton(
                                icon: const Icon(Icons.call),
                                onPressed: () {
                                  // Sanitize string to numbers only for the tel: scheme
                                  final sanitized = emergency.replaceAll(RegExp(r'[^0-9]'), '');
                                  launchUrl(Uri(scheme: 'tel', path: sanitized));
                                },
                              )
                            : null,
                        ),
                      ],
                    ),
                  ),

                  // 3. Parent/Family Member Details (if available)
                  if (parentName != null) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.group, color: Theme.of(context).colorScheme.primary),
                      title: Text(parentName),
                      subtitle: Text("key_305e".tr()), // "Parent"
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (parentPhone != null)
                            IconButton(
                              icon: const Icon(Icons.call),
                              onPressed: () => launchUrl(Uri(scheme: 'tel', path: parentPhone.replaceAll(RegExp(r'[^0-9]'), ''))),
                            ),
                          // Navigate to parent's PublicProfile
                          if (parentId != null)
                            IconButton(
                              icon: const Icon(Icons.person),
                              onPressed: () => context.push('/profile/$parentId'),
                            ),
                        ],
                      ),
                      onTap: parentId != null ? () => context.push('/profile/$parentId') : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(_childQuery),
        variables: {'id': childId},
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (QueryResult result, {VoidCallback? refetch, FetchMore? fetchMore}) {
        if (result.hasException) {
          final errorText = 'Failed to load child profile: ${result.exception.toString()}';
          return Scaffold(body: Center(child: Text(errorText)));
        }

        if (result.isLoading && result.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final childData = result.data?['child_profiles_by_pk'] as Map<String, dynamic>?;

        if (childData == null) {
          return Scaffold(body: Center(child: Text('Child not found')));
        }
        
        return _buildProfileBody(context, childData);
      },
    );
  }
}