import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ccf_app/features/groups/group_service.dart';
import 'package:ccf_app/app_state.dart';

class JoinGroupPreviewScreen extends StatefulWidget {
  final String token;

  const JoinGroupPreviewScreen({super.key, required this.token});

  @override
  State<JoinGroupPreviewScreen> createState() => _JoinGroupPreviewScreenState();
}

class _JoinGroupPreviewScreenState extends State<JoinGroupPreviewScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  
  // ✨ NEW: State variables for the preview
  bool _isLoadingPreview = true;
  String? _groupName;
  String? _groupPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadGroupPreview();
  }

  // ✨ NEW: Fetch the group details when the page opens
  Future<void> _loadGroupPreview() async {
    final svc = context.read<GroupService>();
    final previewData = await svc.getGroupPreviewFromToken(widget.token);
    
    if (mounted) {
      setState(() {
        if (previewData != null) {
          _groupName = previewData['name'];
          _groupPhotoUrl = previewData['photo_url'];
        }
        _isLoadingPreview = false;
      });
    }
  }

  Future<void> _handleJoin() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final svc = context.read<GroupService>();
      final groupId = await svc.consumeInviteLink(widget.token);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Successfully joined the group!".tr())),
      );

      context.replace('/groups/$groupId');

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        
        final errorString = e.toString();
        // Unmask Hasura errors
        if (errorString.contains('database query error') || errorString.contains('postgres error')) {
          _errorMessage = "There was an issue joining this group. Please try again."; 
        } else if (errorString.contains('Unique constraint') || errorString.contains('duplicate key')) {
          _errorMessage = "You are already a member of this group!".tr();
        } else {
          _errorMessage = errorString.replaceAll('Exception: ', '');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAuthed = context.watch<AppState>().isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: Text("Group Invite".tr()),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _isLoadingPreview 
              ? const CircularProgressIndicator() // Show simple loader while fetching preview
              : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✨ UPDATED: Show Photo or Fallback Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    image: _groupPhotoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_groupPhotoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _groupPhotoUrl == null
                      ? Icon(Icons.group, size: 64, color: colorScheme.primary)
                      : null,
                ),
                const SizedBox(height: 32),
                
                // ✨ UPDATED: Personalized Welcome Text
                Text(
                  _groupName != null 
                      ? "You've been invited to join\n$_groupName!" 
                      : "You've been invited!".tr(),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Dynamic instructional text
                Text(
                  isAuthed 
                    ? "Click below to accept the invitation and join the group.".tr()
                    : "Please log in or create an account to join this group.".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),

                // Error State Rendering
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 56, 
                  child: FilledButton(
                    onPressed: _isProcessing 
                        ? null 
                        : (isAuthed ? _handleJoin : () => context.push('/auth')),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            isAuthed ? "Accept Invitation".tr() : "Log In to Join".tr(), 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/groups'),
                  child: Text("Cancel".tr()),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}