import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ccf_app/features/groups/group_service.dart';

class JoinGroupPreviewScreen extends StatefulWidget {
  final String token;

  const JoinGroupPreviewScreen({super.key, required this.token});

  @override
  State<JoinGroupPreviewScreen> createState() => _JoinGroupPreviewScreenState();
}

class _JoinGroupPreviewScreenState extends State<JoinGroupPreviewScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

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

      context.go('/groups/$groupId');

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("Group Invite".tr()),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          // ConstrainedBox ensures the UI doesn't stretch too wide on your Web/Desktop builds
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.group_add, size: 64, color: colorScheme.primary),
                ),
                const SizedBox(height: 32),
                
                // Welcome Text
                Text(
                  "You've been invited!".tr(),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "Click below to accept the invitation and join the group.".tr(),
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
                  height: 56, // Slightly taller button for a premium feel
                  child: FilledButton(
                    onPressed: _isProcessing ? null : _handleJoin,
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
                            "Accept Invitation".tr(), 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                TextButton(
                  // Safely route them back to the groups directory if they change their mind
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