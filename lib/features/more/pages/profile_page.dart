// File: lib/features/more/pages/profile_page.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ccf_app/features/auth/oidc_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_state.dart';
import '../photo_upload_service.dart';
import '../profile_service.dart';

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
  String? _displayName, _bio, _email, _photoUrl, _phone;
  bool?   _visible;
  bool    _isLoading = true;

  late ProfileService      _profileService;
  late PhotoUploadService  _photoUploadService;
  bool _bootstrapped = false;

  List<Map<String, dynamic>> _groups        = [];
  List<Map<String, dynamic>> _family        = [];
  List<Map<String, dynamic>> _prayerRequests = [];
  List<Map<String, dynamic>> _eventRsvps    = [];

  String _contentTypeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.png':  return 'image/png';
      case '.gif':  return 'image/gif';
      case '.webp': return 'image/webp';
      case '.heic': return 'image/heic';
      case '.jpeg': return 'image/jpeg';
      default:      return 'image/jpeg';
    }
  }

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
      final client        = GraphQLProvider.of(context).value;
      _photoUploadService = PhotoUploadService(client);
      _profileService     = ProfileService(client, _photoUploadService);
      _bootstrapped       = true;
      _logger.i('Dependencies ready. Calling _loadAllData.');
      _loadAllData();
    } catch (e, st) {
      _logger.e('[gp] FAILED in didChangeDependencies', error: e, stackTrace: st);
      if (mounted) _isLoading = false;
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userId = context.read<AppState>().profile?.id;
    if (userId == null) {
      if (mounted) { setState(() => _isLoading = false); context.go('/landing'); }
      return;
    }

    try {
      final bundle = await _profileService.fetchProfileBundle(userId);
      List<Map<String, dynamic>> familyRows = [];
      if (bundle.familyId != null) {
        familyRows = await _profileService.fetchFamilyMembers(bundle.familyId!);
      }
      setState(() {
        _displayName   = bundle.profile?['display_name'] as String?;
        _bio           = bundle.profile?['bio']           as String?;
        _email         = bundle.profile?['email']         as String?;
        _photoUrl      = bundle.profile?['photo_url']     as String?;
        _phone         = bundle.profile?['phone']         as String?;
        _visible       = (bundle.profile?['visible_in_directory'] as bool?) ?? true;
        _groups        = bundle.groups;
        _family        = familyRows;
        _prayerRequests = bundle.prayerRequests;
        _eventRsvps    = bundle.eventRsvps;
      });
    } catch (e, st) {
      _logger.e('Error loading profile data', error: e, stackTrace: st);
      if (mounted) _showSnackbar(context, "key_294a".tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Compresses image bytes on mobile; skips on web (no dart:io needed).
  Future<Uint8List> _compressBytes(Uint8List bytes) async {
    if (kIsWeb) return bytes;
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 600,
      minHeight: 600,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    return compressed;
  }

  Future<void> _editPhoto() async {
    _logger.i('Attempting to edit profile photo');
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    final raw        = await picked.readAsBytes();
    final compressed = await _compressBytes(raw);
    if (!mounted) return;

    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;

    try {
      final ext         = '.${picked.name.split('.').last.toLowerCase()}';
      final contentType = _contentTypeFromExt(picked.name);

      final newUrl = await _profileService.uploadAndSetProfilePhoto(
        userId, compressed, ext, contentType,
      );

      if (_photoUrl != null && _photoUrl!.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(_photoUrl!);
        final base = _photoUrl!.split('?').first;
        if (base.isNotEmpty) await CachedNetworkImage.evictFromCache(base);
      }

      if (!mounted) return;
      setState(() => _photoUrl = newUrl);
      _showSnackbar(context, "key_294e".tr());
    } catch (e, st) {
      _logger.e('Error during photo upload', error: e, stackTrace: st);
      _showSnackbar(context, "key_294f".tr());
    }
  }

  Future<void> _removePhoto() async {
    final userId      = context.read<AppState>().profile?.id;
    if (userId == null) return;
    final previousUrl = _photoUrl;
    setState(() => _photoUrl = null);
    final client = GraphQLProvider.of(context).value;
    const mutation = r'''
      mutation RemoveProfilePhoto($id: String!) {
        update_profiles_by_pk(pk_columns: {id: $id}, _set: { photo_url: null }) { id photo_url }
      }
    ''';
    try {
      final result = await client.mutate(
        MutationOptions(document: gql(mutation), variables: {'id': userId}),
      );
      if (result.hasException) throw result.exception!;
      if (!mounted) return;
      _showSnackbar(context, 'Photo removed');
      if (previousUrl != null) await CachedNetworkImage.evictFromCache(previousUrl);
    } catch (e) {
      _logger.e('Failed to remove photo', error: e);
      if (mounted) {
        setState(() => _photoUrl = previousUrl);
        _showSnackbar(context, 'Failed to remove photo');
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text("key_305".tr()),
              onTap: () { Navigator.pop(ctx); _editPhoto(); },
            ),
            if (_photoUrl != null && _photoUrl!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text('Remove Photo',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () { Navigator.pop(ctx); _removePhoto(); },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onSaved,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final newValue   = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("key_295".tr(args: [label])),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "key_295a".tr(args: [label])),
          maxLines: label.toLowerCase() == 'bio' ? 3 : 1,
          keyboardType: keyboardType,
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
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) throw Exception('User not logged in.');
    await _profileService.updateProfileField(userId, key, value);
  }

  Future<void> _toggleVisibility(bool value) async {
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;
    await _profileService.toggleVisibility(userId, value);
    setState(() => _visible = value);
  }

  Future<void> _changePassword() async {
    const String issuer = OidcAuth.issuerUrl;
    final Uri uri = Uri.parse('$issuer/ui/console/users/me/password');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnackbar(context, 'Could not open the external browser.');
    }
  }

  Future<void> _removePrayerRequest(String id) async {
    await _profileService.deletePrayerRequest(id);
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
          TextButton(
            onPressed: () => context.pop(true),
            child: Text("key_302a".tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final userId = context.read<AppState>().profile?.id;
    if (userId == null) return;
    try {
      await _profileService.deleteUserAccount(userId);
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
    final stateRead = context.read<AppState>();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _showPhotoOptions,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(_photoUrl!)
                      : null,
                  child: (_photoUrl == null || _photoUrl!.isEmpty)
                      ? Icon(Icons.person, size: 48, color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _showPhotoOptions,
                child: Text("key_305".tr()),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            _buildEditableTextRow(
              text: _displayName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              icon: Icons.edit_note,
              onEdit: () async {
                await _editField(
                  label: "key_305a".tr(),
                  initialValue: _displayName ?? '',
                  onSaved: (v) async {
                    await _updateProfileField('display_name', v);
                    stateRead.loadUserGroups();
                    setState(() => _displayName = v);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (_email != null)
              ListTile(
                leading: Icon(Icons.email, color: Theme.of(context).colorScheme.secondary),
                title: Text(_email!),
                subtitle: Text("key_305d".tr()),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            _buildEditableListTile(
              title: (_phone != null && _phone!.isNotEmpty)
                  ? _formatUSPhone(_phone!)
                  : "key_305c_add".tr(),
              subtitle: "key_305c".tr(),
              icon: Icons.phone,
              titleColor: (_phone == null || _phone!.isEmpty) ? Colors.blue : null,
              iconColor:  (_phone == null || _phone!.isEmpty) ? Colors.blue : null,
              onTap: () async {
                await _editField(
                  label: "key_305c".tr(),
                  initialValue: _phone ?? '',
                  keyboardType: TextInputType.phone,
                  onSaved: (v) async {
                    await _updateProfileField('phone', v);
                    setState(() => _phone = v);
                  },
                );
              },
            ),
            _buildEditableListTile(
              title: _bio ?? "key_305b_add".tr(),
              subtitle: "key_305b".tr(),
              icon: Icons.notes,
              isBio: true,
              titleColor: (_bio == null || _bio!.isEmpty) ? Colors.blue : null,
              iconColor:  (_bio == null || _bio!.isEmpty) ? Colors.blue : null,
              onTap: () async {
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
          ],
        ),
      ),
    );
  }

  Widget _buildEditableListTile({
    required String    title,
    required String    subtitle,
    required IconData  icon,
    required VoidCallback onTap,
    bool     isBio      = false,
    Color?   titleColor,
    Color?   iconColor,
  }) {
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.secondary;
    return ListTile(
      leading: Icon(icon, color: effectiveIconColor),
      title: Text(
        title,
        maxLines: isBio ? 3 : 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: titleColor),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.edit, size: 20),
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildEditableTextRow({
    String?    text,
    String?    title,
    TextStyle? style,
    IconData   icon  = Icons.edit,
    required VoidCallback onEdit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Column(
            children: [
              if (title != null && text != null)
                Text(title, style: Theme.of(context).textTheme.bodySmall),
              Text(
                text ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        IconButton(icon: Icon(icon, size: 20), onPressed: onEdit),
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
          onTap: () { if (g['id'] != null) context.push('/groups/${g['id']}'); },
        );
      }).toList(),
    );
  }

  Widget _buildFamilySection() {
    return SectionCard(
      title: "key_307c".tr(),
      emptyText: "key_307d".tr(),
      children: _family.map((member) {
        final isChild     = member['is_child'] == true;
        final childProfile = member['child'];
        final userProfile  = member['user'];
        final name  = childProfile?['display_name'] ?? userProfile?['display_name'] ?? 'Unnamed';
        final qrCode = childProfile?['qr_code_url'];
        return ListTile(
          leading: Icon(isChild ? Icons.child_care : Icons.person),
          title: Text(name),
          trailing: isChild && qrCode != null
              ? IconButton(
                  icon: const Icon(Icons.qr_code),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(content: CachedNetworkImage(imageUrl: qrCode)),
                  ),
                )
              : null,
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
        final event      = isAppEvent ? e['app_events'] : e['events'];
        final title      = event?['title'] ?? 'Unnamed Event';
        final date       = event?['event_date'];
        final formatted  = date != null
            ? DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(date).toLocal())
            : 'Unknown date';
        return ListTile(
          leading: Icon(isAppEvent ? Icons.public : Icons.group),
          title: Text(title),
          subtitle: Text("key_309".tr(args: [e['attending_count'].toString(), formatted])),
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
  final String        title;
  final String        emptyText;
  final List<Widget>  children;

  const SectionCard({
    super.key,
    required this.title,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final content = children.isEmpty
        ? [Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
          )]
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