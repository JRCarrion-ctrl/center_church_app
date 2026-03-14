// File: lib/features/groups/pages/group_settings_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../core/graph_provider.dart';
import '../group_service.dart';
import '../models/group.dart';
import '../chat_storage_service.dart';

class GroupSettingsPage extends StatefulWidget {
  final Group group;
  const GroupSettingsPage({super.key, required this.group});

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late GroupService          _groupService;
  late ChatStorageService    _chatStorageService;

  String? _tempPhotoUrl;
  bool _isSaving    = false;
  bool _isUploading = false;
  
  // ADDED: State variable for the toggle
  late bool _onlyAdminsMessage; 

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descController = TextEditingController(text: widget.group.description ?? '');
    _tempPhotoUrl   = widget.group.photoUrl;
    
    // Initialize the toggle from the existing group data
    _onlyAdminsMessage = widget.group.onlyAdminsMessage;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client    = GraphProvider.of(context);
    _groupService   = GroupService(client);
    _chatStorageService = ChatStorageService(client);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Compresses image bytes on mobile. Returns original bytes on web
  /// (flutter_image_compress has no web support).
  Future<Uint8List> _compressBytes(Uint8List bytes) async {
    if (kIsWeb) return bytes;
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 600,
      minHeight: 600,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    return compressed;
  }

  Future<void> _pickAndUploadImage() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked    = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final raw        = await picked.readAsBytes();
      final compressed = await _compressBytes(raw);
      // uploadFile now accepts bytes + filename (see chat_storage_service.dart)
      final finalUrl = await _chatStorageService.uploadFile(
        compressed,
        '${widget.group.id}.jpg',
        widget.group.id,  // ← add back
      );
      setState(() => _tempPhotoUrl = finalUrl);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("key_112".tr(args: [e.toString()]))),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_nameController.text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      // 1. Update general group info
      await _groupService.updateGroup(
        groupId: widget.group.id,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        photoUrl: _tempPhotoUrl,
      );
      
      // 2. Update specific group settings if the toggle changed
      if (_onlyAdminsMessage != widget.group.onlyAdminsMessage) {
        await _groupService.updateGroupSettings(
          groupId: widget.group.id,
          onlyAdminsMessage: _onlyAdminsMessage,
        );
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("key_196g".tr()),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _isUploading ? null : _pickAndUploadImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: (_tempPhotoUrl != null && _tempPhotoUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(_tempPhotoUrl!)
                        : null,
                    child: (_tempPhotoUrl == null || _tempPhotoUrl!.isEmpty)
                        ? const Icon(Icons.group, size: 60)
                        : null,
                  ),
                  if (_isUploading) const CircularProgressIndicator(),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      radius: 18,
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: "key_068a".tr(),
              prefixIcon: const Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "key_068c".tr(),
              prefixIcon: const Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 24),
          
          // Admin Only Message Toggle
          SwitchListTile(
            title: Text("only_admin".tr()),
            value: _onlyAdminsMessage,
            onChanged: (val) => setState(() => _onlyAdminsMessage = val),
            contentPadding: EdgeInsets.zero, // Aligns nicely with the TextFields
          ),
        ],
      ),
    );
  }
}