import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerField extends StatefulWidget {
  final String? initialUrl;
  final String label;
  final void Function(File? localFile, bool removed) onChanged;

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
  File? _localFile;
  bool _removed = false;

  Future<void> _pick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    setState(() {
      _localFile = File(picked.path);
      _removed = false;
    });
    widget.onChanged(_localFile, false);
  }

  void _remove() {
    setState(() {
      _localFile = null;
      _removed = true;
    });
    widget.onChanged(null, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRemote = (widget.initialUrl?.isNotEmpty ?? false) && !_removed;

    Widget preview;
    if (_localFile != null) {
      preview = Image.file(_localFile!, height: 140, fit: BoxFit.cover);
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
            if (_localFile != null || hasRemote)
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
