import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class EditBibleStudyPage extends StatefulWidget {
  final Map<String, dynamic>? study; // if null, this is a new entry

  const EditBibleStudyPage({super.key, this.study});

  @override
  State<EditBibleStudyPage> createState() => _EditBibleStudyPageState();
}

class _EditBibleStudyPageState extends State<EditBibleStudyPage> {
  final supabase = Supabase.instance.client;
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
      _selectedDate = DateTime.parse(s!['date']);
    }
  }

  String _generateFilenameFromTitle(String title, String ext) {
    final safeTitle = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .substring(0, title.length.clamp(1, 50)); // prevent filename overflow
    return 'study-notes/$safeTitle$ext';
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final ext = p.extension(file.path);
    final title = _title.text.trim();

    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_260".tr())),
      );
      return;
    }

    final filename = _generateFilenameFromTitle(title, ext);

    try {
      await supabase.storage.from('biblestudynotes').upload(filename, file);
      final publicUrl = supabase.storage.from('biblestudynotes').getPublicUrl(filename);

      if (!mounted) return;

      setState(() => _notesUrl.text = publicUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_261".tr())),
      );
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

    final data = {
      'title': _title.text.trim(),
      'date': _selectedDate.toIso8601String(),
      'youtube_url': _youtubeUrl.text.trim(),
      'notes_url': _notesUrl.text.trim().isEmpty ? null : _notesUrl.text.trim(),
    };

    try {
      if (widget.study == null) {
        await supabase.from('bible_studies').insert(data);
      } else {
        await supabase
            .from('bible_studies')
            .update(data)
            .eq('id', widget.study!['id']);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.study == null ? "key_262".tr() : "key_262a".tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_263".tr())),
        );
      }
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _youtubeUrl.dispose();
    _notesUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.study == null ? "key_264".tr() : "key_264a".tr()),
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
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
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
                child: Text(widget.study == null ? "key_187".tr() : "key_041i".tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
