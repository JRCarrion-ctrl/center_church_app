// lib/core/media/image_picker_field.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerField extends StatefulWidget {
  final String? initialUrl;
  final String label;
  // Callback now gives raw bytes + file extension instead of a dart:io File.
  // Works identically on web and mobile.
  final void Function(Uint8List? bytes, String? extension, bool removed) onChanged;

  const ImagePickerField({
    super.key,
    this.initialUrl,
    required this.onChanged,
    this.label = 'Image',
  });

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  Uint8List? _bytes;
  String?    _extension;
  bool       _removed = false;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    final bytes     = await picked.readAsBytes();
    final extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';

    setState(() {
      _bytes     = bytes;
      _extension = extension;
      _removed   = false;
    });
    widget.onChanged(_bytes, _extension, false);
  }

  void _remove() {
    setState(() {
      _bytes     = null;
      _extension = null;
      _removed   = true;
    });
    widget.onChanged(null, null, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final hasRemote = (widget.initialUrl?.isNotEmpty ?? false) && !_removed;

    Widget preview;
    if (_bytes != null) {
      // Image.memory works on every platform — no dart:io needed.
      preview = Image.memory(_bytes!, height: 140, fit: BoxFit.cover);
    } else if (hasRemote) {
      preview = Image.network(widget.initialUrl!, height: 140, fit: BoxFit.cover);
    } else {
      preview = Container(
        height: 140,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image, size: 40)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(12), child: preview),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.upload),
              label: const Text('Choose Image'),
            ),
            const SizedBox(width: 8),
            if (_bytes != null || hasRemote)
              TextButton.icon(
                onPressed: _remove,
                icon: const Icon(Icons.delete),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}