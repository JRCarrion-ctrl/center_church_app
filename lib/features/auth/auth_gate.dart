import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';
import '../../app_state.dart';
import '../splash/splash_screen.dart'; // You’ll create this next

class AuthGate extends StatefulWidget {
  final Widget child;

  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(_handleAuthChange);

    _loadProfile(); // initial
  }

  Future<void> _loadProfile() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;

    try {
      final profile = user != null
          ? await ProfileService().getProfile(user.id)
          : null;
      if (mounted) {
        context.read<AppState>().setProfile(profile);
      }
    } catch (e) {
      debugPrint('AuthGate: Failed to load profile – $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleAuthChange(AuthState data) async {
    setState(() => _isLoading = true);
    await _loadProfile();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen(); // Replace with your custom screen
    }

    return widget.child;
  }
}
