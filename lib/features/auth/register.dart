import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../../app_state.dart';
import 'package:provider/provider.dart';
import 'profile_service.dart';
import 'profile.dart';
import 'package:easy_localization/easy_localization.dart';

class RegisterForm extends StatefulWidget {
  final void Function(Profile?)? onRegisterSuccess;

  const RegisterForm({super.key, this.onRegisterSuccess});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;

  String? _emailError;
  String? _displayNameError;
  String? _passwordError;
  String? _confirmError;

  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return emailRegex.hasMatch(email);
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    setState(() {
      _emailError = null;
      _displayNameError = null;
      _passwordError = null;
      _confirmError = null;
    });

    bool hasError = false;

    if (email.isEmpty) {
      _emailError = "key_018a".tr();
      hasError = true;
    } else if (!isValidEmail(email)) {
      _emailError = "key_018b".tr();
      hasError = true;
    }

    if (displayName.isEmpty) {
      _displayNameError = "key_018c".tr();
      hasError = true;
    } else if (displayName.length < 3) {
      _displayNameError = "key_018d".tr();
      hasError = true;
    } else if (displayName.length > 20) {
      _displayNameError = "key_018e".tr();
      hasError = true;
    } else if (!RegExp(r'^[a-zA-Z0-9_ ]+$').hasMatch(displayName)) {
      _displayNameError = "key_018f".tr();
      hasError = true;
    }

    if (password.length < 8) {
      _passwordError = "key_018g".tr();
      hasError = true;
    }

    if (password != confirmPassword) {
      _confirmError = "key_018h".tr();
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService(context.read<AppState>());
      final response = await authService.signUp(email, password);
      final user = response.user;

      if (user != null) {
        // session may be null — wait for confirmation
        await ProfileService().createProfile(
          userId: user.id,
          displayName: displayName,
          email: email,
        );

        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("key_018".tr()),
            content: Text(
              "key_018i".tr(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onRegisterSuccess?.call(null);
                },
                child: Text("key_019".tr()),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("key_020".tr()),
          content: Text("key_021".tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("key_022".tr()),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text("key_023".tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: "key_023a".tr(), errorText: _emailError),
            ),
            TextField(
              controller: _displayNameController,
              autofillHints: const [AutofillHints.name],
              keyboardType: TextInputType.text,
              decoration: InputDecoration(labelText: "key_023b".tr(), errorText: _displayNameError),
            ),
            TextField(
              controller: _passwordController,
              autofillHints: const [AutofillHints.password],
              obscureText: true,
              decoration: InputDecoration(labelText: "key_023c".tr(), errorText: _passwordError),
            ),
            TextField(
              controller: _confirmController,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: "key_023d".tr(), errorText: _confirmError),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _register,
                    child: Text("key_023".tr()),
                  ),
          ],
        ),
      ),
    );
  }
}
