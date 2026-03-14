// File: lib/features/more/pages/add_child_profile.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:easy_localization/easy_localization.dart';
import '../photo_upload_service.dart';
import 'package:ccf_app/app_state.dart';
import 'package:go_router/go_router.dart';

class AddChildProfilePage extends StatefulWidget {
  final String familyId;
  const AddChildProfilePage({super.key, required this.familyId});

  @override
  State<AddChildProfilePage> createState() => _AddChildProfilePageState();
}

class _AddChildProfilePageState extends State<AddChildProfilePage> {
  final _formKey                  = GlobalKey<FormState>();
  final _nameController           = TextEditingController();
  final _allergiesController      = TextEditingController();
  final _notesController          = TextEditingController();
  final _emergencyContactController = TextEditingController();
  late PhotoUploadService _photoUploadService;
  DateTime? _birthday;
  bool _isSaving = false;

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

  // Picked photo stored as bytes so it works on web and mobile.
  XFile?     _photoXFile;
  Uint8List? _photoBytes;

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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoXFile = picked;
      _photoBytes = bytes;
    });
  }

  Future<String?> _uploadPhoto() async {
    if (_photoXFile == null || _photoBytes == null) return null;
    try {
      final ext         = '.${_photoXFile!.name.split('.').last.toLowerCase()}';
      final contentType = _contentTypeFromExt(ext);
      return await _photoUploadService.uploadProfilePhoto(
        _photoBytes!, widget.familyId, ext, contentType,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _uploadQrBytes(Uint8List bytes, {required String childId}) async {
    try {
      // uploadQrCode now takes bytes directly — no temp file needed.
      return await _photoUploadService.uploadQrCode(bytes, widget.familyId, childId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = context.read<AppState>().profile?.id;
    setState(() => _isSaving = true);
    final client = GraphQLProvider.of(context).value;

    try {
      // 1) Upload child photo (optional)
      final photoUrl = await _uploadPhoto();

      // 2) Insert child profile
      const insertChild = r'''
        mutation InsertChildProfile(
          $family_id: String!, $display_name: String!, $birthday: date,
          $photo_url: String, $allergies: String, $notes: String, $emergency_contact: String
        ) {
          insert_child_profiles_one(object: {
            family_member_id: $family_id, display_name: $display_name,
            birthday: $birthday, photo_url: $photo_url,
            allergies: $allergies, notes: $notes,
            emergency_contact: $emergency_contact, qr_code_url: null
          }) { id }
        }
      ''';

      final resChild = await client.mutate(MutationOptions(
        document: gql(insertChild),
        variables: {
          'family_id':         userId,
          'display_name':      _nameController.text.trim(),
          'birthday':          _birthday?.toUtc().toIso8601String(),
          'photo_url':         photoUrl,
          'allergies':         _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
          'notes':             _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          'emergency_contact': _emergencyContactController.text.trim().isEmpty ? null : _emergencyContactController.text.trim(),
        },
      ));
      if (resChild.hasException) throw resChild.exception!;
      final childId = (resChild.data?['insert_child_profiles_one']?['id'] as String?) ?? '';
      if (childId.isEmpty) throw Exception('Missing child id');

      // 3) Generate QR key
      final qrKey = const Uuid().v4();
      const insertQrKey = r'''
        mutation InsertQrKey($child_id: uuid!, $qr_key: String!) {
          insert_child_profile_qr_keys_one(object: {child_id: $child_id, qr_key: $qr_key}) { child_id }
        }
      ''';
      final resQrKey = await client.mutate(MutationOptions(
        document: gql(insertQrKey),
        variables: {'child_id': childId, 'qr_key': qrKey},
      ));
      if (resQrKey.hasException) throw resQrKey.exception!;

      // 4) Generate QR image bytes
      final qrUri = Uri.https('api.qrserver.com', '/v1/create-qr-code', {
        'size': '300x300',
        'data': qrKey,
      });
      final qrResponse = await http.get(qrUri);
      if (qrResponse.statusCode != 200) throw Exception('Failed to generate QR code');

      // 5) Upload QR bytes directly — no temp file needed on any platform
      final qrUrl = await _uploadQrBytes(qrResponse.bodyBytes, childId: childId);
      if (qrUrl == null) throw Exception('QR code upload failed');

      // 6) Update child with QR URL
      const updateChildQr = r'''
        mutation UpdateChildQrUrl($id: uuid!, $qr_url: String!) {
          update_child_profiles_by_pk(pk_columns: {id: $id}, _set: {qr_code_url: $qr_url}) { id }
        }
      ''';
      final resUpdate = await client.mutate(MutationOptions(
        document: gql(updateChildQr),
        variables: {'id': childId, 'qr_url': qrUrl},
      ));
      if (resUpdate.hasException) throw resUpdate.exception!;

      // 7) Link child to family
      const linkToFamily = r'''
        mutation LinkChildToFamily($family_id: uuid!, $child_id: uuid!) {
          insert_family_members_one(object: {
            family_id: $family_id, child_profile_id: $child_id,
            is_child: True, relationship: "Child", status: "accepted"
          }) { id }
        }
      ''';
      final resLink = await client.mutate(MutationOptions(
        document: gql(linkToFamily),
        variables: {'family_id': widget.familyId, 'child_id': childId},
      ));
      if (resLink.hasException) throw resLink.exception!;

      if (!mounted) return;
      Navigator.of(context).pop();
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text("key_238".tr()),
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
                  // Image.memory works on all platforms; no dart:io needed.
                  backgroundImage: _photoBytes != null ? MemoryImage(_photoBytes!) : null,
                  child: _photoBytes == null ? const Icon(Icons.add_a_photo, size: 40) : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "key_238a".tr()),
                validator: (v) => v == null || v.trim().isEmpty ? "key_238b".tr() : null,
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
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : Text("key_239".tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}