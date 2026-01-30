// File: lib/features/more/pages/edit_child_profile.dart
import 'dart:io';
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
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _allergiesController;
  late TextEditingController _notesController;
  late TextEditingController _emergencyContactController;
  
  late PhotoUploadService _photoUploadService;
  DateTime? _birthday; 

  File? _photoFile;
  String? _initialPhotoUrl;
  bool _saving = false;
  
  // Cache the familyId if we have to fetch it
  String? _cachedFamilyId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child['display_name'] ?? '');
    
    final birthdayString = widget.child['birthday'];
    if (birthdayString != null) {
      try {
        _birthday = DateTime.tryParse(birthdayString);
      } catch (_) {
        _birthday = null;
      }
    }
    
    _allergiesController = TextEditingController(text: widget.child['allergies'] ?? '');
    _notesController = TextEditingController(text: widget.child['notes'] ?? '');
    _emergencyContactController = TextEditingController(text: widget.child['emergency_contact'] ?? '');
    _initialPhotoUrl = widget.child['photo_url'];
    
    // Initialize cached ID from widget args if available
    _cachedFamilyId = widget.child['family_id']?.toString();
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
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }
  
  // --- NEW: Helper to fetch Family ID if missing ---
  Future<String?> _fetchFamilyId() async {
    if (_cachedFamilyId != null) return _cachedFamilyId;

    final client = GraphQLProvider.of(context).value;
    const query = r'''
      query GetChildFamilyId($child_id: uuid!) {
        family_members(where: {child_profile_id: {_eq: $child_id}}, limit: 1) {
          family_id
        }
      }
    ''';

    try {
      final res = await client.query(
        QueryOptions(
          document: gql(query), 
          variables: {'child_id': widget.child['id']},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (res.hasException) throw res.exception!;
      
      final rows = res.data?['family_members'] as List?;
      if (rows != null && rows.isNotEmpty) {
        _cachedFamilyId = rows.first['family_id'] as String?;
      }
    } catch (e) {
      debugPrint("Error fetching family ID: $e");
    }
    
    return _cachedFamilyId;
  }

  Future<String?> _uploadPhotoWithPresigned(File file) async {
    try {
      // 1. Try to get ID from widget or cache
      String? familyId = _cachedFamilyId;
      
      // 2. If missing, fetch it from backend
      if (familyId == null || familyId.isEmpty) {
        familyId = await _fetchFamilyId();
      }

      if (familyId == null || familyId.isEmpty) {
        throw Exception("Family ID could not be found for this child.");
      }

      final url = await _photoUploadService.uploadProfilePhoto(file, familyId);
      
      return url.isEmpty
          ? null
          : '$url?ts=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint("Photo upload error: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Photo upload failed: $e")),
        );
      }
      return null;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final client = GraphQLProvider.of(context).value;

    try {
      // 1. Upload new photo if selected
      String? photoUrl = _initialPhotoUrl;
      if (_photoFile != null) {
        final uploadedUrl = await _uploadPhotoWithPresigned(_photoFile!);
        if (uploadedUrl != null) {
          photoUrl = uploadedUrl;
        }
      }

      // 2. Prepare Variables
      final birthday = _birthday?.toIso8601String().split('T').first;

      const mUpdate = r'''
        mutation UpdateChildProfile(
          $id: uuid!,
          $display_name: String!,
          $birthday: date,
          $allergies: String,
          $notes: String,
          $emergency_contact: String,
          $photo_url: String
        ) {
          update_child_profiles_by_pk(
            pk_columns: { id: $id },
            _set: {
              display_name: $display_name,
              birthday: $birthday,
              allergies: $allergies,
              notes: $notes,
              emergency_contact: $emergency_contact,
              photo_url: $photo_url
            }
          ) { id }
        }
      ''';

      final vars = {
        'id': widget.child['id'],
        'display_name': _nameController.text.trim(),
        'birthday': birthday,
        'allergies': _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'emergency_contact': _emergencyContactController.text.trim().isEmpty ? null : _emergencyContactController.text.trim(),
        'photo_url': photoUrl,
      };

      // 3. Execute Mutation
      final res = await client.mutate(
        MutationOptions(document: gql(mUpdate), variables: vars),
      );

      if (res.hasException) {
        throw res.exception!;
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("key_269".tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("key_270".tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteChild();
    }
  }

  Future<void> _deleteChild() async {
    setState(() => _saving = true);
    final client = GraphQLProvider.of(context).value;

    const m = r'''
      mutation DeleteChild($child_id: uuid!) {
        delete_family_members(where: { child_profile_id: { _eq: $child_id } }) {
          affected_rows
        }
        delete_child_profiles_by_pk(id: $child_id) { id }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(document: gql(m), variables: {'child_id': widget.child['id']}),
      );
      if (res.hasException) throw res.exception!;
      
      // Try to ensure we have a familyId for the redirect, otherwise assume current user context 
      // or just go back safely.
      String? familyId = _cachedFamilyId ?? widget.child['family_id'];
      familyId ??= await _fetchFamilyId();

      if (!mounted) return;
      
      if (familyId != null) {
        context.go('/more/family', extra: {'familyId': familyId});
      } else {
        // Fallback navigation if we really can't find where to go
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
    final today = DateTime.now();
    final initial = _birthday ?? DateTime(today.year - 9, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(), 
        ),
        title: Text("key_271".tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Photo Area
              GestureDetector(
                onTap: _pickPhoto,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: _photoFile != null
                      ? FileImage(_photoFile!)
                      : (_initialPhotoUrl != null && _initialPhotoUrl!.isNotEmpty
                          ? NetworkImage(_initialPhotoUrl!)
                          : null) as ImageProvider<Object>?,
                  child: (_photoFile == null && (_initialPhotoUrl ?? '').isEmpty)
                      ? const Icon(Icons.add_a_photo, size: 40)
                      : null,
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