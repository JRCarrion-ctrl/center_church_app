import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';

class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});
  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  bool _loading = false;

  // Refactored _signin method for _LoginSheetState

Future<void> _signin() async {
  if (_loading) return;
  
  // Start loading state
  setState(() => _loading = true);

  try {
    // Attempt the sign-in flow
    await context.read<AppState>().signInWithZitadel();
    
    // On success, dismiss the login sheet
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    if (!mounted) return;

    // Check if the error is the expected user cancellation message.
    // The AppState throws Exception('Sign-in was canceled by the user.')
    final isCancellation = e is Exception && e.toString().contains('Sign-in was canceled');
    
    if (isCancellation) {
      // Do nothing: User voluntarily closed the login window.
      // The loading spinner will be dismissed by the 'finally' block.
    } else {
      // Show a snackbar for all other errors (network, server, config, etc.)
      // Use the error message or a generic failure message.
      final displayMessage = e is Exception
          ? 'Login failed: ${e.toString().split(':').last.trim()}'
          : 'Login failed due to an unknown error.';
          
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    // Always stop the loading state, regardless of success or failure (cancellation/error)
    if (mounted) setState(() => _loading = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text('Sign in or Create Account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        _loading
            ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
            : ElevatedButton(onPressed: _signin, child: const Text('Continue')),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
      ],
    );
  }
}
