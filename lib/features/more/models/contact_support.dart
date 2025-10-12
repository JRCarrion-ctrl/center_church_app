// File: lib/features/more/contact_support_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../app_state.dart';

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

    final client = GraphQLProvider.of(context).value;
    final appState = context.read<AppState>();
    final userId = appState.profile?.id;
    final email = appState.profile?.email;

    // If you don't yet have this table, create it (id uuid pk default gen_random_uuid(),
    // user_id uuid, email text, subject text, message text, status text default 'open', created_at timestamptz default now()).
    const m = r'''
      mutation SubmitSupport(
        $user_id: uuid,
        $email: String,
        $subject: String!,
        $message: String!
      ) {
        insert_support_requests_one(object: {
          user_id: $user_id,
          email: $email,
          subject: $subject,
          message: $message
        }) { id }
      }
    ''';

    try {
      final res = await client.mutate(
        MutationOptions(
          document: gql(m),
          variables: {
            'user_id': userId,
            'email': email,
            'subject': subject,
            'message': message,
          },
        ),
      );

      if (res.hasException) {
        throw res.exception!;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("key_199".tr())), // “Thanks, we got it” toast
      );
      Navigator.of(context).pop();
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
    final email = context.watch<AppState>().profile?.email ?? 'your email';

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
//TODO: This creates a table insert, further action is needed to actually send the message