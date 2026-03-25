// File: lib/features/more/pages/edit_bible_study_page.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart' as graphql;
import 'package:easy_localization/easy_localization.dart';

import 'package:ccf_app/features/more/bible_study_upload_service.dart';

class EditBibleStudyPage extends StatefulWidget {
  final Map<String, dynamic>? study;

  const EditBibleStudyPage({super.key, this.study});

  @override
  State<EditBibleStudyPage> createState() => _EditBibleStudyPageState();
}

class _EditBibleStudyPageState extends State<EditBibleStudyPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _youtubeUrl;
  late final TextEditingController _notesUrl;
  late final TextEditingController _dateController; // Used strictly for display
  
  late BibleStudyUploadService _uploadService;
  DateTime _selectedDate = DateTime.now();
  bool isSaving = false;

  String _contentTypeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.png':  return 'image/png';
      case '.gif':  return 'image/gif';
      case '.webp': return 'image/webp';
      case '.heic': return 'image/heic';
      case '.jpeg': return 'image/jpeg';
      default:      return 'application/pdf'; // Defaulting to PDF makes more sense for notes
    }
  }

  List<String> _selectedAudiences = ['spanish']; // Default to spanish

  @override
  void initState() {
    super.initState();
    final s = widget.study;
    _title      = TextEditingController(text: s?['title']       ?? '');
    _youtubeUrl = TextEditingController(text: s?['youtube_url'] ?? '');
    _notesUrl   = TextEditingController(text: s?['notes_url']   ?? '');
    
    if (s?['date'] != null) {
      final raw = s!['date'] as String;
      _selectedDate = DateTime.tryParse(raw) ?? DateTime.parse('${raw}T00:00:00Z');
    }
    if (s?['target_audiences'] != null) {
      _selectedAudiences = List<String>.from(s!['target_audiences']);
    }
    
    // Initialize display controller for the date
    _dateController = TextEditingController(text: DateFormat.yMMMd().format(_selectedDate));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = graphql.GraphQLProvider.of(context).value;
    _uploadService = BibleStudyUploadService(client);
  }

  @override
  void dispose() {
    _title.dispose();
    _youtubeUrl.dispose();
    _notesUrl.dispose();
    _dateController.dispose();
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
    final title = _title.text.trim();

    // Prevent upload if title is empty, as we need it for the slug
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_260".tr())),
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'pdf'],
      withData: true,
    );

    final platformFile = picked?.files.single;
    if (platformFile == null) return;

    final bytes = platformFile.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file bytes.')),
      );
      return;
    }

    setState(() => isSaving = true); // Show loading state during upload

    final ext = '.${platformFile.extension?.toLowerCase() ?? 'pdf'}';
    final contentType = _contentTypeFromExt(platformFile.name);

    try {
      final logicalId = widget.study?['id'] as String? ?? _slug(title);
      final logicalIdWithExt = '$logicalId$ext';

      final uploadedUrl = await _uploadService.uploadStudyNotes(
        bytes,
        logicalIdWithExt,
        contentType,
      );

      if (!mounted) return;
      setState(() {
        _notesUrl.text = uploadedUrl;
        isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_261".tr())),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat.yMMMd().format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAudiences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select Audience")),
      );
      return;
    }
    setState(() => isSaving = true);

    final client  = graphql.GraphQLProvider.of(context).value;
    final dateStr = _selectedDate.toIso8601String().split('T').first;

    final vars = {
      'id':          widget.study?['id'],
      'title':       _title.text.trim(),
      'date':        dateStr,
      'youtube_url': _youtubeUrl.text.trim(),
      'notes_url':   _notesUrl.text.trim().isEmpty ? null : _notesUrl.text.trim(),
      'audiences':   "{${_selectedAudiences.join(',')}}",
    };

    const mInsert = r'''
      mutation InsertStudy($title: String!, $date: date!, $youtube_url: String!, $notes_url: String, $audiences: _text) {
        insert_bible_studies_one(object: {
          title: $title, date: $date, youtube_url: $youtube_url, notes_url: $notes_url, target_audiences: $audiences
        }) { id }
      }
    ''';

    const mUpdate = r'''
      mutation UpdateStudy($id: uuid!, $title: String!, $date: date!, $youtube_url: String!, $notes_url: String, $audiences: _text) {
        update_bible_studies_by_pk(
          pk_columns: { id: $id },
          _set: { title: $title, date: $date, youtube_url: $youtube_url, notes_url: $notes_url, target_audiences: $audiences }
        ) { id }
      }
    ''';

    final isNew        = widget.study == null;
    final doc          = graphql.gql(isNew ? mInsert : mUpdate);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("key_263".tr())));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  static const mDelete = r'''
    mutation DeleteStudy($id: uuid!) {
      delete_bible_studies_by_pk(id: $id) { id }
    }
  ''';

  Future<void> _delete() async {
    final studyId = widget.study?['id'];
    if (studyId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("key_073".tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text("key_055".tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("key_039".tr()), // Delete
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => isSaving = true);

    if (!mounted) return;
    final client = graphql.GraphQLProvider.of(context).value;

    try {
      final res = await client.mutate(
        graphql.MutationOptions(
          document: graphql.gql(mDelete),
          variables: {'id': studyId},
        ),
      );
      if (res.hasException) throw res.exception!;
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_024i".tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_182".tr())),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.study != null;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "key_264a".tr() : "key_264".tr()),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade400,
              tooltip: "key_039".tr(),
              onPressed: isSaving ? null : _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Section 1: Basic Info
            Text(
              "Study Details", 
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(
                labelText: "key_156".tr(), // Title
                prefixIcon: const Icon(Icons.title),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? "key_156a".tr() : null,
            ),
            const SizedBox(height: 16),
            
            // Replaced ListTile Date Picker with a styled readOnly TextFormField
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _selectDate,
              decoration: const InputDecoration(
                labelText: "Date",
                prefixIcon: Icon(Icons.calendar_month),
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 32),

            // Section 2: Media & Notes
            Text(
              "Media & Resources", 
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _youtubeUrl,
              decoration: InputDecoration(
                labelText: "key_264b".tr(), // YouTube Link
                prefixIcon: const Icon(Icons.ondemand_video),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? "key_264c".tr() : null,
            ),
            const SizedBox(height: 16),

            // Dedicated Upload Card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.upload_file),
                      label: Text("key_265".tr()), // Upload Study Notes
                      onPressed: isSaving ? null : _pickAndUploadFile,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesUrl,
                      decoration: InputDecoration(
                        labelText: "key_265a".tr(), // Notes URL
                        prefixIcon: const Icon(Icons.link),
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Text(
              "Target Audience".tr(), 
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                FilterChip(
                  label: const Text("TCCF"),
                  selected: _selectedAudiences.contains('english'),
                  onSelected: (selected) {
                    setState(() {
                      selected ? _selectedAudiences.add('english') : _selectedAudiences.remove('english');
                    });
                  },
                ),
                FilterChip(
                  label: const Text("Centro"),
                  selected: _selectedAudiences.contains('spanish'),
                  onSelected: (selected) {
                    setState(() {
                      selected ? _selectedAudiences.add('spanish') : _selectedAudiences.remove('spanish');
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Full-Width Save Button
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: isSaving ? null : _save,
                child: isSaving 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isEditing ? "key_041i".tr() : "key_187".tr(), 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditBibleStudyWrapper extends StatefulWidget {
  final String studyId;
  const EditBibleStudyWrapper({super.key, required this.studyId});

  @override
  State<EditBibleStudyWrapper> createState() => _EditBibleStudyWrapperState();
}

class _EditBibleStudyWrapperState extends State<EditBibleStudyWrapper> {
  Future<Map<String, dynamic>?>? _studyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 🚀 FIXED: Added check for "null" string
    final bool isInvalidId = widget.studyId.isEmpty || widget.studyId == "null";

    if (_studyFuture == null && !isInvalidId) {
      final client = graphql.GraphQLProvider.of(context).value;
      const query = r'''
        query GetStudy($id: uuid!) {
          bible_studies_by_pk(id: $id) {
            id title date youtube_url notes_url target_audiences
          }
        }
      ''';
      _studyFuture = client.query(graphql.QueryOptions(
        document: graphql.gql(query), 
        variables: {'id': widget.studyId}, 
        fetchPolicy: graphql.FetchPolicy.networkOnly,
      )).then((res) => res.data?['bible_studies_by_pk']);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 FIXED: Added check for "null" string here too
    if (widget.studyId.isEmpty || widget.studyId == "null") {
      return const EditBibleStudyPage(study: null);
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _studyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasError || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text("Study not found")),
          );
        }

        return EditBibleStudyPage(study: snapshot.data);
      },
    );
  }
}