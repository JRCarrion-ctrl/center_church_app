// File: lib/main.dart
import 'package:ccf_app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'features/splash/splash_screen.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CCFAppBoot());
}

class CCFAppBoot extends StatefulWidget {
  const CCFAppBoot({super.key});

  @override
  State<CCFAppBoot> createState() => _CCFAppBootState();
}

class _CCFAppBootState extends State<CCFAppBoot> {
  bool _ready = false;
  late final AppState appState;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Supabase.initialize(
      url: 'https://vhzcbqgehlpemdkvmzvy.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoemNicWdlaGxwZW1ka3ZtenZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA4ODY3NjgsImV4cCI6MjA2NjQ2Mjc2OH0.rPIiZ3RHcG3b3zTF-9TwB0fu-puByMXTeN5yRe5M0H0',
    );

    appState = AppState();

    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(home: SplashScreen());
    }

    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ccfLightTheme,
            darkTheme: ccfDarkTheme,
            themeMode: state.themeMode, // ✅ Still dynamic
            routerConfig: createRouter(state),
          );
        },
      ),
    );
  }
}
