// File: lib/features/home/models/app_announcement_form_modal.dart
import 'dart:typed_data';
import 'package:ccf_app/features/calendar/event_photo_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';

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

  // ✨ NEW: State variable to track selected languages (Default to both)
  List<String> _selectedAudiences = ['english', 'spanish'];

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
      
      // ✨ NEW: Extract the languages if editing an existing announcement
      final aud = (a['target_audiences'] as List?)?.cast<String>();
      if (aud != null && aud.isNotEmpty) {
        _selectedAudiences = List.from(aud);
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
    // ✨ NEW: Guardrail to ensure they pick at least one audience
    if (_selectedAudiences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one target audience.'))
      );
      return;
    }

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

    // ✨ UPDATED: Added $langs to the mutations
    const insertMutation = r'''
      mutation InsertAppAnnouncement($title: String!, $body: String, $published_at: timestamptz!, $created_by: String!, $image_url: String, $langs: [String!]!) {
        insert_app_announcements_one(object: {
          title: $title, body: $body, published_at: $published_at,
          created_by: $created_by, image_url: $image_url, target_audiences: $langs
        }) { id }
      }
    ''';

    const updateMutation = r'''
      mutation UpdateAppAnnouncement($id: uuid!, $title: String!, $body: String, $published_at: timestamptz!, $image_url: String, $langs: [String!]!) {
        update_app_announcements_by_pk(pk_columns: {id: $id}, _set: {
          title: $title, body: $body, published_at: $published_at, image_url: $image_url, target_audiences: $langs
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
            'langs': _selectedAudiences, // ✨ NEW: Pass the array
          },
        ));
        if (res.hasException) throw res.exception!;
      } else {
        final res = await _gql!.mutate(MutationOptions(
          document: gql(insertMutation),
          variables: {
            ...payload,
            'created_by': _userId,
            'langs': _selectedAudiences, // ✨ NEW: Pass the array
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    // ✨ 1. Clip and Blur for the Frosted Glass effect
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            // ✨ 2. Semi-transparent background
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // iOS Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  Text(
                    isEditing ? "key_154".tr() : "key_155".tr(),
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
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

                  // ✨ 3. Modernized Target Audience Selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_alt_outlined, color: colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Target Audience".tr(), 
                              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: ['english', 'spanish'].map((lang) {
                            final isSelected = _selectedAudiences.contains(lang);
                            return FilterChip(
                              label: Text(lang == 'english' ? 'TCCF (English)' : 'Centro (Español)'),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: colorScheme.primaryContainer,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                              ),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedAudiences.add(lang);
                                  } else {
                                    _selectedAudiences.remove(lang);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Modern Image Picker Container
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ImagePickerField(
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
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Modern Schedule Tile
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
                            _scheduled == null
                                ? "key_190a".tr()
                                : 'Scheduled: ${DateFormat.yMMMd().add_jm().format(_scheduled!)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _pickDateTime,
                          child: Text("key_192".tr()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (saving)
                    Center(child: CircularProgressIndicator(color: colorScheme.primary))
                  else
                    Column(
                      children: [
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
                          child: Text("key_193".tr(), style: TextStyle(color: colorScheme.outline)),
                        ),
                      ],
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