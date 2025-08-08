import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import '../../app_state.dart';
import 'profile_service.dart';
import 'profile.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginForm extends StatefulWidget {
  final void Function(Profile? profile)? onLoginSuccess;

  const LoginForm({super.key, this.onLoginSuccess});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("key_012".tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("key_011".tr()),
          ),
        ],
      ),
    );
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog("key_016".tr());
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = AuthService(context.read<AppState>());
      final authResponse = await authService.signIn(email, password);
      final user = authResponse.user;

      if (user != null) {
        final profile = await ProfileService().getProfile(user.id);
        if (!mounted) return;

        // Update global state so other widgets see the login
        context.read<AppState>().setProfile(profile);

        // Optional: also load user groups if needed
        await context.read<AppState>().loadUserGroups();

        widget.onLoginSuccess?.call(profile);

        // Close the login screen
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showErrorDialog("key_021a".tr());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              "key_017".tr(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: "key_023a".tr()),
            ),
            TextField(
              controller: _passwordController,
              autofillHints: const [AutofillHints.password],
              obscureText: true,
              decoration: InputDecoration(labelText: "key_023c".tr()),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: Text("key_017".tr()),
                  ),
          ],
        ),
      ),
    );
  }
}
