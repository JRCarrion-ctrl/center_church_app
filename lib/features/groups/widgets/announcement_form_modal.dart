// File: lib/features/groups/widgets/announcement_form_modal.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../core/graph_provider.dart';
import '../../../core/time_service.dart';
// REMOVED: import '../../../core/media/presigned_uploader.dart'; // Old upload logic
import '../../../core/media/image_picker_field.dart'; // Import the new widget
import '../models/group_announcement.dart';
import '../../calendar/event_photo_storage_service.dart'; // <-- NEW/SHARED SERVICE IMPORT (Assume location)

class AnnouncementFormModal extends StatefulWidget {
  final String groupId;
  final GroupAnnouncement? existing;

  const AnnouncementFormModal({
    super.key,
    required this.groupId,
    this.existing,
  });

  @override
  State<AnnouncementFormModal> createState() => _AnnouncementFormModalState();
}

class _AnnouncementFormModalState extends State<AnnouncementFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime? _scheduledUtc;
  File? _selectedImage;
  bool _removedImage = false;

  late GraphQLClient _client;
  late EventPhotoStorageService _mediaService; // <-- INITIALIZE NEW SERVICE
  bool _clientReady = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _title.text = ex.title;
      _body.text = ex.body ?? '';
      _scheduledUtc = ex.publishedAt; 
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clientReady) return;
    _client = GraphProvider.of(context);
    _mediaService = EventPhotoStorageService(_client);
    _clientReady = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => saving = true);

    String? imageUrl = widget.existing?.imageUrl;
    final logicalId = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (_removedImage) {
      imageUrl = null;
    } else if (_selectedImage != null) {
      try {
        imageUrl = await _mediaService.uploadEventPhoto(
          file: _selectedImage!,
          keyPrefix: 'group_announcements', 
          logicalId: '${widget.groupId}/$logicalId', 
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload image: $e")),
        );
        setState(() => saving = false);
        return;
      }
    }

    final whenUtc = (_scheduledUtc ?? DateTime.now().toUtc()).toIso8601String();

    try {
      if (widget.existing != null) {
        const m = r'''
          mutation UpdateAnnouncements(
            $id: uuid!,
            $title: String!,
            $body: String,
            $image_url: String,
            $when: timestamptz!
          ) {
            update_group_announcements_by_pk(
              pk_columns: { id: $id },
              _set: { title: $title, body: $body, image_url: $image_url, published_at: $when }
            ) { id }
          }
        ''';

        final res = await _client.mutate(MutationOptions(
          document: gql(m),
          variables: {
            'id': widget.existing!.id,
            'title': _title.text.trim(),
            'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
            'image_url': imageUrl,
            'when': whenUtc,
          },
        ));
        if (res.hasException) {
          throw res.exception!;
        }
      } else {
        const m = r'''
          mutation InsertAnnouncements(
            $groupId: uuid!,
            $title: String!,
            $body: String,
            $image_url: String,
            $when: timestamptz!
          ) {
            insert_group_announcements_one(
              object: {
                group_id: $groupId,
                title: $title,
                body: $body,
                image_url: $image_url,
                published_at: $when
              }
            ) { id }
          }
        ''';

        final res = await _client.mutate(MutationOptions(
          document: gql(m),
          variables: {
            'groupId': widget.groupId,
            'title': _title.text.trim(),
            'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
            'image_url': imageUrl,
            'when': whenUtc,
          },
        ));
        if (res.hasException) {
          throw res.exception!;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledUtc?.toLocal() ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledUtc?.toLocal() ?? now),
    );
    if (time == null) return;

    final utc = TimeService.combineLocalDateAndTimeToUtc(date, time);
    setState(() => _scheduledUtc = utc);
  }

  @override
  Widget build(BuildContext context) {
    if (!_clientReady) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

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
                validator: (v) =>
                    v == null || v.isEmpty ? "key_156a".tr() : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _body,
                decoration: InputDecoration(labelText: "key_157".tr()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(
                  _scheduledUtc == null
                      ? 'No schedule set'
                      : 'Scheduled: ${TimeService.formatUtcToLocal(_scheduledUtc!)}',
                ),
                trailing: TextButton(
                  onPressed: _pickDateTime,
                  child: Text("key_158".tr()),
                ),
              ),
              const SizedBox(height: 12),
              
              ImagePickerField(
                label: 'Announcement Image',
                initialUrl: widget.existing?.imageUrl,
                onChanged: (localFile, removed) {
                  setState(() {
                    _selectedImage = localFile;
                    _removedImage = removed;
                  });
                },
              ),

              const SizedBox(height: 20),

              if (saving)
                const CircularProgressIndicator()
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(isEditing ? "key_041i".tr() : "key_041h".tr()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text("key_159".tr()),
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