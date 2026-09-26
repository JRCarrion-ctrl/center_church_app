// File: lib/core/media/avatar_image_picker.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io' as io show Platform;

// A simple class to hold the result so .bytes works in your settings page
class PickedAvatar {
  final Uint8List bytes;
  final String extension;

  PickedAvatar({required this.bytes, required this.extension});
}

Future<PickedAvatar?> pickAndCropAvatarImage(BuildContext context) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 90,
  );
  if (picked == null) return null;

  Uint8List bytes = await picked.readAsBytes();
  String extension = picked.name.contains('.')
      ? picked.name.split('.').last.toLowerCase()
      : 'jpg';

  // Crop is only supported on Web, Android, and iOS
  bool cropSupported = kIsWeb || io.Platform.isAndroid || io.Platform.isIOS;

  if (cropSupported) {
    if (!context.mounted) return null;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Avatar',
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true, // Lock to square for avatars
        ),
        IOSUiSettings(
          title: 'Crop Avatar',
          aspectRatioPresets: const [CropAspectRatioPreset.square],
          aspectRatioLockEnabled: true, // Lock to square for avatars
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          initialAspectRatio: 1.0, // Square
        ),
      ],
    );
    
    // User cancelled the crop step
    if (cropped == null) return null; 
    
    bytes = await cropped.readAsBytes();
    extension = 'jpg';
  }

  return PickedAvatar(bytes: bytes, extension: extension);
}