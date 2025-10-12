import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';

class MagicLinkPage extends StatefulWidget {
  const MagicLinkPage({super.key});

  @override
  State<MagicLinkPage> createState() => _MagicLinkPageState();
}

class _MagicLinkPageState extends State<MagicLinkPage> {
  bool _loading = false;
  String? _message;

  Future<void> _startOidcLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      // Uses your existing flow: OIDC (Zitadel) → restoreSession → Hasura upsert
      await context.read<AppState>().signInWithZitadel();
      if (!mounted) return;

      // Success message (re-using your i18n key from the old screen)
      setState(() => _message = "key_344a".tr());

      // If this page was shown modally, pop it; otherwise you can navigate home.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      // Or: context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Error: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("key_345".tr())), // e.g., "Sign in"
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              "key_346".tr(), // You can repurpose this to "Continue" or "Sign in"
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _startOidcLogin,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text("key_346".tr()), // e.g., "Continue"
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(tr('Not now')),
            ),
          ],
        ),
      ),
    );
  }
}
