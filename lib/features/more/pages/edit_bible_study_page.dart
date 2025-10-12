// File: lib/features/more/pages/edit_bible_study_page.dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart' as graphql;
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/core/media/presigned_uploader.dart';

class EditBibleStudyPage extends StatefulWidget {
  final Map<String, dynamic>? study; // null => new

  const EditBibleStudyPage({super.key, this.study});

  @override
  State<EditBibleStudyPage> createState() => _EditBibleStudyPageState();
}

class _EditBibleStudyPageState extends State<EditBibleStudyPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _youtubeUrl;
  late final TextEditingController _notesUrl;
  DateTime _selectedDate = DateTime.now();
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.study;
    _title = TextEditingController(text: s?['title'] ?? '');
    _youtubeUrl = TextEditingController(text: s?['youtube_url'] ?? '');
    _notesUrl = TextEditingController(text: s?['notes_url'] ?? '');
    if (s?['date'] != null) {
      final raw = s!['date'] as String;
      _selectedDate = DateTime.tryParse(raw) ?? DateTime.parse('${raw}T00:00:00Z');
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _youtubeUrl.dispose();
    _notesUrl.dispose();
    super.dispose();
  }

  String _slug(String input, {int maxLen = 50}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'untitled';
    final safe = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final end = safe.length < maxLen ? safe.length : maxLen;
    return safe.substring(0, end);
  }

  Future<void> _pickAndUploadFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
    );
    if (picked == null || picked.files.single.path == null) return;

    final file = File(picked.files.single.path!);
    final ext = p.extension(file.path).toLowerCase();
    final title = _title.text.trim();

    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_260".tr())), // “Please enter a title first…”
      );
      return;
    }

    try {
      // Reuse your S3/GCS presigned upload helper
      final logicalId = widget.study?['id'] as String? ?? _slug(title);
      final uploadedUrl = await PresignedUploader.upload(
        file: file,
        keyPrefix: 'bible_studies', // folder/prefix in your storage
        logicalId: '$logicalId$ext', // keep filetype in the logical key
      );

      if (!mounted) return;

      if (uploadedUrl.isNotEmpty) {
        setState(() => _notesUrl.text = uploadedUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_261".tr())), // “Notes uploaded!”
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    final client = graphql.GraphQLProvider.of(context).value; // was: gql

    final dateStr = _selectedDate.toIso8601String().split('T').first;

    final vars = {
      'id': widget.study?['id'],
      'title': _title.text.trim(),
      'date': dateStr,
      'youtube_url': _youtubeUrl.text.trim(),
      'notes_url': _notesUrl.text.trim().isEmpty ? null : _notesUrl.text.trim(),
    };

    const mInsert = r'''
      mutation InsertStudy($title: String!, $date: date!, $youtube_url: String!, $notes_url: String) {
        insert_bible_studies_one(object: {
          title: $title, date: $date, youtube_url: $youtube_url, notes_url: $notes_url
        }) { id }
      }
    ''';

    const mUpdate = r'''
      mutation UpdateStudy($id: uuid!, $title: String!, $date: date!, $youtube_url: String!, $notes_url: String) {
        update_bible_studies_by_pk(
          pk_columns: { id: $id },
          _set: { title: $title, date: $date, youtube_url: $youtube_url, notes_url: $notes_url }
        ) { id }
      }
    ''';

    final isNew = widget.study == null;
    final doc = graphql.gql(isNew ? mInsert : mUpdate); // call the real gql()
    final effectiveVars = isNew ? (Map.of(vars)..remove('id')) : vars;

    try {
      final res = await client.mutate(
        graphql.MutationOptions(document: doc, variables: effectiveVars),
      );
      if (res.hasException) throw res.exception!;
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isNew ? "key_262".tr() : "key_262a".tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("key_263".tr())));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.study != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "key_264a".tr() : "key_264".tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: "key_156".tr()),
                validator: (v) => v == null || v.trim().isEmpty ? "key_156a".tr() : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text('Date: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _youtubeUrl,
                decoration: InputDecoration(labelText: "key_264b".tr()),
                validator: (v) => v == null || v.trim().isEmpty ? "key_264c".tr() : null,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text("key_265".tr()),
                onPressed: isSaving ? null : _pickAndUploadFile,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesUrl,
                decoration: InputDecoration(labelText: "key_265a".tr()),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSaving ? null : _save,
                child: Text(isEditing ? "key_041i".tr() : "key_187".tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
