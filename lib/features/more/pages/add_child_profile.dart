// File: lib/features/more/pages/add_child_profile.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class AddChildProfilePage extends StatefulWidget {
  final String familyId;
  const AddChildProfilePage({super.key, required this.familyId});

  @override
  State<AddChildProfilePage> createState() => _AddChildProfilePageState();
}

class _AddChildProfilePageState extends State<AddChildProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  DateTime? _birthday;
  final supabase = Supabase.instance.client;
  bool _isSaving = false;
  File? _photo;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<String?> _uploadPhoto(String filename) async {
    final response = await supabase.functions.invoke(
      'generate-presigned-url',
      body: {'filename': filename, 'contentType': 'image/jpeg'},
    );

    if (response.status != 200) return null;
    final uploadUrl = response.data['uploadUrl'];
    final finalUrl = response.data['finalUrl'];
    if (uploadUrl == null || finalUrl == null) return null;

    final fileBytes = await _photo!.readAsBytes();
    final uploadResp = await http.put(
      Uri.parse(uploadUrl),
      body: fileBytes,
      headers: {'Content-Type': 'image/jpeg'},
    );

    return uploadResp.statusCode == 200 ? finalUrl : null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      String? photoUrl;
      String filename = 'child_photos/${const Uuid().v4()}.jpg';
      if (_photo != null) {
        photoUrl = await _uploadPhoto(filename);
      }

      final childResponse = await supabase.from('child_profiles').insert({
        'display_name': _nameController.text.trim(),
        'birthday': _birthday?.toIso8601String(),
        'photo_url': photoUrl,
        'allergies': _allergiesController.text.trim(),
        'emergency_contact': _emergencyContactController.text.trim(),
        'qr_code_url': null, // Set if needed
      }).select().single();

      final childId = childResponse['id'];

      await supabase.from('family_members').insert({
        'family_id': widget.familyId,
        'child_profile_id': childId,
        'is_child': true,
        'relationship': 'Child',
        'status': 'accepted',
      });

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Child Profile')),
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
                  backgroundImage: _photo != null ? FileImage(_photo!) : null,
                  child: _photo == null ? const Icon(Icons.add_a_photo, size: 40) : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Child Name'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(labelText: 'Allergies (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(labelText: 'Emergency Contact'),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(_birthday != null
                    ? 'Birthday: ${_birthday!.toLocal().toString().split(' ')[0]}'
                    : 'Select Birthday'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _birthday = picked);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving ? const CircularProgressIndicator() : const Text('Add Child'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}