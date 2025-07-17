// File: lib/features/more/pages/edit_child_profile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

class EditChildProfilePage extends StatefulWidget {
  final Map<String, dynamic> child;
  const EditChildProfilePage({super.key, required this.child});

  @override
  State<EditChildProfilePage> createState() => _EditChildProfilePageState();
}

class _EditChildProfilePageState extends State<EditChildProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _birthdayController;
  late TextEditingController _allergiesController;
  late TextEditingController _notesController;
  late TextEditingController _emergencyContactController;
  File? _photoFile;
  String? _initialPhotoUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child['display_name'] ?? '');
    _birthdayController = TextEditingController(text: widget.child['birthday'] ?? '');
    _allergiesController = TextEditingController(text: widget.child['allergies'] ?? '');
    _notesController = TextEditingController(text: widget.child['notes'] ?? '');
    _emergencyContactController = TextEditingController(text: widget.child['emergency_contact'] ?? '');
    _initialPhotoUrl = widget.child['photo_url'];
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _photoFile = File(picked.path));
  }

  Future<String?> _uploadPhoto(File file) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final filename = 'child_photos/${userId}_${const Uuid().v4()}.jpg';

    final response = await _supabase.functions.invoke('generate-presigned-url', body: {
      'filename': filename,
      'contentType': 'image/jpeg',
    });

    if (response.status != 200) return null;
    final data = response.data;
    final uploadUrl = data['uploadUrl'];
    final finalUrl = data['finalUrl'];
    if (uploadUrl == null || finalUrl == null) return null;

    final bytes = await file.readAsBytes();
    final uploadResp = await http.put(Uri.parse(uploadUrl), body: bytes, headers: {
      'Content-Type': 'image/jpeg',
    });
    return uploadResp.statusCode == 200 ? '$finalUrl?ts=${DateTime.now().millisecondsSinceEpoch}' : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final photoUrl = _photoFile != null ? await _uploadPhoto(_photoFile!) : _initialPhotoUrl;
    final updates = {
      'display_name': _nameController.text.trim(),
      'birthday': _birthdayController.text.trim(),
      'allergies': _allergiesController.text.trim(),
      'notes': _notesController.text.trim(),
      'emergency_contact': _emergencyContactController.text.trim(),
      'photo_url': photoUrl,
    };

    try {
      await _supabase.from('child_profiles').update(updates).eq('id', widget.child['id']);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Child Profile'),
        content: const Text('Are you sure you want to delete this profile? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
    try {
      await _supabase.from('family_members')
          .delete()
          .eq('child_profile_id', widget.child['id']);
      await _supabase.from('child_profiles')
          .delete()
          .eq('id', widget.child['id']);
      if (mounted) {
        context.go('/more', extra: {'familyId': widget.child['family_id']});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectBirthday() async {
    final initialDate = DateTime.tryParse(_birthdayController.text) ?? DateTime(2015);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthdayController.text = picked.toIso8601String().split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Child Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_photoFile != null || _initialPhotoUrl != null)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _photoFile != null
                      ? FileImage(_photoFile!)
                      : (_initialPhotoUrl != null ? NetworkImage(_initialPhotoUrl!) : null) as ImageProvider?,
                  child: (_photoFile == null && _initialPhotoUrl == null)
                      ? const Icon(Icons.person)
                      : null,
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo),
                label: const Text('Select Photo'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _birthdayController,
                readOnly: true,
                onTap: _selectBirthday,
                decoration: const InputDecoration(labelText: 'Birthday'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(labelText: 'Allergies'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(labelText: 'Emergency Contact'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : const Text('Save Changes'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _confirmDelete,
                child: const Text('Delete Profile'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
