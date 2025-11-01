// File: lib/features/home/app_announcement_form_modal.dart
import 'package:ccf_app/features/calendar/event_photo_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import '../../../app_state.dart';
import '../../../core/media/image_picker_field.dart';
class AppAnnouncementFormModal extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const AppAnnouncementFormModal({super.key, this.existing});

  @override
  State<AppAnnouncementFormModal> createState() => _AppAnnouncementFormModalState();
}

class _AppAnnouncementFormModalState extends State<AppAnnouncementFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime? _scheduled;

  File? _localImageFile; // <-- NEW STATE
  bool _imageRemoved = false; // <-- NEW STATE
  String? _imageUrl; // Existing image URL

  late EventPhotoStorageService _mediaService; // <-- NEW SERVICE
  bool saving = false;

  GraphQLClient? _gql;
  String? _userId;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _title.text = (a['title'] ?? '') as String;
      _body.text = (a['body'] ?? '') as String;
      _imageUrl = a['image_url'] as String?; // Capture existing image URL
      final published = a['published_at'];
      if (published is String && published.isNotEmpty) {
        _scheduled = DateTime.tryParse(published)?.toLocal();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gql ??= GraphQLProvider.of(context).value;
    _userId ??= context.read<AppState>().profile?.id;
    
    if (_gql != null) {
      _mediaService = EventPhotoStorageService(_gql!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduled ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduled ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduled = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_userId == null || _gql == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_190".tr())));
      return;
    }

    setState(() => saving = true);

    String? finalImageUrl = _imageUrl;
    final logicalId = widget.existing?['id'] as String? ?? 'new'; // Unique ID for S3 path

    // --- NEW IMAGE UPLOAD LOGIC ---
    if (_imageRemoved && _localImageFile == null) {
      finalImageUrl = null;
    } else if (_localImageFile != null) {
      try {
        finalImageUrl = await _mediaService.uploadEventPhoto(
          file: _localImageFile!,
          keyPrefix: 'app_announcements',
          logicalId: logicalId,
        );
      } catch (e) {
        debugPrint('Error uploading image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to upload image")),
          );
          setState(() => saving = false);
          return;
        }
      }
    }
    // --- END NEW IMAGE UPLOAD LOGIC ---

    final payload = {
      'title': _title.text.trim(),
      'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
      'published_at': (_scheduled ?? DateTime.now()).toUtc().toIso8601String(),
      'image_url': finalImageUrl,
    };

    const insertMutation = r'''
      mutation InsertAppAnnouncement($title: String!, $body: String, $published_at: timestamptz!, $created_by: String!, $image_url: String) {
        insert_app_announcements_one(object: {
          title: $title,
          body: $body,
          published_at: $published_at,
          created_by: $created_by,
          image_url: $image_url
        }) { id }
      }
    ''';

    const updateMutation = r'''
      mutation UpdateAppAnnouncement($id: uuid!, $title: String!, $body: String, $published_at: timestamptz!, $image_url: String) {
        update_app_announcements_by_pk(pk_columns: {id: $id}, _set: {
          title: $title,
          body: $body,
          published_at: $published_at,
          image_url: $image_url
        }) { id }
      }
    ''';

    try {
      if (widget.existing != null) {
        final vars = {
          'id': widget.existing!['id'],
          'title': payload['title'],
          'body': payload['body'],
          'published_at': payload['published_at'],
          'image_url': payload['image_url'],
        };
        final res = await _gql!.mutate(MutationOptions(document: gql(updateMutation), variables: vars));
        if (res.hasException) throw res.exception!;
      } else {
        final vars = {
          'title': payload['title'],
          'body': payload['body'],
          'published_at': payload['published_at'],
          'created_by': _userId,
          'image_url': payload['image_url'], // <-- ADDED
        };
        final res = await _gql!.mutate(MutationOptions(document: gql(insertMutation), variables: vars));
        if (res.hasException) throw res.exception!;
      }

      if (mounted) Navigator.pop(context, payload);
    } catch (e) {
      debugPrint('Error saving announcement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save announcement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? "key_154".tr() : "key_155".tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: "key_156".tr()),
                validator: (value) =>
                    value == null || value.isEmpty ? "key_156a".tr() : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _body,
                decoration: InputDecoration(labelText: "key_157".tr()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // --- ADDED IMAGE PICKER FIELD ---
              ImagePickerField(
                label: 'Announcement Image (Optional)',
                initialUrl: _imageUrl,
                onChanged: (localFile, removed) {
                  setState(() {
                    _localImageFile = localFile;
                    _imageRemoved = removed;
                  });
                },
              ),
              const SizedBox(height: 12),
              // --- END ADDED IMAGE PICKER FIELD ---

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(
                  _scheduled == null
                      ? "key_190a".tr()
                      : 'Scheduled: ${DateFormat.yMMMd().add_jm().format(_scheduled!)}',
                ),
                trailing: TextButton(
                  onPressed: _pickDateTime,
                  child: Text("key_192".tr()),
                ),
              ),
              const SizedBox(height: 20),

              saving
                  ? const CircularProgressIndicator()
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: saving ? null : _submit,
                            child: Text(isEditing ? "key_041i".tr() : "key_041h".tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text("key_193".tr()),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
