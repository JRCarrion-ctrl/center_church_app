import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class MagicLinkPage extends StatefulWidget {
  const MagicLinkPage({super.key});

  @override
  State<MagicLinkPage> createState() => _MagicLinkPageState();
}

class _MagicLinkPageState extends State<MagicLinkPage> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _message;

  Future<void> _sendMagicLink() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    final email = _emailController.text.trim();

    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'ccf_app://login-callback',
      );

      setState(() {
        _message = "key_344a".tr();
      });
    } catch (e) {
      setState(() {
        _message = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("key_345".tr())),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _sendMagicLink,
              child: _loading
                  ? const CircularProgressIndicator()
                  : Text("key_346".tr()),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, style: const TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }
}
