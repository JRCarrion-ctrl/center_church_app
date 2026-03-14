// File: lib/features/groups/widgets/input_row.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

/// Compresses image bytes on mobile; returns originals on web.
Future<Uint8List> _compressImageBytes(Uint8List bytes) async {
  if (kIsWeb) return bytes;
  final compressed = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth: 1024,
    minHeight: 1024,
    quality: 85,
    format: CompressFormat.jpeg,
  );
  return compressed;
}

bool _isImageFilename(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic');
}

Future<List<String>> searchKlipyGifs(BuildContext context, String query) async {
  final userId = context.read<AppState>().profile?.id;
  if (userId == null || userId.isEmpty) throw Exception('User not logged in');

  const appKey        = 'nGKv5SzsUhVjDfkzgTKwnQtwC2G9ED3qc5hHej1oYuQrY3OhzEdvr5a7YVq7dO9w';
  const locale        = 'US';
  const contentFilter = 'high';

  final url = Uri.parse(
    'https://api.klipy.com/api/v1/$appKey/gifs/search'
    '?q=$query&page=1&per_page=20&customer_id=$userId&locale=$locale&content_filter=$contentFilter',
  );

  _logger.i('Fetching GIFs from: $url');
  final response = await http.get(url);
  if (response.statusCode != 200) throw Exception('Failed to fetch GIFs');

  final data  = json.decode(response.body);
  final items = data['data']?['data'];

  if (items is List && items.isNotEmpty) {
    return items
        .map<String?>((g) => g['file']?['md']?['gif']?['url'] as String?)
        .whereType<String>()
        .toList();
  }
  _logger.w('No results returned from Klipy');
  return [];
}

/// Holds bytes + metadata for a picked file so we never need dart:io File.
class _AttachedFile {
  final Uint8List bytes;
  final String    filename;
  final bool      isImage;

  const _AttachedFile({
    required this.bytes,
    required this.filename,
    required this.isImage,
  });
}

class InputRow extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function()                          onSend;
  // Callback now passes raw bytes + filename instead of a dart:io File.
  final Future<void> Function(Uint8List bytes, String filename) onFilePicked;
  final Future<void> Function(String gifUrl)             onGifPicked;

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
  final List<_AttachedFile> _selectedFiles = [];
  final FocusNode _focusNode = FocusNode();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleInputChange);
  }

  void _handleInputChange() {
    final valid = widget.controller.text.trim().isNotEmpty || _selectedFiles.isNotEmpty;
    if (valid != _canSend) setState(() => _canSend = valid);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.controller.removeListener(_handleInputChange);
    super.dispose();
  }

  Future<void> _addFromXFile(XFile xfile) async {
    final raw      = await xfile.readAsBytes();
    final isImage  = _isImageFilename(xfile.name);
    final bytes    = isImage ? await _compressImageBytes(raw) : raw;
    final filename = isImage
        ? xfile.name.replaceAll(RegExp(r'\.(jpg|jpeg|png|webp|heic)$', caseSensitive: false), '_c.jpg')
        : xfile.name;
    setState(() => _selectedFiles.add(_AttachedFile(bytes: bytes, filename: filename, isImage: isImage)));
    _handleInputChange();
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (!kIsWeb) // Camera not available on web
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text("key_167".tr()),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 75,
                  );
                  if (picked != null) await _addFromXFile(picked);
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text("key_168".tr()),
              onTap: () async {
                Navigator.pop(context);
                final pickedList = await ImagePicker().pickMultiImage(imageQuality: 75);
                for (final xfile in pickedList) {
                  await _addFromXFile(xfile);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text("key_169".tr()),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  allowMultiple: true,
                  withData: true, // Required on web; harmless on mobile.
                );
                if (result == null) return;
                for (final f in result.files) {
                  final bytes = f.bytes;
                  if (bytes == null) continue;
                  final name    = f.name;
                  final isImage = _isImageFilename(name);
                  final compressed = isImage ? await _compressImageBytes(bytes) : bytes;
                  setState(() => _selectedFiles.add(
                    _AttachedFile(bytes: compressed, filename: name, isImage: isImage),
                  ));
                }
                _handleInputChange();
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isGifUrl(String text) =>
      text.toLowerCase().endsWith('.gif') && text.startsWith('http');

  Future<void> _handleSend() async {
    final text = widget.controller.text.trim();
    _logger.i('[InputRow] handleSend text="${text.replaceAll('\n', ' ')}" '
        'files=${_selectedFiles.length} isGif=${_isGifUrl(text)}');

    try {
      for (final f in _selectedFiles) {
        _logger.i('[InputRow] onFilePicked: ${f.filename}');
        await widget.onFilePicked(f.bytes, f.filename);
      }

      if (_isGifUrl(text)) {
        await widget.onGifPicked(text);
      } else if (text.isNotEmpty) {
        await widget.onSend();
      }

      widget.controller.clear();
      setState(() {
        _selectedFiles.clear();
        _canSend = false;
      });
    } catch (e, st) {
      _logger.e('[InputRow] send failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to send')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark ? const Color(0xFF2C2C30) : const Color(0xFFF5F5FA);
    final borderColor    = isDark ? const Color(0xFF46464B) : const Color(0xFFDCDCE6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedFiles.isNotEmpty)
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final f = _selectedFiles[index];
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
                        child: f.isImage
                            ? Image.memory(f.bytes, fit: BoxFit.cover)
                            : const Center(child: Icon(Icons.insert_drive_file, size: 24)),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedFiles.removeAt(index);
                          _handleInputChange();
                        }),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
  List<String> gifs   = [];
  bool         loading = false;

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
        top: 16, left: 16, right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search GIFs',
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
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