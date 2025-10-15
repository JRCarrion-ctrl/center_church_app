// file: lib/features/more/pages/profile_page.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:ccf_app/core/graph_provider.dart';
import 'package:ccf_app/core/media/presigned_uploader.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ccf_app/features/auth/oidc_auth.dart';

import '../../../app_state.dart';

final _logger = Logger();

void _showSnackbar(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _displayName, _bio, _photoUrl, _phone;
  bool? _visible;
  bool _isLoading = true;
  GraphQLClient? _client;
  bool _bootstrapped = false;

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _family = [];
  List<Map<String, dynamic>> _prayerRequests = [];
  List<Map<String, dynamic>> _eventRsvps = [];

  @override
  void initState() {
    super.initState();
    _logger.i('ProfilePage initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    try {
      _client = GraphProvider.of(context);
      _bootstrapped = true;
      _logger.i('Dependencies are ready. Calling _loadAllData.');
      _loadAllData();
    } catch (e, st) {
      _logger.e('[gp] FAILED in didChangeDependencies', error: e, stackTrace: st);
    }
  }

  Future<void> _loadAllData() async {
    _logger.i('Starting _loadAllData');

    if (!mounted) {
      _logger.w('Not mounted, exiting _loadAllData');
      return;
    }

    setState(() => _isLoading = true);
    _logger.i('after is loading set to true');

    final userId = context.read<AppState>().profile?.id;
    if (userId == null) {
      _logger.w('User ID is null, exiting _loadAllData');
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/landing');
      }
      return;
    }
    _logger.i('User is logged in. Loading profile data.');
    final client = _client!;

    const qProfileBundle = '''
      query ProfileBundle(\$uid: String!) {
        profiles_by_pk(id: \$uid) {
          display_name
          bio
          photo_url
          visible_in_directory
          phone
        }
        group_memberships(where: { user_id: { _eq: \$uid } }) {
          id
          role
          group {
            id
            name
          }
        }
        my_family: family_members(
          where: { user_id: { _eq: \$uid }, status: { _eq: "accepted" } }
          limit: 1
        ) {
          id
          family_id
        }
        prayer_requests(where: { user_id: { _eq: \$uid } }, order_by: { created_at: desc }) {
          id
          request
          created_at
          expires_at
          status
        }
        event_attendance(where: { user_id: { _eq: \$uid } }, order_by: { created_at: desc }) {
          id
          attending_count
          created_at
          events {
            title
            event_date
          }
        }
        app_event_attendance(where: { user_id: { _eq: \$uid } }, order_by: { created_at: desc }) {
          id
          attending_count
          created_at
          app_events {
            title
            event_date
          }
        }
      }
    ''';

    try {
      _logger.i('[ProfileBundle] start');
      final res = await client.query(
        QueryOptions(
          document: gql(qProfileBundle),
          variables: {'uid': userId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      _logger.i('[ProfileBundle] got response');

      if (res.hasException) {
        _logger.e('[ProfileBundle] exception: ${res.exception}');
        // Only throw a real exception if it's not a CacheMissException.
        if (res.exception?.linkException is CacheMissException) {
          _logger.w('[ProfileBundle] CacheMissException is not a critical error. Continuing.');
        } else {
          _logger.e('Error loading profile data', error: res.exception);
          if (!mounted) return;
          _showSnackbar(context, "key_294a".tr());
          return;
        }
      }

      final profile = res.data?['profiles_by_pk'] as Map<String, dynamic>?;
      final groupsRows = (res.data?['group_memberships'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final prayersRows = (res.data?['prayer_requests'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final groupRSVPs = (res.data?['event_attendance'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final myFamilyList = (res.data?['my_family'] as List<dynamic>? ?? []);
      final fetchedFamilyId = myFamilyList.isNotEmpty ? (myFamilyList.first['family_id'] as String?) : null;

      List<Map<String, dynamic>> familyRows = [];
      if (fetchedFamilyId != null) {
        familyRows = await _fetchFamilyMembers(client, fetchedFamilyId);
      }

      setState(() {
        _displayName = profile?['display_name'] as String?;
        _bio = profile?['bio'] as String?;
        _photoUrl = profile?['photo_url'] as String?;
        _phone = profile?['phone'] as String?;
        _visible = (profile?['visible_in_directory'] as bool?) ?? true;
        _groups = groupsRows;
        _family = familyRows;
        _prayerRequests = prayersRows;
        final appRSVPs = (res.data?['app_event_attendance'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        _eventRsvps = [
          ...groupRSVPs.map((r) => {...r, 'source': 'group'}),
          ...appRSVPs.map((r) => {...r, 'source': 'app'}),
        ];
      });

    } catch (e, st) {
      _logger.e('Error loading profile data', error: e, stackTrace: st);
      if (!mounted) return;
      _showSnackbar(context, "key_294a".tr());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _logger.i('[ProfileBundle] finished');
      }
    }
  }


  Future<List<Map<String, dynamic>>> _fetchFamilyMembers(GraphQLClient client, String familyId) async {
    _logger.d('Starting _fetchFamilyMembers');
    const qFamily = r'''
      query Family($fid: uuid!) {
        family_members(
          where: { family_id: { _eq: $fid }, status: { _eq: "accepted" } }
        ) {
          id
          relationship
          status
          user_id
          is_child
          child: child_profile { display_name }
          user: profile { id display_name photo_url }
        }
      }
    ''';
    try {
      final res = await client.query(
        QueryOptions(
          document: gql(qFamily),
          variables: {'fid': familyId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (res.hasException) {
        _logger.e('Family data GraphQL query failed', error: res.exception);
        throw res.exception!;
      }
      _logger.d('Family data query successful.');
      return (res.data?['family_members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    } catch (e, st) {
      _logger.e('Error fetching family members', error: e, stackTrace: st);
      return [];
    }
  }

  Future<File> _compressImage(File file) async {
    final targetPath = file.path.replaceFirst(RegExp(r'\.(jpg|jpeg|png|heic|webp)$', caseSensitive: false), '_compressed.jpg');
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 600,
      minHeight: 600,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    if (compressedBytes == null) return file;
    return File(targetPath)..writeAsBytesSync(compressedBytes);
  }

  Future<void> _editPhoto() async {
    _logger.i('Attempting to edit profile photo');
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) {
      _logger.i('Photo picker cancelled.');
      return;
    }

    _logger.d('Image picked, starting compression.');
    File file = File(picked.path);
    file = await _compressImage(file);
    if (!mounted) return;
    
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) {
      _logger.e('User ID null during photo edit.');
      return;
    }

    try {
      _logger.d('Uploading image to cloud storage.');
      final uploadedUrl = await PresignedUploader.upload(file: file, keyPrefix: 'profile_photos', logicalId: '$userId.jpg');
      if (uploadedUrl.isEmpty) {
        if (!mounted) return;
        _showSnackbar(context, "key_294d".tr());
        return;
      }
      _logger.d('Image uploaded successfully: $uploadedUrl');

      final cacheBustedUrl = '$uploadedUrl?ts=${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      final client = GraphProvider.of(context);
      
      _logger.d('Updating user profile with new photo URL.');
      const m = r'''
        mutation SetPhoto($id: uuid!, $url: String!) {
          update_profiles_by_pk(pk_columns: { id: $id }, _set: { photo_url: $url }) { id }
        }
      ''';
      final res = await client.mutate(MutationOptions(document: gql(m), variables: {'id': userId, 'url': cacheBustedUrl}));
      if (res.hasException) {
        _logger.e('GraphQL mutation for photo URL failed.', error: res.exception);
        throw res.exception!;
      }
      _logger.d('Photo URL updated in database.');
      
      if (_photoUrl != null && _photoUrl!.isNotEmpty) {
        _logger.d('Evicting old image from cache.');
        await CachedNetworkImage.evictFromCache(_photoUrl!);
        final prevBase = _photoUrl!.split('?').first;
        if (prevBase.isNotEmpty) await CachedNetworkImage.evictFromCache(prevBase);
      }
      
      if (!mounted) return;
      setState(() => _photoUrl = cacheBustedUrl);
      _showSnackbar(context, "key_294e".tr());
      _logger.i('Profile photo updated successfully.');

    } catch (e, st) {
      _logger.e('Error during photo upload or update', error: e, stackTrace: st);
      _showSnackbar(context, "key_294f".tr());
    }
  }

  Future<void> _editField({required String label, required String initialValue, required ValueChanged<String> onSaved}) async {
    final controller = TextEditingController(text: initialValue);
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("key_295".tr(args: [label])),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "key_295a".tr(args: [label])),
          maxLines: label.toLowerCase() == 'bio' ? 3 : 1,
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: Text("key_296".tr())),
          TextButton(onPressed: () => context.pop(controller.text.trim()), child: Text("key_297".tr())),
        ],
      ),
    );
    if (newValue == null || newValue.isEmpty) return;
    onSaved(newValue);
  }

  Future<void> _updateProfileField(String key, String value) async {
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) {
      throw Exception('User not logged in.');
    }
    final client = GraphProvider.of(context);
    
    // 1. Simplified Mutation (as shown above)
    const m = r'''
      mutation UpdateField($id: uuid!, $_set: profiles_set_input!) {
        update_profiles_by_pk(
          pk_columns: { id: $id },
          _set: $_set
        ) { id }
      }
    ''';

    // 2. Create the dynamic set object
    final Map<String, dynamic> setVariables = { key: value };

    // 3. Execute the mutation with the dynamic map
    await client.mutate(
      MutationOptions(
        document: gql(m), 
        variables: {
          'id': userId, 
          '_set': setVariables, // Pass the map containing only the updated field
        }
      )
    );
  }

  Future<void> _toggleVisibility(bool value) async {
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;
    final client = GraphProvider.of(context);
    const m = r'''
      mutation ToggleVisible($id: uuid!, $visible: Boolean!) {
        update_profiles_by_pk(
          pk_columns: { id: $id },
          _set: { visible_in_directory: $visible }
        ) { id }
      }
    ''';
    await client.mutate(MutationOptions(document: gql(m), variables: {'id': userId, 'visible': value}));
    setState(() => _visible = value);
  }

  Future<void> _changePassword() async {
    if (!mounted) return;

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmNewPasswordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        // Use a StatefulBuilder to manage the dialog's own loading state.
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isChanging = false;
            String? errorText;

            Future<void> performChange() async {
              final currentPassword = currentPasswordController.text;
              final newPassword = newPasswordController.text;
              final confirmNewPassword = confirmNewPasswordController.text;

              if (newPassword != confirmNewPassword) {
                setDialogState(() => errorText = "Passwords do not match.");
                return;
              }
              if (currentPassword.isEmpty || newPassword.isEmpty) {
                setDialogState(() => errorText = "Password fields cannot be empty.");
                return;
              }
              
              setDialogState(() {
                isChanging = true;
                errorText = null;
              });

              try {
                await OidcAuth.refreshIfNeeded();
                await OidcAuth.changePassword(currentPassword, newPassword);
                if (mounted) {
                  Navigator.of(context).pop(); // Close dialog on success
                  _showSnackbar(context, "Password changed successfully.");
                }
              } catch (e) {
                _logger.e('Failed to change password', error: e);
                setDialogState(() {
                  isChanging = false;
                  errorText = "Failed to change password. Please check your current password.";
                });
              }
            }

            return AlertDialog(
              title: const Text("Change Password"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: currentPasswordController, decoration: const InputDecoration(labelText: "Current Password"), obscureText: true),
                    TextField(controller: newPasswordController, decoration: const InputDecoration(labelText: "New Password"), obscureText: true),
                    TextField(controller: confirmNewPasswordController, decoration: const InputDecoration(labelText: "Confirm New Password"), obscureText: true),
                    if (errorText != null) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isChanging ? null : () => Navigator.of(context).pop(), child: const Text("Cancel")),
                TextButton(
                  onPressed: isChanging ? null : performChange,
                  child: isChanging ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Change"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removePrayerRequest(String id) async {
    final client = GraphProvider.of(context);
    const m = r'''
      mutation DeletePrayer($id: uuid!) {
        delete_prayer_requests_by_pk(id: $id) { id }
      }
    ''';
    await client.mutate(MutationOptions(document: gql(m), variables: {'id': id}));
    setState(() => _prayerRequests.removeWhere((r) => r['id'] == id));
  }

  Future<void> _logout() async {
    final appState = context.read<AppState>();
    await appState.signOut();
    if (mounted) context.go('/landing');
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("key_301".tr()),
        content: Text("key_302".tr()),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: Text("key_303".tr())),
          TextButton(onPressed: () => context.pop(true), child: Text("key_302a".tr(), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;
    try {
      final client = GraphProvider.of(context);
      const m = r'''
        mutation DeleteAccount($id: uuid!) {
          delete_user_account(id: $id) { ok }
        }
      ''';
      await client.mutate(MutationOptions(document: gql(m), variables: {'id': userId}));
    } catch (e, st) {
      _logger.e('Delete account failed', error: e, stackTrace: st);
      if (!mounted) return;
      _showSnackbar(context, "key_207".tr());
      return;
    }
    if (!mounted) return;
    await context.read<AppState>().signOut();
    if (mounted) context.go('/landing');
  }

  String _formatUSPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return input;
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _editPhoto,
            child: CircleAvatar(
              radius: 48,
              backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty) ? CachedNetworkImageProvider(_photoUrl!) : null,
              child: (_photoUrl == null || _photoUrl!.isEmpty) ? const Icon(Icons.person, size: 48) : null,
            ),
          ),
          TextButton(onPressed: _editPhoto, child: Text("key_305".tr())),
          const SizedBox(height: 8),
          _buildEditableTextRow(
            text: _displayName,
            onEdit: () async {
              await _editField(
                label: "key_305a".tr(),
                initialValue: _displayName ?? '',
                onSaved: (v) async {
                  await _updateProfileField('display_name', v);
                  setState(() => _displayName = v);
                },
              );
            },
          ),
          const SizedBox(height: 4),
          _buildEditableTextRow(
            text: _bio,
            isBio: true,
            onEdit: () async {
              await _editField(
                label: "key_305b".tr(),
                initialValue: _bio ?? '',
                onSaved: (v) async {
                  await _updateProfileField('bio', v);
                  setState(() => _bio = v);
                },
              );
            },
          ),
          if (_phone != null && _phone!.isNotEmpty) const SizedBox(height: 4),
          if (_phone != null)
            _buildEditableTextRow(
              text: _formatUSPhone(_phone!),
              onEdit: () async {
                await _editField(
                  label: "key_305c".tr(),
                  initialValue: _phone ?? '',
                  onSaved: (v) async {
                    await _updateProfileField('phone', v);
                    setState(() => _phone = v);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEditableTextRow({String? text, bool isBio = false, required VoidCallback onEdit}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            text ?? '',
            maxLines: isBio ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: isBio ? null : const TextStyle(fontSize: 20),
          ),
        ),
        IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
      ],
    );
  }

  Widget _buildSettings() {
    return Column(
      children: [
        SwitchListTile(
          title: Text("key_306".tr()),
          value: _visible ?? true,
          onChanged: _toggleVisibility,
        ),
        ListTile(
          leading: const Icon(Icons.lock),
          title: Text("key_307".tr()),
          onTap: _changePassword,
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildGroupsSection() {
    return SectionCard(
      title: "key_307a".tr(),
      emptyText: "key_307b".tr(),
      children: _groups.map((group) {
        final g = group['group'] ?? {};
        return ListTile(
          leading: const Icon(Icons.group),
          title: Text(g['name'] ?? 'Unnamed Group'),
          subtitle: Text(group['role'] ?? ''),
          onTap: () {
            if (g['id'] != null) {
              context.push('/groups/${g['id']}');
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildFamilySection() {
    return SectionCard(
      title: "key_307c".tr(),
      emptyText: "key_307d".tr(),
      children: _family.map((member) {
        final isChild = member['is_child'] == true;
        final childProfile = member['child'];
        final userProfile = member['user'];
        final name = childProfile?['display_name'] ?? userProfile?['display_name'] ?? 'Unnamed';
        final qrCode = childProfile?['qr_code_url'];

        return ListTile(
          leading: Icon(isChild ? Icons.child_care : Icons.person),
          title: Text(name),
          trailing: isChild && qrCode != null ? IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              showDialog(context: context, builder: (_) => AlertDialog(content: Image.network(qrCode)));
            },
          ) : null,
        );
      }).toList(),
    );
  }

  Widget _buildPrayerRequestsSection() {
    return SectionCard(
      title: "key_307e".tr(),
      emptyText: "key_307f".tr(),
      children: _prayerRequests.map((req) {
        return ListTile(
          leading: const Icon(Icons.favorite),
          title: Text(req['request'] ?? ''),
          subtitle: Text('Status: ${req['status'] ?? 'Open'}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _removePrayerRequest(req['id'] as String),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRsvpsSection() {
    return SectionCard(
      title: "key_307g".tr(),
      emptyText: "key_307h".tr(),
      children: _eventRsvps.map((e) {
        final isAppEvent = e['source'] == 'app';
        final event = isAppEvent ? e['app_events'] : e['events'];
        final title = event?['title'] ?? 'Unnamed Event';
        final date = event?['event_date'];
        final formattedDate = date != null
            ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(date).toLocal())
            : 'Unknown date';
        return ListTile(
          leading: Icon(isAppEvent ? Icons.public : Icons.group),
          title: Text(title),
          subtitle: Text("key_309".tr(args: [e['attending_count'].toString(), formattedDate])),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const Divider(),
        ElevatedButton(
          onPressed: _logout,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text("key_310".tr()),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: _deleteAccount,
          child: Text("key_311".tr()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AppState>().profile?.id == null) {
      return Scaffold(
        appBar: AppBar(title: Text("key_304".tr())),
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.go('/landing'),
            child: Text("key_017".tr()),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("key_304".tr()),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 16),
                    _buildSettings(),
                    _buildGroupsSection(),
                    _buildFamilySection(),
                    _buildPrayerRequestsSection(),
                    _buildRsvpsSection(),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<Widget> children;
  const SectionCard({
    super.key,
    required this.title,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final content = children.isEmpty
        ? [Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(emptyText, style: const TextStyle(color: Colors.grey)))]
        : children;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title, style: Theme.of(context).textTheme.titleMedium), ...content],
        ),
      ),
    );
  }
}