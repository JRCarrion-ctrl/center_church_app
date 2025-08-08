import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _showBackToLogin = false;

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty || confirm.isEmpty) {
      setState(() => _message = "key_024a".tr());
      return;
    }

    if (password.length < 8) {
      setState(() => _message = "key_024b".tr());
      return;
    }

    if (password != confirm) {
      setState(() => _message = "key_024c".tr());
      return;
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (mounted) {
        setState(() {
          _message = "key_024d".tr();
          _showBackToLogin = true;
        });
      }
    } catch (e) {
      setState(() => _message = "key_024e".tr());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_024".tr())),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              "key_024f".tr(),
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "key_024g".tr()),
            ),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(labelText: "key_024h".tr()),
            ),
            const SizedBox(height: 24),
            if (_message != null)
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.toLowerCase().contains("key_024i".tr())
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            const SizedBox(height: 16),
            if (_loading)
              const CircularProgressIndicator()
            else ...[
              ElevatedButton(
                onPressed: _updatePassword,
                child: Text("key_025".tr()),
              ),
              if (_showBackToLogin)
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/auth'),
                  child: Text("key_026".tr()),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
