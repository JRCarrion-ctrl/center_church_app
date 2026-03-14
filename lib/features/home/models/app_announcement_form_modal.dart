// File: lib/features/home/models/app_announcement_form_modal.dart
import 'dart:typed_data';
import 'package:ccf_app/features/calendar/event_photo_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

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
  final _title   = TextEditingController();
  final _body    = TextEditingController();
  DateTime? _scheduled;

  Uint8List? _imageBytes;
  String?    _imageExtension;
  bool       _imageRemoved = false;
  String?    _imageUrl;

  late EventPhotoStorageService _mediaService;
  bool saving = false;

  GraphQLClient? _gql;
  String?        _userId;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _title.text = (a['title'] ?? '') as String;
      _body.text  = (a['body']  ?? '') as String;
      _imageUrl   = a['image_url'] as String?;
      final published = a['published_at'];
      if (published is String && published.isNotEmpty) {
        _scheduled = DateTime.tryParse(published)?.toLocal();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gql    ??= GraphQLProvider.of(context).value;
    _userId ??= context.read<AppState>().profile?.id;
    if (_gql != null) _mediaService = EventPhotoStorageService(_gql!);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now  = DateTime.now();
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
    final logicalId = widget.existing?['id'] as String? ?? 'new';

    if (_imageRemoved && _imageBytes == null) {
      finalImageUrl = null;
    } else if (_imageBytes != null) {
      try {
        finalImageUrl = await _mediaService.uploadEventPhoto(
          bytes: _imageBytes!,
          extension: _imageExtension,
          keyPrefix: 'app_announcements',
          logicalId: logicalId,
        );
      } catch (e) {
        debugPrint('Error uploading image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Failed to upload image')));
          setState(() => saving = false);
        }
        return;
      }
    }

    final payload = {
      'title':        _title.text.trim(),
      'body':         _body.text.trim().isEmpty ? null : _body.text.trim(),
      'published_at': (_scheduled ?? DateTime.now()).toUtc().toIso8601String(),
      'image_url':    finalImageUrl,
    };

    const insertMutation = r'''
      mutation InsertAppAnnouncement($title: String!, $body: String, $published_at: timestamptz!, $created_by: String!, $image_url: String) {
        insert_app_announcements_one(object: {
          title: $title, body: $body, published_at: $published_at,
          created_by: $created_by, image_url: $image_url
        }) { id }
      }
    ''';

    const updateMutation = r'''
      mutation UpdateAppAnnouncement($id: uuid!, $title: String!, $body: String, $published_at: timestamptz!, $image_url: String) {
        update_app_announcements_by_pk(pk_columns: {id: $id}, _set: {
          title: $title, body: $body, published_at: $published_at, image_url: $image_url
        }) { id }
      }
    ''';

    try {
      if (widget.existing != null) {
        final res = await _gql!.mutate(MutationOptions(
          document: gql(updateMutation),
          variables: {
            'id': widget.existing!['id'],
            ...payload,
          },
        ));
        if (res.hasException) throw res.exception!;
      } else {
        final res = await _gql!.mutate(MutationOptions(
          document: gql(insertMutation),
          variables: {
            ...payload,
            'created_by': _userId,
          },
        ));
        if (res.hasException) throw res.exception!;
      }
      if (mounted) Navigator.pop(context, payload);
    } catch (e) {
      debugPrint('Error saving announcement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save announcement: $e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final bottom    = MediaQuery.of(context).viewInsets.bottom;

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
                validator: (v) => v == null || v.isEmpty ? "key_156a".tr() : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _body,
                decoration: InputDecoration(labelText: "key_157".tr()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              ImagePickerField(
                label: 'Announcement Image (Optional)',
                initialUrl: _imageUrl,
                onChanged: (bytes, ext, removed) {
                  setState(() {
                    _imageBytes     = bytes;
                    _imageExtension = ext;
                    _imageRemoved   = removed;
                  });
                },
              ),
              const SizedBox(height: 12),
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