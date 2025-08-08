import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class ForgotPasswordForm extends StatefulWidget {
  final VoidCallback? onResetEmailSent;

  const ForgotPasswordForm({super.key, this.onResetEmailSent});

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  void _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Please enter an email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'ccf_app://reset', // must match what's configured in Supabase Auth
      );
      if (mounted) _showSuccessDialog();
    } catch (e) {
      _showErrorDialog('Password reset failed.\n${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("key_009".tr()),
        content: Text("key_010".tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onResetEmailSent?.call();
            },
            child: Text("key_011".tr()),
          ),
        ],
      ),
    );
  }

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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text("key_013".tr(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _resetPassword,
                    child: Text("key_014".tr()),
                  ),
          ],
        ),
      ),
    );
  }
}
