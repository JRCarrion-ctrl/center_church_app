// File: lib/features/groups/widgets/input_row.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:logger/logger.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../app_state.dart';

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

Future<List<String>> searchKlipyGifs(BuildContext context, String query) async {
  final userId = context.read<AppState>().profile?.id;
  if (userId == null || userId.isEmpty) throw Exception('User not logged in');

  const appKey = 'nGKv5SzsUhVjDfkzgTKwnQtwC2G9ED3qc5hHej1oYuQrY3OhzEdvr5a7YVq7dO9w';
  const locale = 'US';
  const contentFilter = 'high';

  final url = Uri.parse(
    'https://api.klipy.com/api/v1/$appKey/gifs/search'
    '?q=$query&page=1&per_page=20&customer_id=$userId&locale=$locale&content_filter=$contentFilter',
  );

  _logger.i('Fetching GIFs from: $url');

  final response = await http.get(url);
  // _logger.i('Klipy API response status: ${response.statusCode}'); // Reduced log spam

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
  final Future<void> Function() onSend;
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
  // CHANGED: Support multiple files
  final List<File> _selectedFiles = [];
  
  final FocusNode _focusNode = FocusNode();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleInputChange);
  }

  void _handleInputChange() {
    final trimmed = widget.controller.text.trim();
    // CHANGED: Check list not empty
    final valid = trimmed.isNotEmpty || _selectedFiles.isNotEmpty;
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
              title: Text("key_167".tr()), // "Camera"
              onTap: () async {
                Navigator.pop(context);
                final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75);
                if (picked != null) {
                  File file = File(picked.path);
                  file = await _compressImage(file);
                  setState(() => _selectedFiles.add(file)); // Add to list
                  _handleInputChange();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text("key_168".tr()), // "Gallery"
              onTap: () async {
                Navigator.pop(context);
                // CHANGED: Use pickMultiImage to allow multiple selections
                final pickedList = await ImagePicker().pickMultiImage(imageQuality: 75);
                if (pickedList.isNotEmpty) {
                  for (var picked in pickedList) {
                    File file = File(picked.path);
                    file = await _compressImage(file);
                    _selectedFiles.add(file);
                  }
                  setState(() {}); // Trigger rebuild
                  _handleInputChange();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text("key_169".tr()), // "File"
              onTap: () async {
                Navigator.pop(context);
                // CHANGED: allowMultiple: true
                final result = await FilePicker.platform.pickFiles(allowMultiple: true);
                if (result != null && result.files.isNotEmpty) {
                  for (var f in result.files) {
                    if (f.path == null) continue;
                    File file = File(f.path!);
                    final ext = file.path.toLowerCase();
                    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.webp') || ext.endsWith('.heic')) {
                      file = await _compressImage(file);
                    }
                    _selectedFiles.add(file);
                  }
                  setState(() {}); // Trigger rebuild
                  _handleInputChange();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isGifUrl(String text) {
    return text.toLowerCase().endsWith('.gif') && text.startsWith('http');
  }

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    _logger.i('[InputRow] handleSend start text="${text.replaceAll('\n',' ')}" '
              'files=${_selectedFiles.length} isGif=${_isGifUrl(text)}');

    try {
      // CHANGED: Iterate and send all selected files
      if (_selectedFiles.isNotEmpty) {
        for (final file in _selectedFiles) {
          _logger.i('[InputRow] onFilePicked: ${file.path}');
          await widget.onFilePicked(file);
        }
        _logger.i('[InputRow] onFilePicked loop done');
      }

      if (_isGifUrl(text)) {
        _logger.i('[InputRow] onGifPicked: $text');
        await widget.onGifPicked(text);
        _logger.i('[InputRow] onGifPicked done');
      } else if (text.isNotEmpty) {
        _logger.i('[InputRow] onSend() begin');
        await widget.onSend();
        _logger.i('[InputRow] onSend() done');
      }

      widget.controller.clear();
      setState(() {
        _selectedFiles.clear(); // Clear list
        _canSend = false;
      });
      _logger.i('[InputRow] cleared UI state');
    } catch (e, st) {
      _logger.e('[InputRow] send failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? const Color(0xFF2C2C30) : const Color(0xFFF5F5FA);
    final borderColor = isDark ? const Color(0xFF46464B) : const Color(0xFFDCDCE6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CHANGED: Display horizontal list of selected files
        if (_selectedFiles.isNotEmpty)
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                final isImage = file.path.toLowerCase().endsWith('.jpg') ||
                                file.path.toLowerCase().endsWith('.jpeg') ||
                                file.path.toLowerCase().endsWith('.png') ||
                                file.path.toLowerCase().endsWith('.webp') ||
                                file.path.toLowerCase().endsWith('.heic');

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isImage
                            ? Image.file(file, fit: BoxFit.cover)
                            : const Center(child: Icon(Icons.insert_drive_file, size: 24)),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFiles.removeAt(index);
                            _handleInputChange();
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
      gifs = await searchKlipyGifs(context, q);
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
            Text("key_170".tr())
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