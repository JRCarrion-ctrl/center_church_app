// File: lib/features/more/pages/add_child_profile.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/core/media/presigned_uploader.dart';

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

  bool _isSaving = false;
  File? _photo;

  @override
  void dispose() {
    _nameController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<String?> _uploadPhotoWithPresigned(File file) async {
    try {
      // Keep the random name behavior
      final logicalId = const Uuid().v4();
      final url = await PresignedUploader.upload(
        file: file,
        keyPrefix: 'child_photos',
        logicalId: logicalId,
      );
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _uploadQrBytes(Uint8List bytes, {required String logicalId}) async {
    try {
      // Write bytes to a temp file, then reuse PresignedUploader
      final dir = await getTemporaryDirectory();
      final tmp = File('${dir.path}/$logicalId.png');
      await tmp.writeAsBytes(bytes);
      final url = await PresignedUploader.upload(
        file: tmp,
        keyPrefix: 'child_qrcodes',
        logicalId: logicalId,
      );
      // Best effort cleanup
      try { if (await tmp.exists()) await tmp.delete(); } catch (_) {}
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final client = GraphQLProvider.of(context).value;

    try {
      // 1) Upload child photo (optional)
      String? photoUrl;
      if (_photo != null) {
        photoUrl = await _uploadPhotoWithPresigned(_photo!);
      }

      // 2) Insert child profile (qr_code_url null for now)
      const insertChild = r'''
        mutation InsertChildProfile(
          $display_name: String!,
          $birthday: timestamptz,
          $photo_url: String,
          $allergies: String,
          $notes: String,
          $emergency_contact: String
        ) {
          insert_child_profiles_one(object: {
            display_name: $display_name,
            birthday: $birthday,
            photo_url: $photo_url,
            allergies: $allergies,
            notes: $notes,
            emergency_contact: $emergency_contact,
            qr_code_url: null
          }) { id }
        }
      ''';

      final resChild = await client.mutate(
        MutationOptions(
          document: gql(insertChild),
          variables: {
            'display_name': _nameController.text.trim(),
            'birthday': _birthday?.toUtc().toIso8601String(),
            'photo_url': photoUrl,
            'allergies': _allergiesController.text.trim().isEmpty
                ? null
                : _allergiesController.text.trim(),
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            'emergency_contact': _emergencyContactController.text.trim().isEmpty
                ? null
                : _emergencyContactController.text.trim(),
          },
        ),
      );
      if (resChild.hasException) throw resChild.exception!;
      final childId = (resChild.data?['insert_child_profiles_one']?['id'] as String?) ?? '';
      if (childId.isEmpty) throw Exception('Missing child id');

      // 3) Generate a random qr_key and store it
      final qrKey = const Uuid().v4();
      const insertQrKey = r'''
        mutation InsertQrKey($child_id: uuid!, $qr_key: String!) {
          insert_child_profile_qr_keys_one(object: {
            child_id: $child_id,
            qr_key: $qr_key
          }) { child_id }
        }
      ''';
      final resQrKey = await client.mutate(
        MutationOptions(
          document: gql(insertQrKey),
          variables: {'child_id': childId, 'qr_key': qrKey},
        ),
      );
      if (resQrKey.hasException) throw resQrKey.exception!;

      // 4) Generate QR image bytes for the qrKey
      final qrUri = Uri.https('api.qrserver.com', '/v1/create-qr-code', {
        'size': '300x300',
        'data': qrKey,
      });
      final qrResponse = await http.get(qrUri);
      if (qrResponse.statusCode != 200) throw Exception('Failed to generate QR code');

      // 5) Upload QR image to storage and get a public URL
      final qrUrl = await _uploadQrBytes(qrResponse.bodyBytes, logicalId: childId);
      if (qrUrl == null) throw Exception('QR code upload failed');

      // 6) Update child with qr_code_url
      const updateChildQr = r'''
        mutation UpdateChildQrUrl($id: uuid!, $qr_url: String!) {
          update_child_profiles_by_pk(pk_columns: {id: $id}, _set: {qr_code_url: $qr_url}) { id }
        }
      ''';
      final resUpdate = await client.mutate(
        MutationOptions(
          document: gql(updateChildQr),
          variables: {'id': childId, 'qr_url': qrUrl},
        ),
      );
      if (resUpdate.hasException) throw resUpdate.exception!;

      // 7) Link child to family (status accepted)
      const linkToFamily = r'''
        mutation LinkChildToFamily($family_id: uuid!, $child_id: uuid!) {
          insert_family_members_one(object: {
            family_id: $family_id,
            child_profile_id: $child_id,
            is_child: True,
            relationship: "Child",
            status: "accepted"
          }) { id }
        }
      ''';
      final resLink = await client.mutate(
        MutationOptions(
          document: gql(linkToFamily),
          variables: {'family_id': widget.familyId, 'child_id': childId},
        ),
      );
      if (resLink.hasException) throw resLink.exception!;

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_238".tr())),
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
                decoration: InputDecoration(labelText: "key_238a".tr()),
                validator: (value) => value == null || value.trim().isEmpty ? "key_238b".tr() : null,
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
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  _birthday != null
                      ? 'Birthday: ${_birthday!.toLocal().toString().split(' ')[0]}'
                      : 'Select Birthday',
                ),
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
                child: _isSaving ? const CircularProgressIndicator() : Text("key_239".tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
