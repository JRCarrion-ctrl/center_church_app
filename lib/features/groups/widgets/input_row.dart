// File: lib/features/groups/widgets/input_row.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
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

/// Desktop and web have a hardware keyboard: Enter sends, Shift+Enter adds a
/// new line. On phones the keyboard's return key adds a line and the send
/// button sends.
bool get _enterSends =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

class _InputRowState extends State<InputRow> {
  final List<_AttachedFile> _selectedFiles = [];
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKeyEvent);
  bool _canSend = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleInputChange);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_enterSends || event is! KeyDownEvent) return KeyEventResult.ignored;
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter || HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _handleSend();
    return KeyEventResult.handled;
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
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (!kIsWeb) // Camera not available on web
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
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
              leading: const Icon(Icons.photo_library_outlined),
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
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text("key_169".tr()),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.pickFiles(
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

  Future<void> _openGifPicker() async {
    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _KlipyGifPicker(),
    );
    if (url == null || !mounted) return;
    try {
      await widget.onGifPicked(url);
    } catch (e, st) {
      _logger.e('[InputRow] gif send failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('chat_send_failed'.tr())));
      }
    }
    _focusNode.requestFocus();
  }

  bool _isGifUrl(String text) =>
      text.toLowerCase().endsWith('.gif') && text.startsWith('http');

  /// Clears the box right away so the next message can be typed, then sends.
  /// On failure the text and attachments are put back.
  Future<void> _handleSend() async {
    if (_sending) return;
    final text = widget.controller.text.trim();
    final files = List<_AttachedFile>.from(_selectedFiles);
    if (text.isEmpty && files.isEmpty) return;

    _logger.i('[InputRow] handleSend text="${text.replaceAll('\n', ' ')}" '
        'files=${files.length} isGif=${_isGifUrl(text)}');

    setState(() {
      _sending = true;
      _selectedFiles.clear();
    });
    _focusNode.requestFocus();

    try {
      for (final f in files) {
        _logger.i('[InputRow] onFilePicked: ${f.filename}');
        await widget.onFilePicked(f.bytes, f.filename);
      }

      if (_isGifUrl(text)) {
        widget.controller.clear();
        await widget.onGifPicked(text);
      } else if (text.isNotEmpty) {
        // onSend reads the controller synchronously before its first await,
        // so the box can be cleared as soon as the call has started.
        final sending = widget.onSend();
        widget.controller.clear();
        await sending;
      }
    } catch (e, st) {
      _logger.e('[InputRow] send failed', error: e, stackTrace: st);
      if (mounted) {
        if (widget.controller.text.isEmpty) widget.controller.text = text;
        setState(() => _selectedFiles.insertAll(0, files));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('chat_send_failed'.tr())));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _handleInputChange();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Solid field with a visible edge (the light theme's outlineVariant is a
    // near-invisible white, so it isn't used here).
    final fieldColor = dark ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLowest;
    final borderColor = colorScheme.onSurface.withValues(alpha: dark ? 0.12 : 0.14);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedFiles.isNotEmpty)
          Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedFiles.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final f = _selectedFiles[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: f.isImage
                            ? Image.memory(f.bytes, fit: BoxFit.cover)
                            : Icon(Icons.insert_drive_file_outlined, size: 24, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Semantics(
                        button: true,
                        label: 'chat_remove_attachment'.tr(),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedFiles.removeAt(index);
                            _handleInputChange();
                          }),
                          child: Container(
                            decoration: BoxDecoration(color: colorScheme.error, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(3),
                            child: Icon(Icons.close, size: 14, color: colorScheme.onError),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // --- Message pill: attach, text, GIF ---
              Expanded(
                child: GestureDetector(
                  // Tapping anywhere on the pill focuses the field.
                  onTap: _focusNode.requestFocus,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 50),
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: colorScheme.onSurfaceVariant),
                          tooltip: 'chat_attach'.tr(),
                          onPressed: _showAttachmentOptions,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: TextField(
                              focusNode: _focusNode,
                              controller: widget.controller,
                              minLines: 1,
                              maxLines: 6,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                              decoration: InputDecoration(
                                hintText: (_enterSends ? 'chat_input_hint_desktop' : 'chat_input_hint').tr(),
                                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                                hintMaxLines: 1,
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.gif_box_outlined, color: colorScheme.onSurfaceVariant),
                          tooltip: 'chat_gif'.tr(),
                          onPressed: _openGifPicker,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // --- Send ---
              AnimatedScale(
                scale: _canSend ? 1 : 0.9,
                duration: const Duration(milliseconds: 150),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
                      disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                    icon: _sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                    tooltip: 'chat_send'.tr(),
                    onPressed: (_canSend && !_sending) ? _handleSend : null,
                  ),
                ),
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
              labelText: 'chat_search_gifs'.tr(),
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