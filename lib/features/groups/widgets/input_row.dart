// File: lib/features/groups/widgets/input_row.dart
import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

Future<File> _compressImage(File file) async {
  final targetPath = file.path.replaceFirst(
    RegExp(r'\.(jpg|jpeg|png|heic|webp)$'),
    '_compressed.jpg',
  );
  final compressedBytes = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: 1024,
    minHeight: 1024,
    quality: 85,
    format: CompressFormat.jpeg,
  );
  return File(targetPath)..writeAsBytesSync(compressedBytes!);
}

Future<List<String>> searchKlipyGifs(String query) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) throw Exception('User not logged in');

  const appKey = 'nGKv5SzsUhVjDfkzgTKwnQtwC2G9ED3qc5hHej1oYuQrY3OhzEdvr5a7YVq7dO9w';
  const locale = 'US';
  const contentFilter = 'high';

  final url = Uri.parse(
    'https://api.klipy.com/api/v1/$appKey/gifs/search'
    '?q=$query&page=1&per_page=20&customer_id=$userId&locale=$locale&content_filter=$contentFilter',
  );

  _logger.i('Fetching GIFs from: $url');

  final response = await http.get(url);
  _logger.i('Klipy API response status: ${response.statusCode}');
  _logger.i('Klipy API response body: ${response.body}');

  if (response.statusCode != 200) throw Exception('Failed to fetch GIFs');

  final data = json.decode(response.body);
  final items = data['data']?['data'];

  if (items is List && items.isNotEmpty) {
    return items
        .map<String?>((g) => g['file']?['md']?['gif']?['url'] as String?)
        .whereType<String>()
        .toList();
  } else {
    _logger.w('No results returned from Klipy');
    return [];
  }
}




class InputRow extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Future<void> Function(File file) onFilePicked;
  final Future<void> Function(String gifUrl) onGifPicked;

  const InputRow({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onFilePicked,
    required this.onGifPicked,
  });

  @override
  State<InputRow> createState() => _InputRowState();
}

class _InputRowState extends State<InputRow> {
  File? _selectedFile;
  final FocusNode _focusNode = FocusNode();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleInputChange);
  }

  void _handleInputChange() {
    final trimmed = widget.controller.text.trim();
    final valid = trimmed.isNotEmpty || _selectedFile != null;
    if (valid != _canSend) {
      setState(() => _canSend = valid);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.controller.removeListener(_handleInputChange);
    super.dispose();
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
                if (picked != null) {
                  File file = File(picked.path);
                  file = await _compressImage(file);
                  setState(() => _selectedFile = file);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
                if (picked != null) {
                  File file = File(picked.path);
                  file = await _compressImage(file);
                  setState(() => _selectedFile = file);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Browse Files'),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
                  File file = File(result.files.first.path!);
                  final ext = file.path.toLowerCase();
                  if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.webp') || ext.endsWith('.heic')) {
                    file = await _compressImage(file);
                  }
                  setState(() => _selectedFile = file);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  //Future<void> _openGifPicker() async {
    //final gifUrl = await showModalBottomSheet<String>(
      //context: context,
      //isScrollControlled: true,
      //builder: (_) => const _KlipyGifPicker(),
    //);

    //if (gifUrl != null) {
      //await widget.onGifPicked(gifUrl);
      //widget.controller.clear();
      //setState(() {
        //_selectedFile = null;
        //_canSend = false;
      //});
    //}
  //}

  bool _isGifUrl(String text) {
    return text.toLowerCase().endsWith('.gif') && text.startsWith('http');
  }

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();

    if (_selectedFile != null) {
      await widget.onFilePicked(_selectedFile!);
    }

    if (_isGifUrl(text)) {
      await widget.onGifPicked(text);
    } else if (text.isNotEmpty) {
      widget.onSend();
    }

    widget.controller.clear();
    setState(() {
      _selectedFile = null;
      _canSend = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? const Color(0xFF2C2C30) : const Color(0xFFF5F5FA);
    final borderColor = isDark ? const Color(0xFF46464B) : const Color(0xFFDCDCE6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedFile != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Dismissible(
              key: ValueKey(_selectedFile!.path),
              direction: DismissDirection.horizontal,
              onDismissed: (_) => setState(() => _selectedFile = null),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: _selectedFile!.path.endsWith('.png') ||
                           _selectedFile!.path.endsWith('.jpg') ||
                           _selectedFile!.path.endsWith('.jpeg') ||
                           _selectedFile!.path.endsWith('.webp') ||
                           _selectedFile!.path.endsWith('.heic')
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_selectedFile!, width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.insert_drive_file),
                  title: Text(_selectedFile!.path.split('/').last),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedFile = null),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              //IconButton.filledTonal(
                //icon: const Icon(Icons.gif_box_outlined),
                //tooltip: 'GIF',
                //onPressed: _openGifPicker,
              //),
              IconButton.filledTonal(
                icon: const Icon(Icons.attach_file),
                tooltip: 'Attach',
                onPressed: _showAttachmentOptions,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      focusNode: _focusNode,
                      controller: widget.controller,
                      minLines: 1,
                      maxLines: 5,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Send',
                onPressed: _canSend ? _handleSend : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KlipyGifPicker extends StatefulWidget {
  const _KlipyGifPicker();

  @override
  State<_KlipyGifPicker> createState() => _KlipyGifPickerState();
}

class _KlipyGifPickerState extends State<_KlipyGifPicker> {
  final TextEditingController _searchController = TextEditingController();
  List<String> gifs = [];
  bool loading = false;

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() => loading = true);
    try {
      gifs = await searchKlipyGifs(q);
    } catch (_) {
      gifs = [];
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search GIFs',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 12),
          if (loading)
            const CircularProgressIndicator()
          else if (gifs.isEmpty)
            const Text('No GIFs yet. Try searching.')
          else
            SizedBox(
              height: 300,
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: gifs.map((url) {
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
