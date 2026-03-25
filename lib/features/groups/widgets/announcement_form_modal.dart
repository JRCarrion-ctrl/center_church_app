// File: lib/features/groups/widgets/announcement_form_modal.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:ui';

import '../../../core/graph_provider.dart';
import '../../../core/time_service.dart';
import '../../../core/media/image_picker_field.dart';
import '../models/group_announcement.dart';
import '../../calendar/event_photo_storage_service.dart';

class AnnouncementFormModal extends StatefulWidget {
  final String             groupId;
  final GroupAnnouncement? existing;

  const AnnouncementFormModal({super.key, required this.groupId, this.existing});

  @override
  State<AnnouncementFormModal> createState() => _AnnouncementFormModalState();
}

class _AnnouncementFormModalState extends State<AnnouncementFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _title   = TextEditingController();
  final _body    = TextEditingController();
  DateTime? _scheduledUtc;

  Uint8List? _imageBytes;
  String?    _imageExtension;
  bool       _removedImage = false;

  late GraphQLClient         _client;
  late EventPhotoStorageService _mediaService;
  bool _clientReady = false;
  bool saving       = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _title.text  = ex.title;
      _body.text   = ex.body ?? '';
      _scheduledUtc = ex.publishedAt;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clientReady) return;
    _client       = GraphProvider.of(context);
    _mediaService = EventPhotoStorageService(_client);
    _clientReady  = true;
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
    final logicalId  = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    if (_removedImage) {
      imageUrl = null;
    } else if (_imageBytes != null) {
      try {
        imageUrl = await _mediaService.uploadEventPhoto(
          bytes: _imageBytes!,
          extension: _imageExtension,
          keyPrefix: 'group_announcements',
          logicalId: '${widget.groupId}/$logicalId',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
        setState(() => saving = false);
        return;
      }
    }

    final whenUtc = (_scheduledUtc ?? DateTime.now().toUtc()).toIso8601String();

    try {
      if (widget.existing != null) {
        const m = r'''
          mutation UpdateAnnouncements(
            $id: uuid!, $title: String!, $body: String, $image_url: String, $when: timestamptz!
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
            'id':        widget.existing!.id,
            'title':     _title.text.trim(),
            'body':      _body.text.trim().isEmpty ? null : _body.text.trim(),
            'image_url': imageUrl,
            'when':      whenUtc,
          },
        ));
        if (res.hasException) throw res.exception!;
      } else {
        const m = r'''
          mutation InsertAnnouncements(
            $groupId: uuid!, $title: String!, $body: String, $image_url: String, $when: timestamptz!
          ) {
            insert_group_announcements_one(object: {
              group_id: $groupId, title: $title, body: $body, image_url: $image_url, published_at: $when
            }) { id }
          }
        ''';
        final res = await _client.mutate(MutationOptions(
          document: gql(m),
          variables: {
            'groupId':   widget.groupId,
            'title':     _title.text.trim(),
            'body':      _body.text.trim().isEmpty ? null : _body.text.trim(),
            'image_url': imageUrl,
            'when':      whenUtc,
          },
        ));
        if (res.hasException) throw res.exception!;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now  = DateTime.now();
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
    setState(() => _scheduledUtc = TimeService.combineLocalDateAndTimeToUtc(date, time));
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    // ✨ 2. Clip the blur to the top rounded corners
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        // ✨ 3. Apply the blur to the background behind the modal
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            // ✨ 4. Use a semi-transparent background color
            color: isDark 
                ? Colors.black.withValues(alpha: 0.6) 
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2), 
              width: 1.5
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // iOS-style drag handle
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  
                  Text(
                    isEditing ? "key_154".tr() : "key_155".tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // ✨ 5. Use the modern input decoration helper if you have it, 
                  // or style them rounded and filled here:
                  TextFormField(
                    controller: _title,
                    decoration: _sleekInput(context, "key_156".tr(), Icons.title),
                    validator: (v) => v == null || v.isEmpty ? "key_156a".tr() : null,
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _body,
                    decoration: _sleekInput(context, "key_157".tr(), Icons.subject),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Modern Schedule Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _scheduledUtc == null
                                ? 'No schedule set'
                                : 'Scheduled: ${TimeService.formatUtcToLocal(_scheduledUtc!)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickDateTime,
                          child: Text("key_158".tr()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ImagePickerField(
                    label: 'Announcement Image',
                    initialUrl: widget.existing?.imageUrl,
                    onChanged: (bytes, ext, removed) {
                      setState(() {
                        _imageBytes     = bytes;
                        _imageExtension = ext;
                        _removedImage   = removed;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  if (saving)
                    CircularProgressIndicator(color: colorScheme.primary)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(isEditing ? "key_041i".tr() : "key_041h".tr()),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("key_159".tr(), style: TextStyle(color: colorScheme.outline)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  InputDecoration _sleekInput(BuildContext context, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: colorScheme.primary, size: 20),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}