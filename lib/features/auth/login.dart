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

  Future<void> _signin() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await context.read<AppState>().signInWithZitadel();
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
    } finally {
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
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Not now'),
        ),
      ],
    );
  }
}
