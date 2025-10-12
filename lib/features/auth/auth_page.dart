import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import 'login.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (app.isAuthenticated) ...[
                  CircleAvatar(radius: 32, child: Text(app.displayName?.characters.first.toUpperCase() ?? '?')),
                  const SizedBox(height: 12),
                  Text(app.displayName ?? 'Member', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.read<AppState>().signOut(),
                    child: const Text('Logout'),
                  ),
                ] else const LoginSheet(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
