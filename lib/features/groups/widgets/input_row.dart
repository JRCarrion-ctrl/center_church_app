// File: lib/features/groups/widgets/input_row.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<File> _compressImage(File file) async {
  final targetPath = file.path.replaceFirst(RegExp(r'\.(jpg|jpeg|png|heic|webp)$'), '_compressed.jpg');
  final compressedBytes = await FlutterImageCompress.compressWithFile(
    file.absolute.path,
    minWidth: 600, // adjust as needed
    minHeight: 600,
    quality: 80,    // adjust as needed (lower = smaller file)
    format: CompressFormat.jpeg,
  );
  return File(targetPath)..writeAsBytesSync(compressedBytes!);
}

class InputRow extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Future<void> Function(File file) onFilePicked;

  const InputRow({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onFilePicked,
  });

  @override
  State<InputRow> createState() => _InputRowState();
}

class _InputRowState extends State<InputRow> {
  File? _selectedFile;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
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
                    await widget.onFilePicked(file);
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
                    await widget.onFilePicked(file);
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
                    await widget.onFilePicked(file);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }


  void _insertEmoji(String emoji) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    final newText = text.replaceRange(cursor, cursor, emoji);
    widget.controller.value = widget.controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedFile != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file),
                const SizedBox(width: 8),
                Expanded(child: Text(_selectedFile!.path.split('/').last)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedFile = null),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: _showAttachmentOptions,
              ),
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined),
                onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
              ),
              Expanded(
                child: TextField(
                  focusNode: _focusNode,
                  controller: widget.controller,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: widget.onSend,
              ),
            ],
          ),
        ),
        if (_showEmojiPicker)
          SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) => _insertEmoji(emoji.emoji),
            ),
          ),
      ],
    );
  }
}
