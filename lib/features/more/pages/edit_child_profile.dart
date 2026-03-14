// File: lib/features/more/pages/edit_child_profile.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../photo_upload_service.dart';

class EditChildProfilePage extends StatefulWidget {
  final Map<String, dynamic> child;
  const EditChildProfilePage({super.key, required this.child});

  @override
  State<EditChildProfilePage> createState() => _EditChildProfilePageState();
}

class _EditChildProfilePageState extends State<EditChildProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _picker  = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _allergiesController;
  late TextEditingController _notesController;
  late TextEditingController _emergencyContactController;
  late PhotoUploadService    _photoUploadService;
  DateTime? _birthday;

  XFile?     _photoXFile;
  Uint8List? _photoBytes;
  String?    _initialPhotoUrl;
  bool       _saving = false;
  String?    _cachedFamilyId;

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
    _nameController           = TextEditingController(text: widget.child['display_name'] ?? '');
    _allergiesController      = TextEditingController(text: widget.child['allergies'] ?? '');
    _notesController          = TextEditingController(text: widget.child['notes'] ?? '');
    _emergencyContactController = TextEditingController(text: widget.child['emergency_contact'] ?? '');
    _initialPhotoUrl          = widget.child['photo_url'];
    _cachedFamilyId           = widget.child['family_id']?.toString();

    final birthdayString = widget.child['birthday'];
    if (birthdayString != null) {
      try { _birthday = DateTime.tryParse(birthdayString); } catch (_) {}
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = GraphQLProvider.of(context).value;
    _photoUploadService = PhotoUploadService(client);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { _photoXFile = picked; _photoBytes = bytes; });
  }

  Future<String?> _fetchFamilyId() async {
    if (_cachedFamilyId != null) return _cachedFamilyId;
    final client = GraphQLProvider.of(context).value;
    const query = r'''
      query GetChildFamilyId($child_id: uuid!) {
        family_members(where: {child_profile_id: {_eq: $child_id}}, limit: 1) { family_id }
      }
    ''';
    try {
      final res = await client.query(QueryOptions(
        document: gql(query),
        variables: {'child_id': widget.child['id']},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (res.hasException) throw res.exception!;
      final rows = res.data?['family_members'] as List?;
      if (rows != null && rows.isNotEmpty) {
        _cachedFamilyId = rows.first['family_id'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching family ID: $e');
    }
    return _cachedFamilyId;
  }

  Future<String?> _uploadPhoto() async {
    if (_photoXFile == null || _photoBytes == null) return null;
    try {
      final familyId = _cachedFamilyId ?? await _fetchFamilyId();
      if (familyId == null || familyId.isEmpty) {
        throw Exception('Family ID could not be found for this child.');
      }
      final ext         = '.${_photoXFile!.name.split('.').last.toLowerCase()}';
      final contentType = _contentTypeFromExt(_photoXFile!.name);
      final url = await _photoUploadService.uploadProfilePhoto(
        _photoBytes!, familyId, ext, contentType,
      );
      return url.isEmpty ? null : '$url?ts=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('Photo upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
      }
      return null;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final client = GraphQLProvider.of(context).value;

    try {
      String? photoUrl = _initialPhotoUrl;
      if (_photoXFile != null) {
        final uploaded = await _uploadPhoto();
        if (uploaded != null) photoUrl = uploaded;
      }

      final birthday = _birthday?.toIso8601String().split('T').first;

      const mUpdate = r'''
        mutation UpdateChildProfile(
          $id: uuid!, $display_name: String!, $birthday: date,
          $allergies: String, $notes: String, $emergency_contact: String, $photo_url: String
        ) {
          update_child_profiles_by_pk(
            pk_columns: { id: $id },
            _set: {
              display_name: $display_name, birthday: $birthday,
              allergies: $allergies, notes: $notes,
              emergency_contact: $emergency_contact, photo_url: $photo_url
            }
          ) { id }
        }
      ''';

      final res = await client.mutate(MutationOptions(
        document: gql(mUpdate),
        variables: {
          'id':                widget.child['id'],
          'display_name':      _nameController.text.trim(),
          'birthday':          birthday,
          'allergies':         _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
          'notes':             _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          'emergency_contact': _emergencyContactController.text.trim().isEmpty ? null : _emergencyContactController.text.trim(),
          'photo_url':         photoUrl,
        },
      ));
      if (res.hasException) throw res.exception!;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("key_267".tr()),
        content: Text("key_268".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("key_269".tr())),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("key_270".tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteChild();
  }

  Future<void> _deleteChild() async {
    setState(() => _saving = true);
    final client = GraphQLProvider.of(context).value;
    const m = r'''
      mutation DeleteChild($child_id: uuid!) {
        delete_family_members(where: { child_profile_id: { _eq: $child_id } }) { affected_rows }
        delete_child_profiles_by_pk(id: $child_id) { id }
      }
    ''';
    try {
      final res = await client.mutate(
        MutationOptions(document: gql(m), variables: {'child_id': widget.child['id']}),
      );
      if (res.hasException) throw res.exception!;
      final familyId = _cachedFamilyId ?? widget.child['family_id'] ?? await _fetchFamilyId();
      if (!mounted) return;
      if (familyId != null) {
        context.go('/more/family', extra: {'familyId': familyId});
      } else {
        context.go('/more');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectBirthday() async {
    final initial = _birthday ?? DateTime(DateTime.now().year - 9, 1, 1);
    final picked  = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    // Determine the avatar image provider without dart:io.
    ImageProvider<Object>? avatarImage;
    if (_photoBytes != null) {
      avatarImage = MemoryImage(_photoBytes!);
    } else if (_initialPhotoUrl != null && _initialPhotoUrl!.isNotEmpty) {
      avatarImage = NetworkImage(_initialPhotoUrl!);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text("key_271".tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: avatarImage,
                  child: avatarImage == null ? const Icon(Icons.add_a_photo, size: 40) : null,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "key_238a".tr()),
                validator: (v) => v == null || v.isEmpty ? "key_238b".tr() : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  _birthday != null
                      ? 'Birthday: ${_birthday!.toLocal().toString().split(' ')[0]}'
                      : 'key_271a'.tr(),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectBirthday,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _allergiesController,
                decoration: InputDecoration(labelText: "key_238c".tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: "key_238d".tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyContactController,
                decoration: InputDecoration(labelText: "key_238e".tr()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : Text("key_273".tr()),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _confirmDelete,
                child: Text("key_274".tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}