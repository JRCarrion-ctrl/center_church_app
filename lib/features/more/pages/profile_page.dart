// file: lib/features/more/pages/profile_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final Logger _logger = Logger();

  String? displayName, bio, photoUrl, phone;
  String? familyId;
  bool? visible;
  bool isLoading = true;
  String formatUSPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return input;
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }

  List<Map<String, dynamic>> groups = [];
  List<Map<String, dynamic>> family = [];
  List<Map<String, dynamic>> prayerRequests = [];
  List<Map<String, dynamic>> eventRsvps = [];

  @override
  void initState() {
    super.initState();
    _kickOutIfLoggedOut();
  }

  Future<void> _kickOutIfLoggedOut() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      // Defer navigation until after first frame to avoid context issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go('/landing');
      });
      return;
    }
    // Only load data if authenticated
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      // Shouldn’t happen because of the gate, but don’t hang the spinner
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final familiesData = await supabase
          .from('family_members')
          .select('family_id')
          .eq('user_id', userId)
          .eq('status', 'accepted')
          .maybeSingle();

      final String? fetchedFamilyId = familiesData?['family_id'];
      familyId = fetchedFamilyId;

      final userProfile = await supabase
          .from('profiles')
          .select('display_name, bio, photo_url, visible_in_directory, phone')
          .eq('id', userId)
          .maybeSingle();

      final groupsData = await supabase
          .from('group_memberships')
          .select('role, groups(id, name)')
          .eq('user_id', userId);

      final List<Map<String, dynamic>> familyData = fetchedFamilyId == null
          ? []
          : List<Map<String, dynamic>>.from(await supabase
              .from('family_members')
              .select('id, relationship, status, is_child, user_id, child:child_profiles(display_name, qr_code_url), user:profiles!family_members_user_id_fkey(display_name, photo_url)')
              .eq('family_id', fetchedFamilyId)
              .eq('status', 'accepted'));

      final prayersData = await supabase
          .from('prayer_requests')
          .select('id, request, created_at, expires_at, status')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final groupRSVPs = await supabase
          .from('event_attendance')
          .select('attending_count, created_at, group_events(title, event_date)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final appRSVPs = await supabase
          .from('app_event_attendance')
          .select('attending_count, created_at, app_events(title, event_date)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final combinedRsvps = [
        ...groupRSVPs.map((r) => {...r, 'source': 'group'}),
        ...appRSVPs.map((r) => {...r, 'source': 'app'}),
      ];

      setState(() {
        displayName = userProfile?['display_name'];
        bio = userProfile?['bio'];
        photoUrl = userProfile?['photo_url'];
        phone = userProfile?['phone'];
        visible = userProfile?['visible_in_directory'] ?? true;
        groups = List<Map<String, dynamic>>.from(groupsData);
        family = familyData;
        prayerRequests = List<Map<String, dynamic>>.from(prayersData);
        eventRsvps = List<Map<String, dynamic>>.from(combinedRsvps);
        isLoading = false;
      });
    } catch (e) {
      _logger.e('Error in _loadAll', error: e, stackTrace: StackTrace.current);
      if (!mounted) return;
      _showSnackbar("key_294a".tr());
      setState(() => isLoading = false);
    }
  }

  Future<File> _compressImage(File file) async {
    final targetPath = file.path.replaceFirst(RegExp(r'\.(jpg|jpeg|png|heic|webp)$'), '_compressed.jpg');
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 600,
      minHeight: 600,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    return File(targetPath)..writeAsBytesSync(compressedBytes!);
  }

  Future<void> _editPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    File file = File(picked.path);
    file = await _compressImage(file);

    final userId = supabase.auth.currentUser!.id;
    final filename = 'profile_photos/$userId.jpg';

    try {
      // 1. Get presigned upload URL and public CloudFront URL from your edge function
      final response = await supabase.functions.invoke(
        'generate-presigned-url',
        body: {
          'filename': filename,
          'contentType': 'image/jpeg',
        },
      );

      if (response.status != 200) {
        _showSnackbar("key_294b".tr());
        return;
      }
      final data = response.data;
      final uploadUrl = data['uploadUrl'];
      final finalUrl = data['finalUrl'];

      if (uploadUrl == null || finalUrl == null) {
        _showSnackbar("key_294c".tr());
        return;
      }

      // 2. Upload the file to S3 using the presigned URL
      final fileBytes = await file.readAsBytes();
      final uploadResp = await http.put(
        Uri.parse(uploadUrl),
        body: fileBytes,
        headers: {'Content-Type': 'image/jpeg'},
      );
      if (uploadResp.statusCode != 200) {
        _showSnackbar("key_294d".tr());
        return;
      }

      // 3. Save the public CloudFront URL in your profiles table
      final cacheBustedUrl = '$finalUrl?ts=${DateTime.now().millisecondsSinceEpoch}';
      CachedNetworkImage.evictFromCache(photoUrl!);
      await supabase.from('profiles').update({'photo_url': cacheBustedUrl}).eq('id', userId);
      setState(() => photoUrl = cacheBustedUrl);
      _showSnackbar("key_294e".tr());
    } catch (e, st) {
      _logger.e('Error uploading photo', error: e, stackTrace: st);
      _showSnackbar("key_294f".tr());
    }
  }

  Future<void> _editField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onSaved,
  }) async {
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
          TextButton(
            onPressed: () => context.pop(controller.text.trim()),
            child: Text("key_297".tr()),
          ),
        ],
      ),
    );
    if (newValue == null || newValue.isEmpty) return;
    onSaved(newValue);
  }

  Future<void> _updateProfileField(String key, String value) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await supabase.from('profiles').update({key: value}).eq('id', userId);
    }
  }

  Future<void> _toggleVisibility(bool value) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      await supabase.from('profiles').update({'visible_in_directory': value}).eq('id', userId);
    }
    setState(() => visible = value);
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_298".tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "key_298a".tr()),
            ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "key_298b".tr()),
            ),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "key_298c".tr()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("key_299".tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text("key_300".tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      _showSnackbar("key_300a".tr());
      return;
    }

    try {
      final email = supabase.auth.currentUser?.email;
      if (email == null) throw Exception('Email not found');

      // Reauthenticate to verify current password
      final signInRes = await supabase.auth.signInWithPassword(email: email, password: currentPassword);
      if (signInRes.user == null) throw Exception('Current password is incorrect.');

      final updateRes = await supabase.auth.updateUser(UserAttributes(password: newPassword));
      if (updateRes.user != null) {
        _showSnackbar("key_300b".tr());
      } else {
        throw Exception('Password update failed.');
      }
    } catch (e) {
      _logger.e('Failed to update password', error: e);
      _showSnackbar("key_300c".tr());
    }
  }


  Future<void> _removePrayerRequest(String id) async {
    await supabase.from('prayer_requests').delete().eq('id', id);
    setState(() => prayerRequests.removeWhere((r) => r['id'] == id));
  }

  Future<void> _logout() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await supabase.auth.signOut();
    await appState.signOut();

    if (mounted) {
      context.go('/landing');
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("key_301".tr()),
        content: Text("key_302".tr()),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: Text("key_303".tr())),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text("key_302a".tr(), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      final response = await supabase.functions.invoke('delete-user-account', body: {
        'user_id': userId,
      });
      if (response.status != 200) {
        _showSnackbar("key_207".tr());
        return;
      }
    }
    await supabase.auth.signOut();
    if (mounted) {
      context.go('/landing');
    }
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // Defensive fallback: if somehow here without a user, nudge to login
    if (supabase.auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text("key_304".tr())),
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.go('/landing'),
            child: Text("key_017".tr()), // "Login"
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("key_304".tr()),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _editPhoto,
                            child: CircleAvatar(
                              radius: 48,
                              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                                ? CachedNetworkImageProvider(photoUrl!)
                                : null,
                              child: (photoUrl == null || photoUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 48)
                                : null,
                            ),
                          ),
                          TextButton(
                            onPressed: _editPhoto,
                            child: Text("key_305".tr()),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(displayName ?? '', style: const TextStyle(fontSize: 20)),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editField(
                                  label: "key_305a".tr(),
                                  initialValue: displayName ?? '',
                                  onSaved: (v) async {
                                    await _updateProfileField('display_name', v);
                                    setState(() => displayName = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(child: Text(bio ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editField(
                                  label: "key_305b".tr(),
                                  initialValue: bio ?? '',
                                  onSaved: (v) async {
                                    await _updateProfileField('bio', v);
                                    setState(() => bio = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (phone != null && phone!.isNotEmpty) const SizedBox(height: 4),
                          if (phone != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(formatUSPhone(phone!), style: const TextStyle(fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editField(
                                    label: "key_305c".tr(),
                                    initialValue: phone ?? '',
                                    onSaved: (v) async {
                                      await _updateProfileField('phone', v);
                                      setState(() => phone = v);
                                    },
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: Text("key_306".tr()),
                      value: visible ?? true,
                      onChanged: _toggleVisibility,
                    ),
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: Text("key_307".tr()),
                      onTap: _changePassword,
                    ),
                    const Divider(),

                    // Groups section
                    SectionCard(
                      title: "key_307a".tr(),
                      emptyText: "key_307b".tr(),
                      children: groups.map((group) {
                        final g = group['groups'] ?? {};
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
                    ),

                    // Family section
                    SectionCard(
                      title: "key_307c".tr(),
                      emptyText: "key_307d".tr(),
                      children: family.map((member) {
                        final isChild = member['is_child'] == true;
                        final childProfile = member['child'];
                        final userProfile = member['user'];
                        final name = childProfile?['display_name'] ?? userProfile?['display_name'] ?? 'Unnamed';
                        final qrCode = childProfile?['qr_code_url'];

                        return ListTile(
                          leading: Icon(isChild ? Icons.child_care : Icons.person),
                          title: Text(name),
                          trailing: isChild && qrCode != null
                              ? IconButton(
                                  icon: const Icon(Icons.qr_code),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        content: Image.network(qrCode),
                                      ),
                                    );
                                  },
                                )
                              : null,
                        );
                      }).toList(),
                    ),

                    // Prayer Requests section
                    SectionCard(
                      title: "key_307e".tr(),
                      emptyText: "key_307f".tr(),
                      children: prayerRequests.map((req) {
                        return ListTile(
                          leading: Icon(Icons.favorite),
                          title: Text(req['request'] ?? ''),
                          subtitle: Text('Status: ${req['status'] ?? 'Open'}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removePrayerRequest(req['id']),
                          ),
                        );
                      }).toList(),
                    ),

                    // Event RSVPs section
                    SectionCard(
                      title: "key_307g".tr(),
                      emptyText: "key_307h".tr(),
                      children: eventRsvps.map((e) {
                        final isAppEvent = e['source'] == 'app';
                        final event = isAppEvent ? e['app_events'] : e['group_events'];
                        final title = event?['title'] ?? 'Unnamed Event';
                        final date = event?['event_date'];
                        final formattedDate = date != null
                            ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(date).toLocal())
                            : 'Unknown date';

                        return ListTile(
                          leading: Icon(isAppEvent ? Icons.public : Icons.group),
                          title: Text(title),
                          subtitle: Text("key_309".tr(args: [e['attending_count'].toString(),formattedDate,])),
                        );

                      }).toList(),
                    ),

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
                ),
              ),
            ),
    );
  }
}

// Helper widget for section cards
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
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            ...children.isEmpty
                ? [Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(emptyText, style: TextStyle(color: Colors.grey)),
                  )]
                : children,
          ],
        ),
      ),
    );
  }
}
