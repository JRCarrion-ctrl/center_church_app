// File: lib/features/more/pages/edit_child_profile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

// Import the service used in add_child_profile.dart
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
  late PhotoUploadService _photoUploadService; // New service
  DateTime? _birthday; // Stored as DateTime, like in add_child_profile

  File? _photoFile;
  String? _initialPhotoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child['display_name'] ?? '');
    // Convert initial birthday string (YYYY-MM-DD) to DateTime
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
  }

  // Use didChangeDependencies to safely access the GraphQL client from context
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

  // REFACTOR: Use PhotoUploadService for consistency
  Future<String?> _uploadPhoto(File file) async {
    try {
      final familyId = widget.child['family_id'] as String;
      // Note: Assumes family_id is available in the child object, which is
      // needed by the service in add_child_profile.dart's implementation.
      final url = await _photoUploadService.uploadProfilePhoto(file, familyId);
      // Append timestamp like the original code did to bust cache
      return url.isEmpty
          ? null
          : '$url?ts=${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final client = GraphQLProvider.of(context).value;

    // Upload if new photo selected
    final photoUrl = _photoFile != null ? await _uploadPhoto(_photoFile!) : _initialPhotoUrl;

    // REFACTOR: Use birthday stored as DateTime?
    // Pass ISO8601 string or null for the 'date' type in Hasura.
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

    try {
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
      if (!mounted) return;
      context.go('/more', extra: {'familyId': widget.child['family_id']});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // REFACTOR: The date picker now updates the _birthday DateTime field
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
    // If you need the user id for role checks later:
    // final userId = context.read<AppState>().profile?.id;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(), // Explicitly pop
        ),
        title: Text("key_271".tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Photo section is kept for consistency in display
              if (_photoFile != null || (_initialPhotoUrl ?? '').isNotEmpty)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _photoFile != null
                      ? FileImage(_photoFile!)
                      : (_initialPhotoUrl != null && _initialPhotoUrl!.isNotEmpty
                          ? NetworkImage(_initialPhotoUrl!)
                          : null) as ImageProvider<Object>?,
                  child: (_photoFile == null && (_initialPhotoUrl ?? '').isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo),
                label: Text("key_272".tr()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "key_238a".tr()),
                validator: (v) => v == null || v.isEmpty ? "key_238b".tr() : null,
              ),
              const SizedBox(height: 12),
              // REFACTOR: Use ListTile for date selection, similar to add_child_profile.dart
              ListTile(
                title: Text(
                  _birthday != null
                      ? 'Birthday: ${_birthday!.toLocal().toString().split(' ')[0]}'
                      : 'key_271a'.tr(), // Use the existing label key if appropriate
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