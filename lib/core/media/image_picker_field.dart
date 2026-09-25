// lib/core/media/image_picker_field.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io' as io show Platform;

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

  // image_cropper only supports Android, iOS and Web — skip cropping (use the
  // picked image as-is) on desktop platforms where it isn't implemented.
  bool get _cropSupported => kIsWeb || io.Platform.isAndroid || io.Platform.isIOS;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    Uint8List bytes = await picked.readAsBytes();
    String extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';

    if (_cropSupported && mounted) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
            aspectRatioLockEnabled: false,
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            initialAspectRatio: 16 / 9,
          ),
        ],
      );
      // User cancelled the crop step — treat like cancelling the whole pick.
      if (cropped == null) return;
      bytes = await cropped.readAsBytes();
      extension = 'jpg';
    }

    if (!mounted) return;
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