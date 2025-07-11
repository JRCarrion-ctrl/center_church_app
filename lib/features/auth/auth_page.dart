// file: lib/features/auth/auth_page.dart
import 'package:ccf_app/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features.dart';

enum AuthMode { login, register, forgotPassword }

class AuthPage extends StatefulWidget {
  final void Function(Profile?)? onAuthSuccess;

  const AuthPage({super.key, this.onAuthSuccess});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  AuthMode _authMode = AuthMode.login;

  void _setAuthMode(AuthMode mode) {
    setState(() => _authMode = mode);
  }

  void _handleAuthSuccess(Profile? profile) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (profile != null) {
        context.read<AppState>().setProfile(profile);
      }
      widget.onAuthSuccess?.call(profile);

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _handleResetEmailSent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setAuthMode(AuthMode.login);
      }
    });
  }

  Widget _buildContent() {
    switch (_authMode) {
      case AuthMode.login:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoginForm(onLoginSuccess: _handleAuthSuccess),
            TextButton(
              onPressed: () => _setAuthMode(AuthMode.forgotPassword),
              child: const Text("Forgot password?"),
            ),
            TextButton(
              onPressed: () => _setAuthMode(AuthMode.register),
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        );
      case AuthMode.register:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RegisterForm(onRegisterSuccess: _handleAuthSuccess),
            TextButton(
              onPressed: () => _setAuthMode(AuthMode.login),
              child: const Text("Have an account? Log In"),
            ),
          ],
        );
      case AuthMode.forgotPassword:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ForgotPasswordForm(onResetEmailSent: _handleResetEmailSent),
            TextButton(
              onPressed: () => _setAuthMode(AuthMode.login),
              child: const Text("Back to Login"),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }
}
