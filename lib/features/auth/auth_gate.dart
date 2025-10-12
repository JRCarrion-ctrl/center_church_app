import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import 'login.dart';

class AuthGate extends StatelessWidget {
  final Widget child;
  final bool requireMember; // if false, just passes through
  const AuthGate({super.key, required this.child, this.requireMember = true});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!requireMember) return child;

    if (app.isAuthenticated) return child;

    return Center(
      child: ElevatedButton(
        onPressed: () async {
          await showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => const Dialog(
              insetPadding: EdgeInsets.all(24),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: LoginSheet(),
              ),
            ),
          );
        },
        child: const Text('Sign in to continue'),
      ),
    );
  }
}
