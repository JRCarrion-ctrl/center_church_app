import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import 'package:easy_localization/easy_localization.dart';

class ContactSupportPage extends StatefulWidget {
  const ContactSupportPage({super.key});

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'submit_support_request',
        body: {
          'subject': subject,
          'message': message,
        },
      );

      if (response.status == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("key_199".tr())),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception(response.data);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final email = appState.profile?.email ?? 'your email';

    return Scaffold(
      appBar: AppBar(title: Text("key_201".tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("key_202".tr(args: [email])),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(labelText: "key_202a".tr()),
                validator: (val) => val == null || val.trim().isEmpty ? "key_202b".tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(labelText: "key_202c".tr()),
                maxLines: 5,
                validator: (val) => val == null || val.trim().isEmpty ? "key_202b".tr() : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitSupportRequest,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : Text("key_203".tr()),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}