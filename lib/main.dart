// File: lib/main.dart
import 'package:ccf_app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'features/splash/splash_screen.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("a75771e7-9bd5-4497-adf3-18b7c8901bcb");

  runApp(const CCFAppBoot());
}
Future<void> requestPushPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

class CCFAppBoot extends StatefulWidget {
  const CCFAppBoot({super.key});

  @override
  State<CCFAppBoot> createState() => _CCFAppBootState();
}

class _CCFAppBootState extends State<CCFAppBoot> {
  bool _ready = false;
  late final AppState appState;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _requestPushPermissionOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('notification_prompted') ?? false;

    if (!hasPrompted) {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isRestricted) {
        await Permission.notification.request();
      }
      await prefs.setBool('notification_prompted', true);
    }
  }

  Future<void> _initializeApp() async {
    await Supabase.initialize(
      url: 'https://vhzcbqgehlpemdkvmzvy.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoemNicWdlaGxwZW1ka3ZtenZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA4ODY3NjgsImV4cCI6MjA2NjQ2Mjc2OH0.rPIiZ3RHcG3b3zTF-9TwB0fu-puByMXTeN5yRe5M0H0',
    );

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      OneSignal.login(userId);
    } else {
      // Optional: use logout if anonymous or show warning
      OneSignal.logout();
    }

     await _requestPushPermissionOnce();

    appState = AppState();
    await appState.loadTimezone();
    _router = createRouter(appState);

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
          if (!state.isInitialized) {
            return const MaterialApp(home: SplashScreen());
          }

          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ccfLightTheme,
            darkTheme: ccfDarkTheme,
            themeMode: state.themeMode, // ✅ Still dynamic
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
