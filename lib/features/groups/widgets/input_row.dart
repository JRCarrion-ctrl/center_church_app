// File: lib/features/groups/widgets/input_row.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDark
        ? Color.fromARGB(255, 44, 44, 48)
        : Color.fromARGB(255, 245, 245, 250);

    final borderColor = isDark
        ? Color.fromARGB(255, 70, 70, 75)
        : Color.fromARGB(255, 220, 220, 230);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _selectedFile != null
              ? Padding(
                  key: ValueKey(_selectedFile!.path),
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
                )
              : const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.attach_file),
                tooltip: 'Attach file',
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
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
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

  Future<void> _handleSend() async {
    if (_selectedFile != null) {
      await widget.onFilePicked(_selectedFile!);
    }

    if (widget.controller.text.trim().isNotEmpty) {
      widget.onSend();
    }

    widget.controller.clear();
    setState(() {
      _canSend = false;
      _selectedFile = null;
    });
  }
}
