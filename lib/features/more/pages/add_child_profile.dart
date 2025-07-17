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
  final _notesController = TextEditingController();
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
      // Upload child photo if selected
      String? photoUrl;
      final imageFileName = 'child_photos/${const Uuid().v4()}.jpg';
      if (_photo != null) {
        photoUrl = await _uploadPhoto(imageFileName);
      }

      // Insert child profile (qr_code_url will be updated later)
      final childResponse = await supabase.from('child_profiles').insert({
        'display_name': _nameController.text.trim(),
        'birthday': _birthday?.toIso8601String(),
        'photo_url': photoUrl,
        'allergies': _allergiesController.text.trim(),
        "notes" : _notesController.text.trim(),
        'emergency_contact': _emergencyContactController.text.trim(),
        'qr_code_url': null,
      }).select().single();

      final childId = childResponse['id'];

      // ✅ Generate a random qr_key and store it
      final qrKey = const Uuid().v4();
      await supabase.from('child_profile_qr_keys').insert({
        'child_id': childId,
        'qr_key': qrKey,
        // No expires_at — this makes it non-expiring
      });

      // ✅ Generate QR Code using qrKey, not childId
      final qrUri = Uri.https('api.qrserver.com', '/v1/create-qr-code', {
        'size': '300x300',
        'data': qrKey,
      });

      final qrResponse = await http.get(qrUri);
      if (qrResponse.statusCode != 200) throw Exception('Failed to generate QR code');

      // Upload QR code image
      final qrFileName = 'child_qrcodes/$childId.png';
      final presigned = await supabase.functions.invoke('generate-presigned-url', body: {
        'filename': qrFileName,
        'contentType': 'image/png',
      });

      final uploadUrl = presigned.data['uploadUrl'];
      final finalQrUrl = presigned.data['finalUrl'];

      if (uploadUrl == null || finalQrUrl == null) {
        throw Exception('Presigned QR code upload URL missing');
      }

      final uploadResp = await http.put(
        Uri.parse(uploadUrl),
        body: qrResponse.bodyBytes,
        headers: {'Content-Type': 'image/png'},
      );

      if (uploadResp.statusCode != 200) throw Exception('QR code upload failed');

      // Update the child profile with qr_code_url
      await supabase.from('child_profiles').update({
        'qr_code_url': finalQrUrl,
      }).eq('id', childId);

      // Link child to family
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
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emergencyContactController,
                decoration: const InputDecoration(labelText: 'Emergency Contact [Name, Phone Number]'),
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